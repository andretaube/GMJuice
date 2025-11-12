# GMJuice Claude Code Configuration

This directory contains custom configurations for Claude Code to assist with GMJuice development.

## 📋 Custom Slash Commands

### `/design-feature`
**Purpose**: Get help designing new features with architectural guidance

**When to use**:
- Planning a new feature or major enhancement
- Need architectural advice for complex changes
- Want to ensure consistency with existing patterns

**What it does**:
- Guides you through a structured design process
- Analyzes architecture impact
- Creates implementation plans
- Considers trade-offs and alternatives

**Example**:
```
/design-feature I want to add a feature to compare my times against other shooters
```

---

### `/review`
**Purpose**: Comprehensive code review of your changes

**When to use**:
- Before committing significant changes
- After implementing a feature
- When you want a second pair of eyes on your code

**What it does**:
- Reviews code quality and Swift best practices
- Checks SwiftUI and SwiftData usage
- Verifies architecture compliance
- Identifies potential bugs and edge cases
- Assesses user experience and accessibility

**Example**:
```
/review
```
(Automatically detects git changes and reviews them)

---

### `/pre-commit`
**Purpose**: Run comprehensive pre-commit validation checks

**When to use**:
- Before every commit (make it a habit!)
- After completing a feature or bug fix
- When you want to ensure code quality

**What it does**:
- Builds the project to verify compilation
- Scans for code quality issues
- Checks SwiftData schema changes
- Validates architecture patterns
- Looks for sensitive data or debug code
- Provides a clear commit readiness verdict

**Example**:
```
/pre-commit
```

---

## 🪝 Optional Hooks Configuration

You can add automated hooks to run checks at specific points in the Claude Code workflow. To configure hooks, run the `/hooks` command in Claude Code.

### Example: Auto-format Swift files after edits

Add this to your Claude Code settings (user or project level):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$TOOL_INPUT_FILE_PATH\" =~ \\.swift$ ]]; then echo '✓ Swift file modified: $TOOL_INPUT_FILE_PATH'; fi"
          }
        ]
      }
    ]
  }
}
```

### Example: Log all bash commands

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date)] Running: $TOOL_INPUT_COMMAND\" >> ~/.claude/gmjuice-bash-log.txt"
          }
        ]
      }
    ]
  }
}
```

### Example: Prevent accidental edits to critical files

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$TOOL_INPUT_FILE_PATH\" =~ (GMJuice\\.entitlements|Info\\.plist)$ ]]; then echo '⚠️  WARNING: Editing critical project file: $TOOL_INPUT_FILE_PATH'; fi"
          }
        ]
      }
    ]
  }
}
```

## 🎯 Best Practices

### Feature Development Workflow
1. Use `/design-feature` to plan your feature
2. Implement the feature following the design
3. Use `/review` to check your code
4. Run `/pre-commit` before committing
5. Commit with confidence!

### Quick Fixes Workflow
For small bug fixes or tweaks:
1. Make your changes
2. Run `/pre-commit` to validate
3. Commit

### Code Review Workflow
When reviewing someone else's PR:
1. Check out their branch
2. Run `/review` to get an automated analysis
3. Supplement with your own manual review

## 🔧 Customization

You can customize these commands by editing the markdown files in `.claude/commands/`:

- `design-feature.md` - Adjust the design process or guidelines
- `review.md` - Modify review criteria or focus areas
- `pre-commit.md` - Add/remove validation checks

Changes to these files take effect immediately - no restart needed!

## 📚 Additional Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [GMJuice Project Guidelines](../CLAUDE.md)
- [Custom Slash Commands Guide](https://code.claude.com/docs/en/slash-commands)
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide)

## 💡 Tips

- **Tab completion**: Type `/` and start typing to see available commands
- **Command history**: Use arrow keys to navigate through previous commands
- **Combine with git**: These commands work great with git workflows
- **Share with team**: Commit the `.claude` directory to share these tools with your team

---

**Note**: These commands are powered by Claude Code and use natural language prompts. They adapt to your specific changes and context automatically.
