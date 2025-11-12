# Claude Code Quick Reference for GMJuice

## 🚀 Quick Start

You now have a complete Claude Code setup for GMJuice development! Here's what's available:

## Available Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/design-feature` | Design new features with architectural guidance | Before implementing major features |
| `/review` | Comprehensive code review | Before committing or during PR review |
| `/pre-commit` | Run all pre-commit validation checks | Before every commit |

## Available Agents

### test-framework-architect (Built-in)
Use for setting up testing infrastructure and writing tests.

**Example usage:**
```
I need to add unit tests for BLEManager
```

Claude will automatically launch the test-framework-architect agent to help you.

## Typical Workflows

### 🎨 Designing a New Feature
```
/design-feature
I want to add a feature to export session data as PDF
```

1. Claude guides you through architectural design
2. You get a structured implementation plan
3. Implement the feature following the design
4. Use `/review` when done
5. Run `/pre-commit` before committing

### 🔍 Code Review
```
/review
```

1. Claude analyzes your git changes
2. Reviews for code quality, architecture, bugs
3. Provides actionable feedback
4. You make improvements
5. Run `/pre-commit` to validate

### ✅ Pre-Commit Validation
```
/pre-commit
```

1. Builds the project
2. Runs code quality checks
3. Validates architecture patterns
4. Checks for sensitive data
5. Gives you a clear commit readiness verdict

### 🧪 Adding Tests
```
I need to add unit tests for RecordingViewModel
```

1. Claude launches test-framework-architect automatically
2. Sets up test infrastructure if needed
3. Creates comprehensive test examples
4. Documents testing patterns

## 🎯 Best Practices

### Daily Development
- Start with `/design-feature` for anything non-trivial
- Run `/pre-commit` before every commit
- Use `/review` for self-review of larger changes

### Team Collaboration
- Share the `.claude` directory (already in git)
- Use `/review` to analyze teammate's PRs
- Consistent code quality across the team

### Quality Gates
1. Design → `/design-feature`
2. Implement → code the feature
3. Review → `/review`
4. Validate → `/pre-commit`
5. Test → use test-framework-architect
6. Commit → with confidence!

## 💡 Pro Tips

### Combining Commands
You can chain multiple operations:
```
/review
```
Then after addressing issues:
```
/pre-commit
```

### Using with Git
```bash
# After making changes
git status
/pre-commit  # Validate everything
git add .
git commit -m "Your message"
```

### Getting Context-Aware Help
All commands understand your project:
- They know about GMJuice architecture (singletons, SwiftData, etc.)
- They reference CLAUDE.md for project guidelines
- They understand Steel Challenge domain context

### Tab Completion
Type `/` and start typing - Claude Code will show available commands

## 🔧 Customization

Want to modify a command? Edit the files in `.claude/commands/`:
- `design-feature.md` - Feature design process
- `review.md` - Code review criteria
- `pre-commit.md` - Validation checks

Changes take effect immediately!

## 📝 Examples

### Example 1: Adding a new stage
```
/design-feature
I want to add support for SCSA (Steel Challenge Speed Shooting Association) in addition to USPSA
```

### Example 2: Reviewing your work
```
# After implementing a feature
git add .
/review
# Fix any issues found
/pre-commit
# If all clear, commit!
git commit -m "Add SCSA support"
```

### Example 3: Adding tests
```
I want to add unit tests for the PeakBenchmark calculations
```

## 🆘 Need Help?

- View all commands: Type `/` and browse
- Command documentation: Check `.claude/commands/*.md`
- Project guidelines: See `CLAUDE.md`
- Claude Code docs: https://code.claude.com/docs

## 🎉 You're All Set!

Start using these commands in your development workflow. They're designed to:
- Save you time
- Improve code quality
- Catch issues early
- Make development more enjoyable

**Happy coding! 🚀**
