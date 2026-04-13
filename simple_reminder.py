#!/usr/bin/env python3
"""
简单提醒脚本 - 10点前每15分钟提醒一次
通过 OpenClaw 的 internal API 发送消息
"""

import time
import subprocess
from datetime import datetime, timedelta

# 配置
END_HOUR = 10
INTERVAL_MINUTES = 15
MESSAGE = "🚨 抢腾讯云 coding plan！快去：https://cloud.tencent.com/act/pro/codingplan?fromSource=gwzcw.1293314.1293314.1293314&cps_key=e884107f613647a5847b532bf0354c40"

LOG_FILE = "/root/.openclaw/workspace/simple_reminder.log"

def log(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def send_message():
    """通过 OpenClaw gateway API 发送消息"""
    try:
        # 尝试调用 OpenClaw 的内部 API
        # 使用 node 直接调用 OpenClaw 的 message 模块
        cmd = f"""
        const {{ message }} = require('/root/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.2_@napi-rs+canvas@0.1.95_@types+express@5.0.6_hono@4.12.5_node-llama-cpp@3.16.2/node_modules/openclaw/dist/index.js');
        message({{
          action: 'send',
          channel: 'wecom',
          to: 'XiongTao',
          message: '{MESSAGE}'
        }}).then(console.log).catch(console.error);
        """
        result = subprocess.run(
            ['/root/.nvm/versions/node/v22.22.0/bin/node', '-e', cmd],
            capture_output=True,
            text=True,
            timeout=30
        )
        log(f"发送结果: {result.stdout}")
        if result.stderr:
            log(f"错误: {result.stderr}")
        return result.returncode == 0
    except Exception as e:
        log(f"❌ 发送失败: {e}")
        return False

def main():
    log("简单提醒脚本启动")
    log(f"结束时间: {END_HOUR}:00，间隔: {INTERVAL_MINUTES} 分钟")

    # 立即发送一次
    log("立即发送提醒...")
    send_message()

    # 计算下次提醒时间
    now = datetime.now()
    next_reminder = now.replace(minute=30, second=0, microsecond=0)  # 9:30
    if now.minute >= 30:
        next_reminder = now.replace(hour=now.hour + 1, minute=0, second=0, microsecond=0)  # 10:00

    log(f"下次提醒: {next_reminder.strftime('%H:%M')}")

    while True:
        now = datetime.now()

        if now.hour >= END_HOUR:
            log(f"已到 {END_HOUR}:00，停止")
            break

        if now >= next_reminder:
            log("发送提醒...")
            send_message()
            next_reminder = next_reminder + timedelta(minutes=INTERVAL_MINUTES)
            log(f"下次提醒: {next_reminder.strftime('%H:%M')}")

        time.sleep(1)

    log("脚本结束")

if __name__ == '__main__':
    main()
