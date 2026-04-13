#!/bin/bash
# 腾讯云 coding plan 抢购提醒脚本
# 2026-03-09 09:00 开始，每隔 25 分钟提醒一次

LOG_FILE="/root/.openclaw/workspace/tencent_reminder.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] 腾讯云 coding plan 提醒脚本启动" >> $LOG_FILE

# 目标日期
TARGET_DATE="2026-03-09"
TARGET_HOUR=9

# 提醒间隔（分钟）
INTERVAL=25

# 最大提醒次数（避免无限提醒）
MAX_REMINDERS=20

# 提醒内容
MESSAGE="🚨 抢腾讯云 coding plan！快去：https://cloud.tencent.com/act/coding"

# 函数：发送企业微信提醒
send_reminder() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 发送提醒: $MESSAGE" >> $LOG_FILE
    
    # 用 OpenClaw message 工具发送（这里用 echo，实际需要调用 message API）
    echo "[$timestamp] $MESSAGE"
}

# 函数：等待到目标时间
wait_until_target() {
    local target_time="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待到 $target_time..." >> $LOG_FILE
    
    while true; do
        local current=$(date '+%Y-%m-%d %H:%M')
        if [[ "$current" >= "$target_time" ]]; then
            break
        fi
        sleep 10
    done
}

# 等待到明天 9:00
wait_until_target "$TARGET_DATE $TARGET_HOUR:00"

# 开始提醒循环
count=0
while [ $count -lt $MAX_REMINDERS ]; do
    send_reminder
    count=$((count + 1))
    
    # 等待 25 分钟
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 $INTERVAL 分钟后下次提醒..." >> $LOG_FILE
    sleep $((INTERVAL * 60))
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 提醒脚本结束" >> $LOG_FILE
