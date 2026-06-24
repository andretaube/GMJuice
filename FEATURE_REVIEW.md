# GMJuice — Feature Review & Simplification Plan

**Goal:** Strip GMJuice down to a focused **personal Steel Challenge training tracker** and get it ready for **public distribution** (App Store / anyone, not just friends).

**Status:** Decisions finalized (see Action Plan). Code changes **not yet executed** — this is the agreed plan to work from.

**The app, after this plan:**
> Connect an AMG Bluetooth timer → record training strings → review what you did on any given day → see your live performance class vs GM benchmarks → check your own SCSA status in Profile → export your stats. Three tabs: **Train · Profile · Settings.**

---

## ✅ Action Plan

### ➕ ADD (new): "Target Times" reference screen
**What:** A **static reference helper — not based on your performance.** Select a **division** → see a table of all 8 stages × classifications (C/B/A/M/GM), each cell showing the **total target time** and the **per-string target time**. Answers "I'm RFPI and want a GM score — what should each string be?"

**Use case:** the digital version of the little printed target-time cards shooters carry to the range. Before a practice session you open it, pick your division, and remind yourself how fast each string needs to be for a given classification. No personal/SCSA data involved.

**Good news — it mostly already exists.** `MatchesView.swift` contains `PercentageTableTabView` + `AllStagesTableView` + `StageTableView` (lines ~616–920) with the exact, correct math:
- Target time for a class = `peakTime / classPercentThreshold × 100` (GM=95%, M=85%, A=75%, B=60%, C=40%).
- Per-string time = `targetTime / strings` (SC-104 = 3 counted strings, all others = 4).

**The gap:** today it's **stage-first** (pick a stage → rows are divisions). You want **division-first** (pick a division → rows are stages). Same math, transposed layout.

**Plan:**
1. **Before deleting `MatchesView`**, extract the table components + math into a new standalone view (e.g. `Views/TargetTimesView.swift`), independent of `MatchScore`/SCSA.
2. **Reorient to division-first:** a division picker at top; table rows = stages SC-101…SC-108, columns = C/B/A/M/GM + Peak; each cell shows **total** time and **per-string** time, in a clean tabular layout (like a printout card). Purely static — no current-class highlighting or personal data.
3. Reads from `CurrentPeakBenchmarks` (already Firebase-backed with local fallback) — no SCSA dependency, works offline.
4. **Placement:** dedicated **"Target Times"** screen reached from the **Train tab** (recommended — matches the pre-training use case; you pick a division to record there anyway). It's a self-contained, reusable view, so it can also be linked from Profile if wanted. *(Revised from an earlier Profile-first recommendation now that it's confirmed to be non-personal reference data.)*

> This *supersedes* old inventory item #33 (the buried reference table) — it's the same feature, rescued, reoriented, and given a real home.

### ➕ ADD (new): Set-based stage scoring (recording-view redesign)
**The problem today:** the recording view treats strings as an unbounded stream and shows a *rolling* "Best 4 of 5" (`calculateBestNSum` continuously takes the last N+1 strings and drops the slowest). There is no discrete, scored stage attempt.

**Desired behavior (confirmed):** everything happens in **sets** — 5 strings normally, **4 for Outer Limits (SC-104)**.
1. Enter the timer screen → shoot string 1 → counter shows **1/5**; string 2 → **2/5**; etc.
2. As strings come in, the **worst string in the current set is shown in red** (recomputed live).
3. After the **final** string (5th, or 4th for Outer Limits), show the **stage total = best N-1 of N (drop the worst)** with its classification (letter + %).
4. The **next beep auto-starts a fresh set at string 1**; the just-completed stage total + class **moves to the right-column history**.
5. Right column = **last 5 completed stages this session** (total time + class). Replaces today's session fastest/slowest panel.

**The math already exists** — no new formulas:
- Per-string letter + %: `CurrentPeakBenchmarks.percent(division:stageCode:time:)` → compares one string to the per-string benchmark `peak / (strings-1)`.
- Stage total letter + %: `CurrentPeakBenchmarks.percent(division:stageCode:times:)` → drops slowest, sums best N-1, compares to full `peak`.
- Set size N = `Stage.strings` (5, or 4 for SC-104). Worst-of-set = the max-time string (the dropped one).

