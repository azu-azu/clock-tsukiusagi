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

**Guiding Principle**: In production code, comments should be minimal and only explain **non-obvious information**. Most code should be self-documenting through clear naming and structure.

#### ✂️ Mark These (Temporary Learning Comments)

Use ✂️ for comments that explain **your development process and decision-making**:

- Step-by-step reasoning during implementation
- Verbose explanations of what the code does (should be self-explanatory)
- Redundant calculations already evident in code
- Progress notes or implementation status
- Overly detailed justifications for straightforward choices

**Examples**:
```swift
// ✂️ This custom implementation gives us full control over text color and layout
// ✂️ HStack with Spacer() creates justified layout: text left, chevron right
// ✂️ 70% of card (which is 70% of screen) = 0.7 × 0.7 = 0.49
// ✂️ Black for readability on bright background
```

#### ❌ DON'T Mark These (Permanent Documentation Comments)

Do NOT use ✂️ for comments that prevent future developers from repeating mistakes or misunderstanding critical behavior:

- **Technical gotchas and pitfalls**: Known issues with libraries/frameworks that cause problems
- **Non-obvious workarounds**: Why a seemingly strange approach is necessary
- **Critical constraints**: System limitations or requirements that affect design
- **Business logic**: Domain-specific rules that aren't apparent from code alone
- **Section markers**: MARK comments for code organization

**Keep comments minimal—only document what isn't obvious.**

**Examples**:
```swift
// GeometryReader prevents VStack spacing from working correctly
// Picker's .menu style doesn't respect .foregroundColor() modifier
// No top padding needed: Large Title mode provides built-in spacing
// Audio icon hidden on current page
// MARK: - Sections
```

#### Decision Framework

Ask yourself: **"Would removing this comment cause future developers to waste time or repeat my mistakes?"**

- **YES** → No ✂️ (critical knowledge, keep it)
- **NO** → ✂️ (learning content, remove later)

Another test: **"Is this obvious from the code itself?"**

- **YES** → ✂️ (redundant, remove later)
- **NO** → Evaluate: Is it a gotcha/constraint? → No ✂️ | Is it my thought process? → ✂️

**Default mindset**: Favor self-documenting code over comments. Only add comments when necessary.

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

- **DO**: Use ✂️ for your thought process, step-by-step reasoning, and redundant explanations
- **DO NOT**: Use ✂️ for technical gotchas, critical constraints, or non-obvious workarounds
- **DO**: Keep permanent comments minimal—only document what prevents future mistakes
- **Decision Test**: "Would removing this waste someone's time?" → No ✂️ | "Is this my development notes?" → ✂️

**Examples**:
```swift
// ✂️ This custom implementation gives us full control  ← YES ✂️ (verbose, obvious)
// GeometryReader prevents VStack spacing from working correctly  ← NO ✂️ (gotcha)
// ✂️ HStack with Spacer() creates justified layout  ← YES ✂️ (redundant)
// Picker's .menu style doesn't respect .foregroundColor() modifier  ← NO ✂️ (framework limitation)
// MARK: - Sections  ← NO ✂️ (organizational)
```

### Always Add Learning Comments (with Correct Marking)

- **DO**: Add explanatory comments during development to aid your learning
- **DO**: Use ✂️ for verbose explanations, step-by-step reasoning, and development notes
- **DO**: Preserve critical gotchas and constraints WITHOUT ✂️ for production
- **DO**: Favor self-documenting code—keep final comments minimal
- **DO NOT**: Add unnecessary comments that restate obvious code behavior

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
