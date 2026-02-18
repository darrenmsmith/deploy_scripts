# Field Trainer Release Version Management

**Updated:** 2026-01-02
**Repository:** https://github.com/darrenmsmith/field-trainer-releases

---

## Installation - Version Selection

### Phase 7 Now Defaults to Latest Release

When you run `phase7_fieldtrainer.sh`, it will:

1. **Fetch latest release from GitHub** (e.g., v2025.12.31)
2. **Show version options:**
   ```
   Version options:
     1. v2025.12.31 (latest release - RECOMMENDED)
     2. main (bleeding edge - latest development)
     3. Custom version/branch

   Select option (1/2/3, default: 1):
   ```

3. **Default to latest stable release** (option 1)
   - Just press Enter to use latest
   - Or choose option 2 for development version
   - Or choose option 3 for specific older version

---

## Viewing Available Releases

### On GitHub
Visit: https://github.com/darrenmsmith/field-trainer-releases/releases

Shows all releases with:
- Version number (e.g., v2025.12.31)
- Release date
- Features and changes
- Download links

### From Command Line

**List all release tags:**
```bash
git ls-remote --tags https://github.com/darrenmsmith/field-trainer-releases.git
```

**List just version numbers:**
```bash
git ls-remote --tags https://github.com/darrenmsmith/field-trainer-releases.git | grep -oP 'refs/tags/v\K[0-9.]+' | sort -V
```

Example output:
```
2025.12.31
2026.01.15
2026.02.01
```

---

## Check Currently Installed Version

After installation, check what version is running:

```bash
cd /opt

# Show current tag/version
git describe --tags

# Show current branch
git branch --show-current

# Show commit info
git log --oneline -1
```

**Example output:**
```
v2025.12.31
HEAD detached at v2025.12.31
8c8195b Prepare distributable release 2025.12.31
```

---

## Rolling Back to Previous Release

If you need to downgrade to an earlier version:

### Method 1: Switch to Specific Release Tag (Recommended)

```bash
# Stop the service
sudo systemctl stop field-trainer

# Go to application directory
cd /opt

# Fetch all tags
git fetch --tags

# List available versions
git tag -l "v*"

# Switch to specific version (e.g., v2025.12.31)
sudo git checkout v2025.12.31

# Restart service
sudo systemctl start field-trainer

# Verify version
git describe --tags
```

### Method 2: Complete Reinstall (Clean Slate)

```bash
# Stop the service
sudo systemctl stop field-trainer

# Backup database (optional but recommended)
sudo cp /opt/data/field_trainer.db /opt/data/field_trainer.db.backup_$(date +%Y%m%d_%H%M%S)

# Remove current installation
cd /opt
sudo rm -rf .git *

# Clone specific version
sudo git clone -b v2025.12.31 https://github.com/darrenmsmith/field-trainer-releases.git .

# Reinstall Python dependencies
sudo pip3 install -r requirements.txt

# Restart service
sudo systemctl start field-trainer
```

---

## Updating to Newer Release

### When New Release Available

Check GitHub: https://github.com/darrenmsmith/field-trainer-releases/releases

### Update Process

**Option A: Using Git (Preserves Database)**

```bash
# Stop service
sudo systemctl stop field-trainer

# Backup database (recommended)
sudo cp /opt/data/field_trainer.db /opt/data/field_trainer.db.backup_$(date +%Y%m%d_%H%M%S)

# Fetch latest tags
cd /opt
git fetch --tags

# Switch to new version (e.g., v2026.01.15)
sudo git checkout v2026.01.15

# Update Python dependencies (if changed)
sudo pip3 install -r requirements.txt

# Restart service
sudo systemctl start field-trainer

# Verify version
git describe --tags
```

**Option B: Re-run Phase 7 (Fresh Install)**

```bash
# Stop service
sudo systemctl stop field-trainer

# Backup database
sudo cp /opt/data/field_trainer.db ~/field_trainer.db.backup

# Run Phase 7 again
cd /mnt/usb/ft_usb_build/phases
sudo ./phase7_fieldtrainer.sh

# Choose option 1 (latest release) or option 3 (specific version)
```

---

## Version Compatibility

### Database Compatibility

**Between minor releases** (e.g., v2025.12.31 → v2026.01.15):
- Usually compatible
- Database migrations may be needed
- Check release notes

**Between major changes:**
- May require database reinitialization
- Backup your data first
- Check release notes for breaking changes

### Rollback Safety

**Safe to rollback:**
- ✅ Same database schema
- ✅ No new required fields
- ✅ Noted in release as "backward compatible"

**NOT safe to rollback:**
- ❌ Database schema changed
- ❌ New required tables added
- ❌ Breaking changes noted in release

**Always check release notes before upgrading or downgrading!**

---

## Common Scenarios

### Scenario 1: New Release Available, Want to Update

```bash
# 1. Check current version
cd /opt
git describe --tags
# Output: v2025.12.31

# 2. Check for new releases
git ls-remote --tags origin | grep -oP 'refs/tags/v\K[0-9.]+' | sort -V | tail -1
# Output: 2026.01.15

# 3. Backup database
sudo cp /opt/data/field_trainer.db ~/backup_before_update.db

# 4. Update to new version
sudo systemctl stop field-trainer
git fetch --tags
sudo git checkout v2026.01.15
sudo pip3 install -r requirements.txt
sudo systemctl start field-trainer

# 5. Verify
git describe --tags
sudo systemctl status field-trainer
```

