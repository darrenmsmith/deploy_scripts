# Field Trainer - Restore from USB Backup

**Backup File:** `ft_opt_backup_20260205_112234.tar.gz`  
**Backup Location:** `/mnt/usb/`  
**Created:** February 5, 2026  
**Contents:** Complete /opt directory (excluding .git) — working dev system state

---

## Prerequisites

- USB drive mounted at `/mnt/usb`
- If not mounted:
  ```bash
  sudo mkdir -p /mnt/usb
  sudo mount -t ntfs-3g -o rw,uid=1000,gid=1000 /dev/sda1 /mnt/usb
  ```

---

## Restore Steps

```bash
# 1. Stop the service
sudo systemctl stop field-trainer-server

# 2. Remove current /opt contents (PRESERVES .git history)
cd /opt
sudo find . -maxdepth 1 ! -name '.git' ! -name '.' -exec rm -rf {} +

# 3. Extract the backup
sudo tar xzf /mnt/usb/ft_opt_backup_20260205_112234.tar.gz -C /opt

# 4. Fix ownership
sudo chown -R pi:pi /opt

# 5. Restart the service
sudo systemctl restart field-trainer-server

# 6. Verify service is running
sudo systemctl status field-trainer-server
```

---

## Full Wipe Restore (including git history reset)

Use this ONLY if you want to completely start over, losing all git history:

```bash
# 1. Stop the service
sudo systemctl stop field-trainer-server

# 2. Remove EVERYTHING in /opt
sudo rm -rf /opt/*
sudo rm -rf /opt/.git
sudo rm -rf /opt/.gitignore

# 3. Extract the backup
sudo tar xzf /mnt/usb/ft_opt_backup_20260205_112234.tar.gz -C /opt

# 4. Fix ownership
sudo chown -R pi:pi /opt

# 5. Re-initialize git if needed
cd /opt
git init
git remote add origin git@github.com:darrenmsmith/FT_2025.git

# 6. Restart the service
sudo systemctl restart field-trainer-server
```

---

## Verify After Restore

```bash
# Check service
sudo systemctl status field-trainer-server

# Check web interface
curl -s http://localhost:5001/health | head -5

# Check database exists
ls -lh /opt/data/field_trainer.db

# Check key files
ls -la /opt/coach_interface.py
ls -la /opt/field_trainer_main.py
```

---

**Note:** This backup was taken AFTER pushing Jan_branch and main to GitHub.  
GitHub repo: https://github.com/darrenmsmith/FT_2025.git  
Branches pushed: `main` (38 commits), `Jan_branch`
