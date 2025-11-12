# Pre-Commit Checks

Run comprehensive pre-commit validation checks before committing code to the GMJuice repository.

## Automated Checks

Perform the following checks in order:

1. **Git Status Check**
   - Run `git status` to identify all changed files
   - Verify you understand what's being committed
   - Flag any unexpected changes or files

2. **Swift Compilation Check**
   - Build the project to ensure it compiles without errors
   - Run: `xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Debug build`
   - Report any compilation errors or warnings
   - Pay special attention to new warnings introduced by changes

3. **Code Quality Scan**
   Review changed Swift files for:
   - **Syntax Issues**: Proper Swift syntax and formatting
   - **Force Unwrapping**: Excessive use of `!` operators (flag for review)
   - **Print Statements**: Debug `print()` calls that should be removed
   - **TODO/FIXME**: Document any technical debt markers
   - **Commented Code**: Large blocks of commented code that should be removed
   - **Magic Numbers**: Hardcoded values that should be constants

4. **SwiftData Schema Check**
   If Schemas.swift was modified:
   - Verify schema versioning is handled correctly
   - Check that ModelAliases.swift is updated if needed
   - Ensure migration path exists for breaking changes
   - Confirm @Relationship delete rules are appropriate

5. **Architecture Compliance**
   Verify:
   - Singletons (BLEManager, Announcer, NotificationManager) are used correctly
   - No business logic in Views (should be in ViewModels)
   - SwiftUI property wrappers are used appropriately
   - No retain cycles in closures (check [weak self] usage)

6. **Sensitive Data Check**
   - Ensure no API keys, tokens, or credentials are hardcoded
   - Verify .gitignore is preventing sensitive files from being tracked
   - Check for accidentally committed test data or personal information

7. **Documentation Check**
   - If CLAUDE.md was referenced, verify it's still accurate
   - Check that significant changes are reflected in code comments
   - Verify README or docs are updated if public APIs changed

## Validation Criteria

The commit is ready if:
- ✅ Project builds successfully with zero errors
- ✅ No critical code quality issues found
- ✅ No sensitive data is being committed
- ✅ Architecture patterns are followed
- ✅ SwiftData schema changes are properly versioned (if applicable)

## Output Format

Provide a clear report:

1. **Build Status**: Pass/Fail with error details
2. **Code Quality**: Issues found (categorized by severity)
3. **Architecture Review**: Any violations of GMJuice patterns
4. **Warnings**: Things to review before committing
5. **Verdict**: ✅ Safe to Commit | ⚠️ Review Warnings | ❌ Fix Issues First

## What to Report

- **Critical Issues** (must fix): Compilation errors, sensitive data exposure
- **Major Issues** (should fix): Architecture violations, potential bugs
- **Minor Issues** (consider fixing): Code style, unnecessary comments, minor optimizations
- **Warnings** (informational): New TODOs, increased warning count

## Guidelines

- Be thorough but don't block trivial improvements
- Provide specific file and line references for issues
- Suggest fixes for common problems
- Prioritize issues by impact and severity
- Remember this is a SwiftUI/iOS project context

## Important
- Always run the actual build command to verify compilation
- Don't just assume code will work - test it
- If SwiftData schemas changed, triple-check the migration path
- Consider the impact on users with existing data
