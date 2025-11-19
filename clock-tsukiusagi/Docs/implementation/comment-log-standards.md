# Comment & Log Standards

**ID**: `impl-comment-log-standards`
**Status**: Active
**Last Updated**: 2025-11-19

This document defines standards for comments and debug logs in the clock-tsukiusagi codebase to maintain code cleanliness and prevent accidental inclusion of temporary debugging artifacts in production.

---

## Overview

During development, temporary comments and logs are useful for learning and debugging. However, production code must remain clean and professional. This standard provides a systematic approach to distinguish temporary artifacts from permanent documentation.

---

## ✂️ Rule for Learning Comments

### Purpose

Temporary comments added for personal understanding or debugging must be clearly marked and removed before production deployment.

### Emoji Marker

All temporary learning comments must include a **✂️ (scissors)** mark:

```swift
// ✂️ This is a temporary learning comment - remove before production
// This is a permanent documentation comment - keep in production
```

### When to Use

- Personal understanding notes during development
- Temporary explanations for complex logic
- Debugging annotations
- Learning references

### When NOT to Use

- API documentation
- Architecture explanations
- Important warnings or caveats
- Production-ready inline comments

### Workflow

1. **During Development**: Add ✂️ to all temporary learning comments
2. **Before Merging**: Search for "✂️" in the codebase and delete all matches
3. **Result**: Production code remains clean and professional

---

## Debug Log Emoji Rule

### Purpose

Debug logs are essential during development but must be removed before production to avoid noise and performance issues.

### Emoji Tags

All temporary debug logs must include a specific emoji tag:

| Emoji | Purpose | Example |
|-------|---------|---------|
| **🔥** | Temporary debug logs (must be deleted) | `print("🔥 [Debug] Current value: \(value)")` |
| **🐛** | Bug investigation logs | `print("🐛 [Bug] Investigating issue #123")` |
| **🧪** | Experimental / testing logs | `print("🧪 [Test] Feature flag enabled")` |

### Examples

```swift
// ✅ Correct - tagged for removal
print("🔥 [Debug] Audio engine state: \(engine.isRunning)")
print("🐛 [Bug] Route change detected: \(route.displayName)")
print("🧪 [Test] Experimental signal processing active")

// ❌ Wrong - production logs without cleanup markers
print("Debug: Current volume level")
print("Testing new feature...")
```

### Workflow

1. **During Development**: Add 🔥 / 🐛 / 🧪 to all temporary logs
2. **Before Merging**: Search for these emojis and delete all matches
3. **Result**: Production code has no debug noise

### Search Commands

```bash
# Find all temporary logs
grep -r "🔥\|🐛\|🧪" clock-tsukiusagi/

# Find all learning comments
grep -r "✂️" clock-tsukiusagi/
```

---

## Benefits

1. **Clear Distinction**: Temporary vs. permanent artifacts are immediately recognizable
2. **Easy Cleanup**: Single emoji search finds all items to remove
3. **No Accidental Leftovers**: Visual markers prevent forgetting cleanup
4. **Debugging Freedom**: Developers can add as many temporary notes as needed
5. **Production Quality**: Final code remains clean and professional

---

## Integration with Development Workflow

### Pull Request Checklist

Before creating a PR, verify:

- [ ] No ✂️ markers in code
- [ ] No 🔥 / 🐛 / 🧪 emoji logs
- [ ] All temporary debugging artifacts removed
- [ ] Only production-ready comments remain

### CI/CD Integration (Future)

Consider adding automated checks:

```bash
# Fail build if temporary markers found
if grep -r "✂️\|🔥\|🐛\|🧪" clock-tsukiusagi/; then
  echo "❌ Temporary debug artifacts found - remove before merging"
  exit 1
fi
```

---

## Related Documents

- `CLAUDE.md` — Main development guidance
- `clock-tsukiusagi/Docs/_guide-error-resolution.md` — Error resolution process
- `ENGINEERING_RULES.md` — Project-wide development rules

---

**Note**: This standard applies to all Swift code, configuration files, and scripts. Documentation files (`.md`) are exempt from emoji rules but should still maintain appropriate cleanup before major releases.
