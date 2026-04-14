#!/bin/bash
# OpenClaw config auto-backup script

WORKSPACE="/home/ubuntu/.openclaw/workspace"
DATE=$(date '+%Y-%m-%d %H:%M')

cd "$WORKSPACE"

# Add and commit all changes
git add -A
COMMIT_MSG="Auto backup $(date '+%Y-%m-%d %H:%M')"
git commit -m "$COMMIT_MSG" 2>/dev/null

# Check if there were changes to commit
if [ $? -eq 0 ]; then
    # Push to GitHub
    git push origin master 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Send WeChat notification
        /usr/bin/node /home/ubuntu/.openclaw/workspace/scripts/send_backup_notification.js
    fi
fi
