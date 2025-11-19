# Comment & Log Standards

**ID**: `impl-comment-log-standards`
**Status**: Active
**Last Updated**: 2025-11-19

This document defines the mandatory comment and debug log standards for Claude Code when working with the clock-tsukiusagi codebase. The core principle: **learning comes first, cleanup comes last**.

---

## Core Philosophy

This project prioritizes **learning and understanding** during development. Claude Code must help the user (Azu) learn by adding explanatory comments to all code modifications. Production cleanup happens only when explicitly requested.

---

## ✂️ Learning Comment Generation Rule (MANDATORY)

### Default Behavior

**Claude Code MUST automatically add ✂️ learning comments whenever generating or modifying code.**

This is the **default mode** for all development sessions. Do not skip or omit comments unless explicitly instructed to do so.

### When to Add Learning Comments

Claude Code must add ✂️ comments in these situations:

1. **Every code modification or generation**
2. **Complex logic or non-obvious implementations**
3. **Important design decisions or trade-offs**
4. **Potential side effects or gotchas**
5. **Background context for why this approach was chosen**

### ✂️ vs Permanent Comments: What to Mark

**IMPORTANT**: Not all comments should have ✂️ markers. Distinguish between temporary learning comments and permanent documentation comments.

#### ✂️ Mark These (Temporary Learning Comments)

Use ✂️ for comments that explain **why you made specific implementation choices during development**:

- Technical reasons for choosing one approach over another
- Explanations of workarounds or fixes for specific issues
- Details about library limitations or SwiftUI quirks
- Step-by-step reasoning behind complex logic
- Calculations or formulas with derivation details
- Temporary notes about trade-offs or alternatives considered

**Examples**:
```swift
// ✂️ Using Menu instead of Picker because .menu style doesn't respect .foregroundColor()
// ✂️ GeometryReader was removed to prevent VStack spacing issues
// ✂️ 70% of card (which is 70% of screen) = 0.7 × 0.7 = 0.49
// ✂️ Reduced to account for Large Title's built-in bottom spacing
```

#### ❌ DON'T Mark These (Permanent Documentation Comments)

Do NOT use ✂️ for comments that describe **what the code does or important specifications**:

- Feature descriptions or functional specifications
- Important warnings or gotchas for future developers
- Business logic explanations
- API usage notes that should remain long-term
- Architectural decisions that define the codebase structure
- Section markers or organizational comments

**Examples**:
```swift
// Audio アイコンは非表示（現在のページ）
// MARK: - Sections
// Important: Volume limiter must be applied before final output
// This implements the Calm Technology philosophy by...
// Falls back to speaker if headphones are disconnected
```

#### Decision Framework

Ask yourself: **"Is this explaining my implementation choice, or is this documenting what the code does?"**

- **Implementation choice** → Use ✂️ (temporary)
- **Code documentation** → No ✂️ (permanent)

Another way to think about it:

- **"I chose this because..."** → ✂️
- **"This code does..."** → No ✂️

### Comment Content Guidelines

Learning comments should explain:

- **Intent** (修正意図): Why this change was made
- **Background** (背景): Context or problem being solved
- **Rationale** (選択理由): Why this approach over alternatives
- **Caveats** (注意点): Side effects, limitations, or future considerations

### Example: Good Learning Comments

```swift
// ✂️ Using Menu instead of Picker because .menu style doesn't respect .foregroundColor()
// ✂️ This custom implementation gives us full control over text color and layout
Menu {
    ForEach(sources) { source in
        Button(action: { selectedSource = source }) {
            Text(source.displayName)
        }
    }
} label: {
    // ✂️ HStack with Spacer() creates justified layout: text left, chevron right
    HStack {
        Text(selectedSource.displayName)
            .foregroundColor(.black)  // ✂️ Black for readability on bright background
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
    }
}
```

### Example: Insufficient Comments (❌ AVOID)

```swift
// Changed to Menu
Menu { ... }
```

**Problem**: Doesn't explain *why* the change was made or what problem it solves.

---

## Learning Session vs. Production Mode

### Default: Learning Session Mode (Always ON)

**Claude Code operates in "learning session mode" by default.**

Assumptions in this mode:
- User wants to understand every change
- Comments are valuable learning artifacts
- Code cleanliness is secondary to comprehension
- ✂️ markers will be cleaned up later when explicitly requested

### Exception: Production Cleanup Mode (Explicitly Triggered)

**Only enter cleanup mode when user explicitly requests it** with phrases like:

- "Clean up the code for production"
- "Remove all learning comments"
- "Prepare for merge/release"
- "クリーンナップして" (Japanese: clean up)
- "リリース用に" (Japanese: for release)

**DO NOT** assume production mode just because:
- Code is in a certain file or directory
- Code looks "production-ready"
- A commit is being made
- Time has passed since initial implementation

---

## ✂️ Comment Cleanup Workflow

### When to Remove ✂️ Comments

**Only remove ✂️ comments when explicitly instructed by the user.**

Typical cleanup triggers:
1. User says "Clean up for production"
2. User says "Remove learning comments"
3. User requests pre-merge cleanup
4. User specifies release preparation

### How to Clean Up

1. Search for all ✂️ markers:
   ```bash
   grep -r "✂️" clock-tsukiusagi/
   ```

