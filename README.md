# Cron-Sync Manager 🚀

A professional, idempotent Bash engine to manage Ubuntu crontabs across multiple projects. Keep your core logic in GitHub and your configurations in your project folders.

## 🛠 Usage

### 1. Create a Configuration (`cron.conf`)
In your project directory, define your jobs in a file named `cron.conf`:

```bash
# Format: "Label|Schedule|Command"
ADD_JOBS=(
    "Database Backup|0 5 * * *|/home/user/scripts/backup.sh"
    "System Monitor|*/15 * * * *|/usr/bin/python3 /home/user/scripts/monitor.py"
)

# Any managed job containing these strings will be removed
REMOVE_JOBS=(
    "old_script.sh"
    "test_task.py"
)
```

### 2. Run Sync
You can run the script locally or stream it directly from your GitHub repository for a zero-install experience.

Local Execution:
```bash
1. Download the script:
curl -o cron-sync.sh https://raw.githubusercontent.com/Shubhamc4/cron-sync-manager/main/cron-sync.sh

2. Make it executable:
chmod +x cron-sync.sh

3. Run with your config:
./cron-sync.sh --dry-run cron.conf
```

Remote Execution:
```bash
curl -s https://raw.githubusercontent.com/Shubhamc4/cron-sync-manager/main/cron-sync.sh | bash -s -- --dry-run cron.conf
```

## ⚡ Quick Start Template
Run this in your terminal to generate a fresh configuration file instantly:

```bash
cat <<EOF > cron.conf
ADD_JOBS=(
    "App Heartbeat|*/5 * * * *|/usr/bin/curl -s http://localhost/api/heartbeat"
)

REMOVE_JOBS=(
    "obsolete_task.sh"
)
EOF
```

## 📊 Status Indicators
- ✓ : Job is already present and correct.
- + : Job will be added to crontab.
- ✕ : Job will be removed from crontab.

## 🚪 Exit Codes
- 0: No changes needed.
- 10: Crontab successfully updated.
- 11: Changes detected during dry-run.
