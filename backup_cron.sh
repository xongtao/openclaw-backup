#!/bin/bash
# OpenClaw config auto-backup script

cd /home/ubuntu/.openclaw/workspace

# Add and commit all changes
git add -A
git commit -m "Auto backup $(date '+%Y-%m-%d %H:%M')" 2>/dev/null

# Push to GitHub
git push origin master 2>/dev/null