2. Review each comment:
   - **Delete the entire comment** if it's temporary learning content (e.g., "✂️ Using Menu instead of Picker because...")
   - **Remove only the ✂️ marker** if the comment has evolved into permanent documentation
   - **Keep as-is** if it's essential technical context that should remain

3. Verify no ✂️ markers remain before committing

**Decision Guide**:
- "✂️ This fixes the spacing issue by..." → **Delete entire comment**
- "✂️ Falls back to speaker if headphones are disconnected" → **Remove ✂️, keep comment**
- "// MARK: - Sections" → **Keep as-is** (should never have ✂️)

### Cleanup Checklist

Before finalizing cleanup:

- [ ] All ✂️ markers removed or converted to permanent comments
- [ ] No temporary learning comments remain
- [ ] Permanent documentation comments are clear and concise
- [ ] Code is self-documenting where possible

---

## 🔥 Debug Log Emoji Rule

### Emoji Tags for Temporary Logs

All temporary debug logs must include a specific emoji tag:

| Emoji | Purpose | Example |
|-------|---------|---------|
| **🔥** | Temporary debug logs (must be deleted) | `print("🔥 [Debug] Current value: \(value)")` |
| **🐛** | Bug investigation logs | `print("🐛 [Bug] Investigating issue #123")` |
| **🧪** | Experimental / testing logs | `print("🧪 [Test] Feature flag enabled")` |

### Usage Guidelines

```swift
// ✅ Correct - tagged for removal
print("🔥 [Debug] Audio engine state: \(engine.isRunning)")
print("🐛 [Bug] Route change detected: \(route.displayName)")
print("🧪 [Test] Experimental signal processing active")

// ❌ Wrong - production logs without cleanup markers
print("Debug: Current volume level")
print("Testing new feature...")
```

### Cleanup

Remove all 🔥 / 🐛 / 🧪 logs during production cleanup:

```bash
grep -r "🔥\|🐛\|🧪" clock-tsukiusagi/
```

---

## Benefits of This Approach

### For Learning (Development Phase)

1. **Accelerated Understanding**: User learns why decisions were made
2. **Context Preservation**: Rationale is captured at decision time
3. **No Cognitive Load**: User doesn't need to reverse-engineer intent
4. **Debugging Aid**: Comments help troubleshoot issues later

### For Production (Cleanup Phase)

1. **Clean Separation**: ✂️ markers make temporary vs. permanent obvious
2. **Easy Cleanup**: Single search operation finds all artifacts
3. **No Accidental Leftovers**: Visual markers prevent missed removals
4. **Professional Result**: Final code is clean and maintainable

---

## Important Reminders for Claude Code

### Distinguish ✂️ Learning Comments from Permanent Comments

- **DO**: Use ✂️ for implementation choices, workarounds, and technical reasoning
- **DO NOT**: Use ✂️ for feature descriptions, specifications, or MARK comments
- **Decision Test**: "Am I explaining WHY I chose this?" → ✂️ | "Am I explaining WHAT this does?" → No ✂️

**Examples**:
```swift
// ✂️ Using Menu instead of Picker because .menu style doesn't respect .foregroundColor()  ← YES ✂️
// Audio アイコンは非表示（現在のページ）  ← NO ✂️
// ✂️ Reduced to 8pt to account for Large Title's built-in bottom spacing  ← YES ✂️
// MARK: - Sections  ← NO ✂️
```

### Always Add Learning Comments (with Correct Marking)

- **DO**: Add explanatory comments to every code change
- **DO**: Explain intent, background, rationale, and caveats
- **DO**: Use ✂️ for temporary learning content, no ✂️ for permanent documentation
- **DO NOT**: Skip comments to "keep code clean"
- **DO NOT**: Assume user already understands the change

### Never Auto-Cleanup Without Instruction

- **DO**: Keep ✂️ comments throughout development
- **DO**: Wait for explicit cleanup request from user
- **DO NOT**: Remove ✂️ comments proactively
- **DO NOT**: Assume production mode without being told

### Treat Every Session as Learning

- **DO**: Default to learning session mode
- **DO**: Prioritize comprehension over brevity
- **DO NOT**: Make assumptions about "production readiness"
- **DO NOT**: Self-censor comments for cleanliness

---

## Search Commands

```bash
# Find all temporary learning comments
grep -r "✂️" clock-tsukiusagi/

# Find all temporary debug logs
grep -r "🔥\|🐛\|🧪" clock-tsukiusagi/

# Find all temporary artifacts (comments + logs)
grep -r "✂️\|🔥\|🐛\|🧪" clock-tsukiusagi/
```

---

## CI/CD Integration (Future)

Automated pre-merge check:

```bash
# Fail build if temporary markers found
if grep -r "✂️\|🔥\|🐛\|🧪" clock-tsukiusagi/; then
  echo "❌ Temporary artifacts found - run cleanup before merging"
  exit 1
fi
```

---

## Related Documents

- `CLAUDE.md` — Main development guidance
- `clock-tsukiusagi/Docs/_guide-error-resolution.md` — Error resolution process
- `ENGINEERING_RULES.md` — Project-wide development rules

---

## Summary

**Default Behavior**: Claude Code always adds ✂️ learning comments to help user understand changes.

**Cleanup Trigger**: Only remove ✂️ comments when user explicitly requests production cleanup.

**Core Principle**: Learning comes first, cleanup comes last.
