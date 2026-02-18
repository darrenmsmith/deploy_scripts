# Phase 7 Update: Automatic Version Selection

**Date:** 2026-01-02
**Updated:** phase7_fieldtrainer.sh

---

## What Changed

Phase 7 now **automatically detects and defaults to the latest stable release** instead of the main branch.

### Before (Old Behavior)
```
Enter branch name to clone (default: main):
```
- Default: main branch
- Manual entry required for specific versions

### After (New Behavior)
```
Fetching available releases from GitHub...
Latest release: v2025.12.31

Version options:
  1. v2025.12.31 (latest release - RECOMMENDED)
  2. main (bleeding edge - latest development)
  3. Custom version/branch

Select option (1/2/3, default: 1):
```
- Default: **Latest stable release tag** (v2025.12.31)
- Easy menu selection
- Clear recommendation

---

## How It Works

1. **Fetches available releases** from GitHub repository
2. **Identifies latest release tag** (e.g., v2025.12.31)
3. **Presents menu** with 3 options
4. **Defaults to option 1** (latest stable release)

---

## User Experience

### For Most Users (Just Press Enter)
```
Select option (1/2/3, default: 1): [ENTER]
Selected: v2025.12.31 (latest stable release)
```

**Result:** Installs latest stable, tested release

### For Developers (Option 2)
```
Select option (1/2/3, default: 1): 2
Selected: main branch (development)
```

**Result:** Installs bleeding-edge development version

### For Specific Version (Option 3)
```
Select option (1/2/3, default: 1): 3
Enter custom version tag or branch name: v2025.12.31
Selected: v2025.12.31
```

**Result:** Installs specific older version

---

## Benefits

✅ **Always gets stable release** by default
✅ **No manual version lookup** required
✅ **Easy to select specific version** if needed
✅ **Clear recommendation** (option 1)
✅ **Fallback to main** if tags unavailable

---

## Rollback to Previous Release

See: `/mnt/usb/RELEASE_VERSION_MANAGEMENT.md`

**Quick rollback:**
```bash
sudo systemctl stop field-trainer
cd /opt
git fetch --tags
sudo git checkout v2025.12.31
sudo systemctl start field-trainer
```

---

## Documentation Updated

1. **phase7_fieldtrainer.sh** - Version selection logic
2. **FRESH_INSTALL_GUIDE.md** - Installation instructions
3. **RELEASE_VERSION_MANAGEMENT.md** - Version management guide (NEW)
4. **VERSION_SELECTION_UPDATE.md** - This file (NEW)

---

## Testing

To test on your fresh install:

```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase7_fieldtrainer.sh
```

You'll see:
1. Repository URL prompt (press Enter)
2. **Version selection** (press Enter for latest)
3. Database initialization
4. Installation proceeds...

---

**Status:** ✅ Ready for fresh installations
