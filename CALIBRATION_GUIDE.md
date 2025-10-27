# Shot Detection Calibration Guide

## Overview

The calibration system allows you to tune the shot detection algorithm to your specific shooting environment. Every range is different, and factors like microphone position, target distances, target types, and ambient noise all affect detection accuracy.

## Why Calibrate?

While the default thresholds are based on real-world data (7 hits and 2 misses), your setup may differ:
- **Different distances**: Outer Limits has 25+ yard shots vs. 7-yard close shots
- **Different targets**: Size and material affect the "ding" sound
- **Different microphone**: Position relative to shooter and targets
- **Different environment**: Indoor vs. outdoor, noise levels

Calibration collects YOUR data and calculates optimal thresholds for YOUR setup.

## How to Use

### 1. Access Calibration
```
Settings → Shot Detection → Calibrate Detection
```

### 2. Follow the Wizard

**Step 1: Introduction**
- Read the instructions
- Understand the requirements (minimum 10 hits, 10 misses)
- Tap "Start Calibration"

**Step 2: Distance Selection**
- Choose the distance to your target:
  - Close (7-10 yards)
  - Medium (10-15 yards)
  - Far (15-25 yards)
  - Very Far (25+ yards)
- Tap "Ready to Fire"

**Step 3: Fire and Label**
1. App displays "Listening..." with pulsing waveform icon
2. **Fire your shot** (live fire required!)
3. App automatically detects the shot
4. Displays acoustic analysis (ratio, delay)
5. **Mark the shot**:
   - Tap green "HIT" if you hit the steel
   - Tap red "MISS" if you missed
6. App returns to distance selection

**Step 4: Repeat**
- Continue firing and labeling shots
- Progress badges show: Hits ✓ / Misses ✓
- Mix distances for comprehensive calibration
- Minimum: 10 hits + 10 misses
- Recommended: 15-20 of each for better accuracy

**Step 5: Analyze**
- When minimum requirements met, "Finish & Analyze" button appears
- Tap to analyze your data
- View detailed statistics

**Step 6: Review Results**
The analysis shows:
- **Total samples**: Number of shots collected
- **Hit ratio range**: Min, max, and average secondary amplitude ratios for hits
- **Miss ratio range**: Min, max, and average for misses
- **Recommended threshold**: Calculated optimal value
- **Separation**: Distance between hit and miss averages (higher = better)
- **Confidence**: 0-100% based on data quality

**Step 7: Apply or Discard**
- Tap "Apply Calibration" to use the new thresholds
- Or tap "Done" to discard and keep current settings

## Understanding the Data

### Secondary Amplitude Ratio
The key metric for hit vs. miss detection:
- **Hits**: Two spikes (gunshot + steel ding), ratio typically 0.40-0.95
- **Misses**: One spike (gunshot only), ratio typically <0.25

### Good Calibration Indicators
✅ **High separation** (>0.40): Clear distinction between hits and misses
✅ **High confidence** (>80%): Minimal overlap between hit and miss ranges
✅ **Consistent ranges**: Tight min-max spread within each category

### Warning Signs
⚠️ **Low separation** (<0.20): Overlapping ranges, may need more samples
⚠️ **Low confidence** (<50%): Inconsistent data, check microphone position
⚠️ **Wide ranges**: Large variation, may need to separate by distance

## Best Practices

### Sample Collection
1. **Be honest**: Label shots accurately (it's for training, not bragging!)
2. **Vary distances**: Include shots from different ranges
3. **Consistent setup**: Use the same microphone position throughout
4. **Minimize noise**: Avoid calibrating on a busy range if possible
5. **More is better**: 20+ of each gives more reliable thresholds

### When to Recalibrate
- Moving to a new range
- Changing microphone position
- Different target setup
- Detection seems inaccurate
- Every few months as a tune-up

### Pro Tips
- Calibrate at the range you use most
- Start with medium distance, then add close/far
- If you shoot Outer Limits often, include "very far" samples
- Save multiple calibration sessions for different ranges
- Test after calibration: fire 5 known hits/misses and verify

## Technical Details

### Data Collected Per Shot
- Peak amplitude
- Secondary amplitude ratio (primary metric)
- Delay between gunshot and steel ding (ms)
- High frequency energy (>2kHz)
- RMS energy

### Threshold Calculation
```
Optimal threshold = missAvg + (separation × 0.6)
```
- Places threshold 60% of the way from miss average to hit average
- Biased toward avoiding false positives (better to miss a hit than call a miss a hit)
- Confidence based on minimum separation between hit min and miss max

### Storage
- All calibration sessions saved to UserDefaults
- Can view previous sessions (future feature)
- Persists across app restarts

## Troubleshooting

### "Not detecting shots"
- Ensure Shot Detection is enabled in Settings
- Check microphone permissions
- Increase sensitivity slider
- Verify timer is reporting shots (BLE connection)

### "Ratios all very low (<0.20)"
- Microphone too far from targets
- Targets too far away
- Try closer distances first
- Check if steel plates are making audible "ding"

### "Ratios all very high (>0.80) even for misses"
- Microphone too close to targets
- Background noise creating false secondary peaks
- Move microphone farther from targets
- Calibrate in quieter conditions

### "Inconsistent results"
- Collect more samples (30+ each)
- Ensure consistent microphone position
- Separate by distance (calibrate each distance separately - future feature)
- Check for environmental factors (wind, other shooters)

## Future Enhancements

Planned improvements:
- [ ] Distance-specific profiles (auto-select based on stage)
- [ ] Visual waveform display during calibration
- [ ] History of calibration sessions
- [ ] Export/import calibration data
- [ ] Auto-calibration mode (machine learning)
- [ ] Per-stage calibration profiles
- [ ] Confidence visualization on hits
- [ ] Real-time detection testing mode

## Example Session

```
Session: Range Day 2025-10-26

Distance: Medium (10-15 yards)
1. BANG! → "HIT" ✓ (ratio: 0.82, delay: 45ms)
2. BANG! → "HIT" ✓ (ratio: 0.76, delay: 42ms)
3. BANG! → "MISS" ✗ (ratio: 0.18, delay: 38ms)
...

Distance: Far (15-25 yards)
11. BANG! → "HIT" ✓ (ratio: 0.52, delay: 78ms)
12. BANG! → "MISS" ✗ (ratio: 0.22, delay: 65ms)
...

Results:
- 22 samples (12 hits, 10 misses)
- Hit range: 0.52 - 0.95 (avg: 0.71)
- Miss range: 0.15 - 0.24 (avg: 0.19)
- Recommended threshold: 0.50
- Separation: 0.52
- Confidence: 92%

✅ Applied!
```

## Support

Having issues with calibration? Check:
1. Debug console output (shows acoustic analysis for each shot)
2. AUDIO_ANALYSIS_FINDINGS.md for baseline data
3. Ensure BLE timer is connected and working
4. Test with default settings first before calibrating

Remember: Calibration is optional! The default thresholds work well for typical setups. Only calibrate if you're experiencing accuracy issues or want to optimize for your specific environment.
