#!/bin/bash
# arXiv 论文追踪器 - 定时任务脚本
# 每天早上 8:00 运行

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

cd /root/.openclaw/workspace/arxiv_tracker

# 加载环境变量
export TENCENT_API_KEY="sk-sp-0lJWHVwLo9CUsIiGi6a6XlTYSOSOUZ8u6TuccAbA5Vd5BfDi"
export TENCENT_BASE_URL="https://api.lkeap.cloud.tencent.com/coding/v3"
export TENCENT_MODEL="kimi-k2.5"

# 运行追踪器（自动推送）
/usr/bin/python3 arxiv_tracker.py 2>&1 | tee -a /var/log/arxiv_tracker.log

echo "--- $(date) ---" >> /var/log/arxiv_tracker.log
