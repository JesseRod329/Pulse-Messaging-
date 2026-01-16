# Fix Compilation Errors

## Quick Fix Summary

### Error 1: `Cannot find 'SentMessageCache' in scope`

**Cause:** `SentMessageCache.swift` exists but is not added to the Xcode project target.

**Fix:**
1. Open `/Users/jesse/pulse/Pulse/Pulse.xcodeproj` in Xcode
2. In the Project Navigator, find `Managers` folder
3. Right-click → "Add Files to Pulse..."
4. Select `Managers/SentMessageCache.swift`
5. Uncheck "Copy items if needed"
6. Check the **Pulse** target checkbox
7. Click "Add"
8. Clean build folder: `Cmd + Shift + K`
9. Build: `Cmd + B`

---

### Error 2: `Extra argument 'plaintext' in call` (line 426)

**Cause:** `saveGroupMessage` function still uses old `PersistedMessage` initializer with `plaintext` parameter.

**Fix:** Already applied - this should resolve after adding SentMessageCache to target.

---

### Error 3: `Type 'Font?' has no member 'pulsePageTitle'`

**Cause:** Xcode indexing issue or incomplete build.

**Fix:**
1. Clean build folder: `Cmd + Shift + K`
2. Close Xcode completely
3. Reopen Xcode
4. Build: `Cmd + B`

Alternatively, verify the font exists:
```swift
// Typography.swift lines 39-42
static var pulsePageTitle: Font {
    .custom("SF Mono", size: Typography.title)
        .weight(.bold)
}
```

---

## Command Line Build Fix

If you prefer command line:

```bash
cd /Users/jesse/pulse/Pulse

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Pulse-*

# Open Xcode (will reindex)
open Pulse.xcodeproj

# In Xcode: Product → Clean Build Folder (Cmd + Shift + K)
# Then: Product → Build (Cmd + B)
```

---

## Verify Files Exist

```bash
# Check SentMessageCache exists
ls -la Pulse/Pulse/Managers/SentMessageCache.swift

# Check Typography has pulsePageTitle
grep "pulsePageTitle" Pulse/Pulse/Utilities/Typography.swift

# Check PersistedMessage doesn't have plaintext
grep "var plaintext" Pulse/Pulse/Models/PersistedMessage.swift
# Should return nothing
```

---

## Expected Output

After fixes, all files should compile with zero errors:
- ✅ SentMessageCache found
- ✅ No plaintext parameter errors
- ✅ Font extensions available
- ✅ All Swift files build successfully

---

## Still Having Issues?

If errors persist after following these steps:

1. **Check Build Settings:**
   - Select Pulse target
   - Build Settings → Swift Compiler - Search Paths
   - Verify "Framework Search Paths" includes project directory

2. **Check File Target Membership:**
   - Select each new file
   - File Inspector (Cmd + Option + 1)
   - Verify "Target Membership" → Pulse is checked

3. **Reinstall Xcode:**
   - Last resort - Xcode corruption can cause indexing issues
