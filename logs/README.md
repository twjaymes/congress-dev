# Congress.dev Logs Directory

This directory contains all application logs for the Congress.dev project.

## Log Files

- **`alembic.log`** - Database migration logs from Alembic
- **`billparser.log`** - Bill parser and importer logs (JSON format)
- **`api.log`** - FastAPI server and uvicorn logs
- **`import_bills.log`** - Bill import process logs
- **`import_sponsors.log`** - Sponsor data import logs
- **`import_actions.log`** - Legislative actions import logs
- **`import_statuses.log`** - Bill status import logs
- **`import_cleanup.log`** - Post-import cleanup logs
- **`import_usc.log`** - US Code import logs
- **`quick_import.log`** - Quick import script logs

## Log Rotation

Log files are appended to and can grow large over time. Consider implementing log rotation:

```bash
# Manual cleanup (keep last 7 days)
find logs/ -name "*.log" -mtime +7 -delete

# Or use logrotate
sudo logrotate /etc/logrotate.conf
```

## Viewing Logs

```bash
# View all logs in real-time
tail -f logs/*.log

# View specific log
tail -f logs/api.log

# Search logs
grep "ERROR" logs/*.log

# View billparser logs (JSON format)
cat logs/billparser.log | jq .
```

## Git Ignore

Log files (`.log`) are ignored by git, but this directory structure is tracked via `.gitkeep`.
