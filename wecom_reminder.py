#!/usr/bin/env python3
"""
企业微信定时提醒脚本
10点前每15分钟提醒一次
"""

import time
import subprocess
import os
from datetime import datetime, timedelta

# 配置
END_HOUR = 10  # 结束时间 10:00
INTERVAL_MINUTES = 15
MESSAGE = "🚨 抢腾讯云 coding plan！快去：https://cloud.tencent.com/act/pro/codingplan?fromSource=gwzcw.1293314.1293314.1293314&cps_key=e884107f613647a5847b532bf0354c40"

LOG_FILE = "/root/.openclaw/workspace/wecom_reminder.log"
OPENCLAW_PATH = "/root/.local/share/pnpm/openclaw"
NODE_PATH = "/root/.nvm/versions/node/v22.22.0/bin/node"

def log(message):
    """记录日志"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def send_message():
    """通过 OpenClaw 发送消息"""
    try:
        env = os.environ.copy()
        env['PATH'] = f"{NODE_PATH.rsplit('/', 1)[0]}:{env.get('PATH', '')}"
        env['NODE_PATH'] = "/root/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.2_@napi-rs+canvas@0.1.95_@types+express@5.0.6_hono@4.12.5_node-llama-cpp@3.16.2/node_modules/openclaw/node_modules:/root/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.2_@napi-rs+canvas@0.1.95_@types+express@5.0.6_hono@4.12.5_node-llama-cpp@3.16.2/node_modules:/root/.local/share/pnpm/global/5/.pnpm/node_modules"

        result = subprocess.run(
            ['bash', OPENCLAW_PATH, 'message', 'send', '--channel', 'wecom', '--target', 'XiongTao', '--message', MESSAGE],
            capture_output=True,
            text=True,
            timeout=30,
            env=env
        )

        log(f"发送结果: {result.stdout}")
        if result.stderr:
            log(f"错误输出: {result.stderr}")

        return result.returncode == 0
    except Exception as e:
        log(f"❌ 发送失败: {e}")
        return False

def main():
    log("企业微信定时提醒脚本启动")
    log(f"结束时间: {END_HOUR}:00")
    log(f"提醒间隔: {INTERVAL_MINUTES} 分钟")

    # 计算下一个整点时间（15分钟对齐）
    now = datetime.now()

    # 计算下次提醒时间（对齐到15分钟）
    minute = now.minute
    next_minute = ((minute // INTERVAL_MINUTES) + 1) * INTERVAL_MINUTES

    if next_minute >= 60:
        next_reminder = now.replace(hour=now.hour + 1, minute=0, second=0, microsecond=0)
    else:
        next_reminder = now.replace(minute=next_minute, second=0, microsecond=0)

    log(f"下次提醒时间: {next_reminder.strftime('%Y-%m-%d %H:%M')}")

    while True:
        now = datetime.now()

        # 检查是否超过结束时间
        if now.hour >= END_HOUR:
            log(f"已到 {END_HOUR}:00，停止提醒")
            break

        # 检查是否到提醒时间
        if now >= next_reminder:
            log(f"⏰ 发送提醒...")
            success = send_message()
            if success:
                log("✅ 提醒发送成功")
            else:
                log("❌ 提醒发送失败")

            # 计算下次提醒时间
            next_reminder = next_reminder + timedelta(minutes=INTERVAL_MINUTES)
            log(f"下次提醒时间: {next_reminder.strftime('%Y-%m-%d %H:%M')}")

        # 等待 5 秒
        time.sleep(5)

    log("提醒脚本结束")

if __name__ == '__main__':
    main()
