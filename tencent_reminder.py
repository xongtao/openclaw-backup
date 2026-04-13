#!/usr/bin/env python3
"""
腾讯云 coding plan 抢购提醒
明天 2026-03-09 09:00 开始，每隔 25 分钟提醒一次
"""

import time
import subprocess
import json
from datetime import datetime, timedelta

# 配置
TARGET_DATE = "2026-03-09"
TARGET_TIME = "09:00"
INTERVAL_MINUTES = 25
MAX_REMINDERS = 20
MESSAGE = "🚨 抢腾讯云 coding plan！快去：https://cloud.tencent.com/act/pro/codingplan?fromSource=gwzcw.1293314.1293314.1293314&cps_key=e884107f613647a5847b532bf0354c40"

LOG_FILE = "/root/.openclaw/workspace/tencent_reminder.log"

def log(message):
    """记录日志"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def send_message(message):
    """发送企业微信消息（通过 OpenClaw CLI）"""
    try:
        # 尝试用 openclaw 命令发送
        result = subprocess.run(
            ['openclaw', 'message', 'send', '--to', 'XiongTao', '--message', message],
            capture_output=True,
            text=True,
            timeout=30
        )
        log(f"消息发送结果: {result.returncode}")
        return result.returncode == 0
    except Exception as e:
        log(f"发送消息失败: {e}")
        return False

def wait_until_target():
    """等待到目标时间"""
    target_str = f"{TARGET_DATE} {TARGET_TIME}"
    target_time = datetime.strptime(target_str, '%Y-%m-%d %H:%M')
    
    log(f"等待到 {target_str}...")
    
    while True:
        now = datetime.now()
        if now >= target_time:
            log(f"到达目标时间！")
            break
        
        # 计算剩余时间
        remaining = (target_time - now).total_seconds()
        if remaining > 0:
            log(f"距离目标时间还有 {int(remaining)} 秒")
            time.sleep(min(60, remaining))  # 每分钟检查一次

def main():
    log("腾讯云 coding plan 提醒脚本启动")
    log(f"目标时间: {TARGET_DATE} {TARGET_TIME}")
    log(f"提醒间隔: {INTERVAL_MINUTES} 分钟")
    log(f"最大提醒次数: {MAX_REMINDERS}")
    
    # 等待到目标时间
    wait_until_target()
    
    # 开始提醒循环
    count = 0
    while count < MAX_REMINDERS:
        count += 1
        log(f"第 {count} 次提醒")
        
        # 发送消息
        success = send_message(MESSAGE)
        if success:
            log("✅ 消息发送成功")
        else:
            log("❌ 消息发送失败")
        
        # 检查是否继续
        if count >= MAX_REMINDERS:
            log(f"已达到最大提醒次数 {MAX_REMINDERS}，停止")
            break
        
        # 等待下次提醒
        log(f"等待 {INTERVAL_MINUTES} 分钟后下次提醒...")
        time.sleep(INTERVAL_MINUTES * 60)
    
    log("提醒脚本结束")

if __name__ == '__main__':
    main()