**Implementation outline:**
- **Data model — Schema002 (start fresh, no migration):** add a `StageRun` model (stageId, divisionId, date, `@Relationship(.cascade)` to its `[StringRun]`, plus stored/computed best-N total + percent + class). `StringRun` stays (one string = its shots) but now belongs to a `StageRun`. Since we're **starting fresh**, the existing local SwiftData store is reset on upgrade — no migration logic needed.
- **`RecordingManager`:** track the current set (completed strings + in-progress string). On beep: finish the in-progress string into the set; if the set already holds N strings → **finalize & persist the `StageRun`**, push it to session history, reset, then start string 1 of a new set; otherwise start the next string.
- **`RecordingViewModel`:** expose `currentSetStrings`, `worstStringIndex`, `currentStageTotal`/class (once N reached), and `completedStagesThisSession` (last 5).
- **`RecordingLeftColumn`:** rewrite → header `X/5` (or `X/4`); a list of the current set's strings each with time + letter + % (worst row red); stage total + class once the set completes.
- **`RecordingRightColumn`:** rewrite → list of last 5 completed stages (total + class). (Old per-session fastest/slowest is removed.)
- **Daily Log / Stage-Day Detail (kept #13/#14):** now show **stage scores** per day; tap a stage to see its strings. Reshaped to read `StageRun`.

**Assumptions (flag if wrong):**
- **Incomplete set** (you leave mid-set, e.g. 3 strings): the partial set is **not scored or saved** — discarded.
- **Shots-per-string** logic is unchanged (still completes a string at 5 shots); this change is about *strings-per-set*, not shots-per-string.
- **Announcer:** announce the **stage total** when a set completes (keep per-string time announce optional). Will confirm during build.

> Reshapes inventory items #4, #5, #6 (recording display), #13/#14 (Log now stage-based), and #55 (SwiftData → Schema002 + `StageRun`).

### ➕ ADD (from research, committed): A · B · C · E
Lean, data-reuse features greenlit from the three research passes (full detail + citations in [Candidate additions](#-candidate-additions-from-market--user--business-research)):
- **A — Branded session/progress report (PDF) via share sheet.** Upgrades CSV export (#43) into a one-tap "share/email my last training": draw, splits, transitions, total + best-4-of-5, classification. Keystone feature — doubles as the training-business MVP. No backend; sharing is user-initiated (= consent).
- **B — "Why this class" explainer.** Plain-language SCSA classification-math breakdown next to the score already computed.
- **C — "Practice your weakest stage" pointer.** Auto-surfaces the lowest-class-% stage. Near-free from existing data.
- **E — One lightweight progress trend.** A single classification/best-4-of-5-over-time view — intentionally *not* a chart suite.
- **Guardrails adopted:** account-free, user-initiated sharing only, never collect age/DOB, no realistic gun imagery in store assets, positive (non-guilt) reminders.

### KEEP (core — the app's reason to exist)
- **Recording & timer** — BLE connect/scan/persist, shot recording, live classification, best/worst times, best-N-of-M, string editing, stage/division selection.
- **Audio** — TTS announcer, auto-announce, trophy sound, connection-status announce.
- **Training review** — Training Log (by day → division → stage), Stage/Day Detail (review a specific day, edit/delete runs), Summary stats card.
- **CSV export** — "download stats" of all training runs via share sheet.
- **Profile (self only)** — see decision below.
- **Settings** — Voice, Timer, Appearance (light/dark), Notifications.
- **Notifications** — weekly summary + daily reminder (keep for now).
- **Infra** — Terms/Privacy gate, SwiftData persistence, app bootstrap.

### KEEP — Firebase (confirmed)
- **Remote Config** — **keep**, primarily for peak benchmark times (`PeakData`). See [Updating Peak Benchmark Data](#updating-peak-benchmark-data) below.
- **Analytics** — keep.
- **Crashlytics** — keep.
- **Peak Benchmarks service** — keep (remote with local fallback).

### ✂️ SIMPLIFY
- **Feature flags** — Remote Config currently gates 4 flags (`ProfileEnabled`, `AnalysisEnabled`, `SCSADataEnabled`, `ClaudeAIEnabled`). After cuts, most are dead:
  - ❌ Remove `AnalysisEnabled` (Analysis tab is being deleted).
  - ❌ Remove `ClaudeAIEnabled` (all AI removed).
  - ❌ Remove `ProfileEnabled` gating (Profile is always on now) — hard-enable the tab.
  - ✅ **Keep `SCSADataEnabled`** as a remote **kill-switch** — because SCSA scraping is fragile, this lets you remotely disable it if scsa.org changes and breaks parsing, without an app update. Good use of Remote Config.
- **Tab navigation** — drop the Analysis tab and all flag-gating logic. Final tabs: **Train · Profile · Settings.**
- **Splash (#54)** — keep the splash, but remove the Firebase motivational-message dependency (since the messages service is being cut). Show a static message or none.
- **Onboarding/help** — pick the **single simplest** mechanism (see Onboarding section). Keep one lightweight help sheet.
- **Profile** — keep SCSA sync **for your own number only**; strip everything social.

### ❌ CUT (remove entirely)
- **All AI coaching** — `ClaudeAPIClient`, `CoachingService`, `CoachingCardCache`, `SCPerformanceAnalyzer`, `Models/CoachingCard`, `Views/Coaching/*`. Plus the **Anthropic API key** from `Config.xcconfig` + Info.plist injection + the `ANTHROPIC_API_KEY` build wiring. *(This is the #1 public-distribution risk — a shipped key bills your account. Removing it closes that risk.)*
- **All reporting/analytics views** — `ReportView`, `AllTimeReportView` (incl. `StageReportDetailView` = old #18), `StageProgressReportView` (old #19). The duplicated chart code (first-shot chart, total-time chart, `groupData()`, hit-rate calc) gets deleted wholesale — duplication resolved by deletion.
- **Match scores** — match-score list/tab, `MatchesView`, and match-score-driven views. ⚠️ **First rescue the percentage/target-time table** out of `MatchesView` (see ADD section) before deleting the file.
- **Social / following** — `FollowingView`, head-to-head comparison (`CompareProfilesView` etc.).
- **Video recording** — `VideoRecordingView`, `VideosView`, `VideoRecordingViewModel`, `VideoProcessingManager`, `VideoProcessor`, processing banner. (Self-contained subsystem — clean cut.)
- **Onboarding extras** — TipKit tips (`TrainTips`), custom coach-mark engine (`CoachMarks` + `*Help` coach-mark flows). Keep only one simple help sheet.
- **Motivational messages service (#59)** — `MotivationalMessagesService` + its Firebase round-trip.

### Profile — final decision: **Keep SCSA, self only**
- ✅ Keep scraping scsa.org for **your own** USPSA number → show classification, per-division %, and the stage/classifier breakdown ("my scores/status").
- ✅ Keep: `USPSANumberSheet` (enter your number), `ProfileErrorRecovery`, Thursday auto-sync, `SCSAOnboardingView` (simplified).
- ❌ Remove from Profile: match-scores list, following, head-to-head comparison, profile-visibility toggles (nothing left to hide from).
- ⚠️ Accept the residual fragility (scsa.org redesign breaks parsing) — mitigated by the `SCSADataEnabled` remote kill-switch.

---

## 🔬 Candidate additions (from market + user + business research)

Three deep-research passes (competitor scan, shooter pain-points, training-business fit) all point the same direction: **the lean philosophy is correct, the cuts are vindicated, and the best additions are guidance/reports layered on data the app already captures — not new subsystems.** Nothing below is decided; this is a prioritized menu to react to.

> **Triple-confirmed DO NOT BUILD** (all three reports independently): AI coaching, video, social feed, heavy expert-only analytics dashboards, large drill libraries, and accounts/backend — *until/unless the business scales.* Research principle that kills bloat: *"there are no advanced techniques — experts just need finer measurement of the same basics."*

> **Decisions (locked):** ✅ **A, B, C, E committed.** ❌ **J declined (stays cut).** ⏸️ **H, I deferred** until the training business scales. D, F, G remain open candidates.

### Tier 1 — ✅ COMMITTED (A, B, C)
| Tag | Candidate | What | Serves | Backend | Effort | Bloat |
|----|-----------|------|--------|---------|--------|-------|
| **A** | **Branded session/progress report (PDF) via share sheet** | Upgrade the CSV export (#43) into a clean, branded one-tap "share/email my last training" report: draw/first-shot, splits, transitions, total + best-4-of-5, classification. | All users **+ the training-business MVP** | **None** (local, share-sheet) | Light–Med | Low |
| **B** | **"Why this class" explainer** | Plain-language breakdown of the (genuinely confusing, frequently-asked) SCSA classification math next to the score the app already computes. | Int/Adv + beginners | None | **Low** | Low |
| **C** | **"Practice your weakest stage" pointer** | Auto-surface the stage with the lowest classification % — a near-free nudge from data already computed. | Int/Adv | None | **Low** | Low |

> **A is the keystone.** It's exactly your "email the log" instinct, it's the #1 training-business feature across the research, and it doubles as a general-user feature. It supersedes/upgrades CSV export rather than adding a new surface.

### Tier 2 — lean but watch scope
| Tag | Candidate | Note | Effort | Bloat |
|----|-----------|------|--------|-------|
| **D** | **Beginner "what good looks like" context** | Fold into the Target Times screen: show where a time sits vs class bands + reassurance framing (counters YouTube-GM intimidation). | Low–Med | Low |
| **E** | **One lightweight progress trend** ✅ COMMITTED | classification %/best-4-of-5 over time. **A *single* simple trend, not a chart suite** (deliberately narrower than the multi-screen analytics that were cut). | Med | Med |
| **F** | **Gentle, positive reminder framing** | Refine existing notifications (#44/#45): frame around short frequent sessions + PRs/class gains; **avoid guilt-inducing streaks** (research warns these demoralize). | Low | Low |
| **G** | **Small fixed set of par-time dry-fire drills** | draw + transitions only. Optional; only if it stays minimal (large drill libraries are a bloat trap). | Med | Med |

### Tier 3 — defer unless the training business scales
| Tag | Candidate | Why defer |
|----|-----------|-----------|
| **H** | On-device per-student / coach notes | Light, but only useful once you have students. |
| **I** | Accounts + coach dashboard (roster, assigned drills, client-logged data) | **Phase 3 only.** Adds backend cost + privacy/consent burden; breaks the lean local-first design. Research says don't until you've outgrown the share-sheet flow. |

### Reconsider (cut vs. competitor signal)
| Tag | Candidate | The tension |
|----|-----------|-------------|
| **J** | ❌ **Head-to-head comparison — DECLINED, stays cut** | The closest direct competitor leads with it, but no user pain-point requires it and it pulls toward the social/multi-shooter surface we deliberately removed. Decision: **not building it.** (Revisit only if positioning later demands it.) |

### Cross-cutting guardrails — ✅ ADOPTED
- **Stay account-free; keep all sharing user-initiated.** A user tapping "share my report" *is* the consent (Apple 5.1.2 / GDPR) — avoids a consent/backend burden. Apple actively favors no-login apps.
- **Never collect age/birthdate.** Collecting it creates COPPA "actual knowledge" and triggers parental-consent/deletion obligations. Don't ask.
- **No realistic firearm imagery in App Store screenshots/marketing** (Apple has rejected these even though shooting-sports apps themselves are allowed under 1.1.3).
- **Monetization norms** (validate separately — research was inconclusive here): direct competitors use **one-time ~$9.99** or **freemium-with-Pro**. A **free app as a funnel to paid lessons** is the natural training-business model. QR/handout for lead-gen is free.

### Differentiator to protect
Your **AMG BLE auto-capture + SCSA-classification framing + TTS/trophy gamification** is a combination **no current app offers**: the two direct SCSA apps are manual-entry; the BLE-capable apps (PractiScore Log) aren't SCSA-classification trainers. Keep this front-and-center in positioning.

---

## Updating Peak Benchmark Data

You asked to keep Remote Config specifically for peak times. Here's exactly how that data flows and how to change it.

**Where the data lives:**
- **Local seed (fallback / default):** `GMJuice/Data/PeakBenchmark.swift` — a `PeakTable` built from `t.set(division:stageCode:peakTime:)` calls (8 stages × all divisions). This ships in the app and is used when Remote Config is unavailable.
- **Remote override:** Firebase Remote Config parameter **`PeakData`** (a JSON-encoded `PeakTable`). Managed in `GMJuice/Firebase/PeakBenchmarksService.swift`.
- **Always read through** `CurrentPeakBenchmarks` (remote if present, else local seed). Clients fetch **daily** in Release (every launch in Debug) and cache to UserDefaults for offline use.

**To update benchmarks WITHOUT shipping an app update (preferred):**
1. Edit the values in `Data/PeakBenchmark.swift` locally (this is the source of truth for the JSON).
2. Run the app in a **Debug** build and call the helper to print the JSON:
   ```swift
   // DEBUG-only helpers in PeakBenchmarksService
   print(PeakBenchmarksService.shared.generateFirebaseJSON() ?? "")
   // or: await PeakBenchmarksService.shared.uploadCurrentBenchmarks()  // prints key + JSON
   ```
3. Copy the printed JSON.
4. Firebase Console → **Remote Config** → parameter **`PeakData`** → paste the JSON as the value → **Publish changes**.
5. Clients pick it up on their next daily fetch (or immediately in Debug).

**To update benchmarks the simple way (ships with an app release):**
- Just edit `Data/PeakBenchmark.swift` and release a new build. The new values become the local default; if `PeakData` in Remote Config is empty/absent, the app uses them directly.

> Note: the Remote Config **key is `PeakData`** (not `peak_benchmarks` as an older CLAUDE.md note says). The decode target is `PeakTable`, so the JSON shape must match what `generateFirebaseJSON()` emits — always generate it from the helper rather than hand-writing it.

---

## Public-distribution checklist (carried over)

These remain regardless of the feature cuts:
1. **App Privacy disclosure** in App Store Connect — required because Analytics + Crashlytics collect data (usage data, crash data, identifiers).
2. **GDPR/consent** — public = EU users; disclose Analytics properly. (No IDFA/ads → likely no ATT prompt; confirm no `AdSupport`.)
3. **Configure App Check** — already a linked dependency but never set up; enabling it protects Remote Config from outside abuse at scale.
4. **Verify Crashlytics dSYM upload** build phase exists (otherwise public crash reports are unsymbolicated).
5. `GoogleService-Info.plist` is committed — fine (not a true secret; no writable backend exists), App Check is the real mitigation.

✅ **Big reassurance:** No Firestore/Auth/Storage/Realtime DB anywhere — there is **no writable backend** for strangers to abuse, and Analytics/Crashlytics/Remote Config are all free-tier and scale to unlimited users.

---

## Full feature inventory (final decisions)

Legend: ✅ Keep · ✂️ Simplify · ❌ Cut

### 1. Core Recording & Timer
| # | Feature | Decision |
|---|---------|----------|
| 1 | BLE timer shot recording | ✅ Keep |
| 2 | BLE scan/connect/persist | ✅ Keep |
| 3 | BLE data parsing | ✅ Keep |
| 4 | Live performance classification | ✅ Keep → reshaped by set-based scoring (per-string + per-stage) |
| 5 | Best/worst time tracking | 🔄 Replaced by session stage-history (last 5) |
| 6 | Best N-of-M calc | 🔄 Replaced by discrete set scoring (best N-1 of N per set) |
| 7 | String run editing | ✅ Keep |
| 8 | Stage/division selection | ✅ Keep |
| 9 | TTS announcer | ✅ Keep |
| 10 | Auto-announce on 5 shots | ✅ Keep |
| 11 | Trophy sound | ✅ Keep |
| 12 | Connection-status announce | ✅ Keep |

### 2. Reporting & Analytics Views
| # | Feature | Decision |
|---|---------|----------|
| 13 | Training Log | ✅ Keep → reshaped to show stage scores (set-based) |
| 14 | Stage/Day Detail | ✅ Keep → reshaped to stage scores, tap → strings |
| 15 | Summary stats card | ✅ Keep |
| 16 | Report (session-level) | ❌ Cut |
| 17 | All-Time Report hub | ❌ Cut |
| 18 | All-Time Stage Detail (9+ charts) | ❌ Cut |
| 19 | Stage Progress (match scores) | ❌ Cut |

### 3. AI Coaching
| # | Feature | Decision |
|---|---------|----------|
| 20 | AI coaching cards | ❌ Cut |
| 21 | Match vs Practice cards | ❌ Cut |
| 22 | SCPerformanceAnalyzer | ❌ Cut |
| 23 | Stage Detail Analysis | ❌ Cut |
| 24 | Coaching card cache | ❌ Cut |
| 25 | Coaching Home | ❌ Cut |

### 4. Profile, SCSA & Social
| # | Feature | Decision |
|---|---------|----------|
| 26 | USPSA profile management | ✅ Keep (self only) |
| 27 | SCSA web scraping | ✅ Keep (self only, + kill-switch) |
| 28 | Classification display | ✅ Keep |
| 29 | Match Scores tab | ❌ Cut |
| 30 | Head-to-head comparison | ❌ Cut |
| 31 | Following system | ❌ Cut |
| 32 | Profile visibility toggles | ❌ Cut |
| 33 | Classification reference table | ➕ Rescue → becomes the new division-first **Target Times** screen (see ADD) |
| 34 | Profile error recovery | ✅ Keep |
| 35 | Auto-sync (Thursday) | ✅ Keep |

### 5. Video Recording
| # | Feature | Decision |
|---|---------|----------|
| 36 | Video recording + overlay | ❌ Cut |
| 37 | Video browser/playback | ❌ Cut |
| 38 | Processing status banner | ❌ Cut |

### 6. Settings
| # | Feature | Decision |
|---|---------|----------|
| 39 | Voice settings | ✅ Keep |
| 40 | Timer settings | ✅ Keep |
| 41 | Notification settings | ✅ Keep |
| 42 | Appearance (light/dark) | ✅ Keep |
| 43 | CSV export | ✅ Keep |

### 7. Notifications
| # | Feature | Decision |
|---|---------|----------|
| 44 | Weekly summary notification | ✅ Keep |
| 45 | Daily training reminder | ✅ Keep |
| 46 | Permission request/status | ✅ Keep |

### 8. Onboarding & Help
| # | Feature | Decision |
|---|---------|----------|
| 47 | Coach marks (custom spotlight) | ❌ Cut |
| 48 | TipKit tips | ❌ Cut |
| 49 | Help/tutorial sheets | ✂️ Simplify (keep one simple sheet) |
| 50 | SCSA onboarding | ✂️ Simplify (keep, trimmed) |

### 9. App Shell & Infrastructure
| # | Feature | Decision |
|---|---------|----------|
| 51 | App bootstrap/init | ✅ Keep |
| 52 | Terms/Privacy gate | ✅ Keep |
| 53 | Tab nav + flag gating | ✂️ Simplify (Train·Profile·Settings, drop gating) |
| 54 | Splash + motivational msg | ✂️ Simplify (static msg, drop Firebase dep) |
| 55 | SwiftData persistence | ✅ Keep → Schema002 adds `StageRun` (start fresh, no migration) |
| 56 | Analysis constants | ❌ Cut (only used by removed analysis) |
| 57 | Remote Config (flags) | ✂️ Simplify (keep `PeakData` + `SCSADataEnabled` kill-switch) |
| 58 | Peak benchmarks service | ✅ Keep |
| 59 | Motivational messages service | ❌ Cut |
| 60 | Analytics service | ✅ Keep |
| 61 | Crashlytics | ✅ Keep |

---

## Suggested execution order

Cutting top-down minimizes broken references at each step:

1. **AI coaching** (#20–25) + Anthropic key — self-contained; removes the public-release blocker first.
2. **Video** (#36–38) — self-contained subsystem.
3. **Reporting/analytics views** (#16–19) + `Constants` analysis section (#56).
4. **Rescue the Target Times table** out of `MatchesView` into `Views/TargetTimesView.swift` (division-first) and wire it into Profile — *do this before* deleting `MatchesView`.
5. **Social/following + match scores** (#29–32) — delete `MatchesView`/`FollowingView`/comparison; then simplify Profile to self-only SCSA (#26–28).
6. **Onboarding** — remove TipKit + coach marks (#47, #48); keep one help sheet (#49).
7. **Tabs & flags** (#53, #57) — drop Analysis tab, gating logic, dead flags.
8. **Motivational messages** (#59) + **splash** (#54).
9. **Build new features:** (a) **Set-based stage scoring** — Schema002 + `StageRun`, rework `RecordingManager`/`RecordingViewModel`/left+right columns, reshape Log to stage scores; (b) finish the **division-first Target Times** view rescued in step 4 and link it into the Train tab.
10. **Build research-driven additions** (lean, reuse existing data): **A** branded session-report PDF (upgrade CSV export #43) → **B** "why this class" explainer → **C** weakest-stage pointer → **E** single progress trend. Apply adopted guardrails throughout.
11. Build, fix references, run tests, verify.

> After each step: compile (`xcodebuild ... build`) and fix dangling references before moving on, per project directive. Estimated removal: well over a third of the ~23k-line codebase.

---

*Generated from a full read of the codebase. No app code has been changed yet — this document is the agreed plan. Next step: execute the cuts in the order above on your go-ahead.*