### Scenario 2: Update Failed, Need to Rollback

```bash
# 1. Stop service
sudo systemctl stop field-trainer

# 2. Go back to previous version
cd /opt
sudo git checkout v2025.12.31

# 3. Restore database backup (if needed)
sudo cp ~/backup_before_update.db /opt/data/field_trainer.db

# 4. Restart service
sudo systemctl start field-trainer

# 5. Verify
git describe --tags
sudo systemctl status field-trainer
```

### Scenario 3: Testing New Release Before Committing

```bash
# 1. Note current version
cd /opt
CURRENT_VERSION=$(git describe --tags)
echo "Current: $CURRENT_VERSION"

# 2. Backup database
sudo cp /opt/data/field_trainer.db ~/test_backup.db

# 3. Test new version
sudo systemctl stop field-trainer
git fetch --tags
sudo git checkout v2026.01.15
sudo systemctl start field-trainer

# 4. Test the system...
# If problems occur:

# 5. Rollback
sudo systemctl stop field-trainer
sudo git checkout $CURRENT_VERSION
sudo cp ~/test_backup.db /opt/data/field_trainer.db
sudo systemctl start field-trainer
```

---

## Release Naming Convention

**Format:** `vYYYY.MM.DD`

**Examples:**
- `v2025.12.31` = Released December 31, 2025
- `v2026.01.15` = Released January 15, 2026
- `v2026.02.01` = Released February 1, 2026

**Why date-based?**
- Easy to identify when released
- Clear chronological order
- No semantic version confusion

---

## Best Practices

### Before Any Version Change

✅ **Always:**
1. Backup database
   ```bash
   sudo cp /opt/data/field_trainer.db ~/backup_$(date +%Y%m%d).db
   ```

2. Read release notes
   - Visit: https://github.com/darrenmsmith/field-trainer-releases/releases
   - Check for breaking changes
   - Note new features

3. Test on non-production system first (if possible)

4. Have rollback plan ready

### After Version Change

✅ **Verify:**
1. Service is running
   ```bash
   sudo systemctl status field-trainer
   ```

2. Web interface loads
   ```
   http://localhost:5000
   ```

3. Database intact
   ```bash
   sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM courses;"
   ```

4. No errors in logs
   ```bash
   sudo journalctl -u field-trainer -n 50
   ```

---

## Troubleshooting

### "Cannot Find Version Tag"

**Problem:** `git checkout v2026.01.15` fails

**Solution:**
```bash
# Fetch all tags from remote
git fetch --tags --force

# List available tags
git tag -l

# Try checkout again
sudo git checkout v2026.01.15
```

### "Modified Files Prevent Checkout"

**Problem:** Git won't switch versions due to local changes

**Solution:**
```bash
# See what's modified
git status

# Stash changes (save for later)
git stash

# Or discard changes (CAREFUL!)
sudo git reset --hard

# Then checkout version
sudo git checkout v2026.01.15
```

### "Service Won't Start After Update"

**Problem:** Field Trainer service fails after version change

**Solution:**
```bash
# Check logs for error
sudo journalctl -u field-trainer -n 100 --no-pager

# Common fixes:
# 1. Reinstall dependencies
sudo pip3 install -r /opt/requirements.txt

# 2. Check database
sqlite3 /opt/data/field_trainer.db "PRAGMA integrity_check;"

# 3. Rollback to previous version
sudo git checkout v2025.12.31
sudo systemctl restart field-trainer
```

---

## Quick Reference Commands

**Check installed version:**
```bash
cd /opt && git describe --tags
```

**List all releases:**
```bash
git ls-remote --tags https://github.com/darrenmsmith/field-trainer-releases.git | grep -oP 'refs/tags/v\K[0-9.]+' | sort -V
```

**Update to latest:**
```bash
sudo systemctl stop field-trainer
cd /opt
git fetch --tags
LATEST=$(git ls-remote --tags origin | grep -oP 'refs/tags/v\K[0-9.]+' | sort -V | tail -1)
sudo git checkout v$LATEST
sudo pip3 install -r requirements.txt
sudo systemctl start field-trainer
```

**Rollback to specific version:**
```bash
sudo systemctl stop field-trainer
cd /opt
sudo git checkout v2025.12.31
sudo systemctl start field-trainer
```

**Backup database:**
```bash
sudo cp /opt/data/field_trainer.db ~/field_trainer_backup_$(date +%Y%m%d_%H%M%S).db
```

---

## Summary

✅ **Phase 7 defaults to latest stable release** (v2025.12.31)
✅ **Easy to switch versions** using `git checkout`
✅ **Simple rollback** if problems occur
✅ **Date-based versioning** makes versions clear
✅ **Always backup database** before changing versions

**For most users:** Just press Enter during Phase 7 to get the latest stable release!

**For developers:** Choose option 2 for `main` branch

**For specific versions:** Choose option 3 and enter the version tag
