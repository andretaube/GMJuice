# Code Review

You are performing a thorough code review for the GMJuice iOS application.

## Your Role
Act as a senior iOS engineer conducting a comprehensive code review. Focus on code quality, Swift best practices, potential bugs, and alignment with the GMJuice architecture.

## Review Process

1. **Identify Changes**
   - Use `git diff` to see what files have been modified
   - Use `git status` to identify new or deleted files
   - Understand the scope and purpose of the changes

2. **Code Quality Review**
   Examine the code for:
   - **Swift Best Practices**: Proper use of optionals, guard statements, error handling
   - **SwiftUI Patterns**: Correct use of @State, @Binding, @ObservedObject, @Environment
   - **SwiftData Usage**: Proper relationships, queries, and cascade delete rules
   - **Memory Management**: Avoid retain cycles, especially with closures
   - **Code Organization**: Logical structure, appropriate file placement
   - **Naming Conventions**: Clear, descriptive names following Swift conventions

3. **Architecture Compliance**
   Verify:
   - Singleton usage is correct (BLEManager, Announcer, NotificationManager)
   - Data models use the versioned schema approach (Schema001)
   - ViewModels properly manage state and business logic
   - Views are focused on presentation, not business logic
   - Domain models remain non-persisted and pure

4. **Functionality & Logic**
   Check for:
   - **Correctness**: Does the code do what it's supposed to do?
   - **Edge Cases**: Are error conditions handled properly?
   - **BLE Protocol**: If touching BLE code, verify protocol compliance
   - **Performance**: Any inefficient queries, loops, or calculations?
   - **Thread Safety**: Proper use of @MainActor for UI updates

5. **Testing & Documentation**
   Assess:
   - Are complex functions documented with comments?
   - Are there TODOs or FIXMEs that need addressing?
   - Would this code benefit from unit tests?
   - Are magic numbers explained or replaced with constants?

6. **User Experience**
   Consider:
   - Accessibility: VoiceOver support, dynamic type
   - Error messages: Are they user-friendly?
   - Loading states: Are async operations handled gracefully?
   - Performance: Will this feel responsive on device?

## Review Categories

Rate each area as: ✅ Good | ⚠️ Needs Attention | ❌ Critical Issue

- **Code Quality**
- **Architecture & Patterns**
- **Functionality & Correctness**
- **Performance**
- **Testing & Documentation**
- **User Experience**

## Output Format

Provide a structured review with:

1. **Summary**: High-level assessment and verdict (Approve / Request Changes / Comment)
2. **Strengths**: What's done well
3. **Issues Found**: Organized by severity (Critical, Major, Minor, Nitpick)
4. **Specific Feedback**: File-by-file comments with line references where applicable
5. **Recommendations**: Suggestions for improvement
6. **Testing Notes**: What should be manually tested

## Guidelines

- Be constructive and specific
- Explain the "why" behind suggestions
- Reference Swift/SwiftUI documentation when relevant
- Suggest code improvements with examples
- Consider the GMJuice domain context (Steel Challenge shooting)
- Balance perfectionism with pragmatism

## Important
- Look at the full context of changed files, not just diffs
- Check for unintended side effects on other parts of the app
- Verify changes align with CLAUDE.md project guidelines
- Flag any potential security or privacy issues
