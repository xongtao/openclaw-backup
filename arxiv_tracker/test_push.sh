#!/bin/bash
# 测试脚本 - 放宽条件推送

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

cd /root/.openclaw/workspace/arxiv_tracker

export TENCENT_API_KEY="sk-sp-0lJWHVwLo9CUsIiGi6a6XlTYSOSOUZ8u6TuccAbA5Vd5BfDi"
export TENCENT_BASE_URL="https://api.lkeap.cloud.tencent.com/coding/v3"
export TENCENT_MODEL="kimi-k2.5"

echo "🧪 测试模式运行中..."

# 创建临时测试脚本
cat > /tmp/test_run.py << 'EOF'
import sys
sys.path.insert(0, '/root/.openclaw/workspace/arxiv_tracker')
from arxiv_tracker import ArxivTracker

tracker = ArxivTracker()
# 测试模式：放宽条件
result = tracker.run(target_count=3, test_mode=True)
print(result)
EOF

OUTPUT=$(/usr/bin/python3 /tmp/test_run.py 2>&1)

# 记录日志
echo "$OUTPUT" >> /var/log/arxiv_tracker.log
echo "--- TEST $(date) ---" >> /var/log/arxiv_tracker.log

# 推送
if echo "$OUTPUT" | grep -q "【1】"; then
    echo "📤 推送到企业微信..."
    
    # 发送标题
    TITLE="📚 蛋白质设计论文推荐 (测试模式)"
    /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "🦐 $TITLE" 2>&1 | tee -a /var/log/arxiv_tracker.log
    
    # 发送每篇论文
    echo "$OUTPUT" | awk '/^【[0-9]+】/{if(p)print p; p=$0; next} /^📚|^🦐|^=|^$/{next} {p=p"\n"$0} END{print p}' | \
    while IFS= read -r paper; do
        if [ -n "$paper" ]; then
            /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "$paper" 2>&1 | tee -a /var/log/arxiv_tracker.log
            sleep 0.5
        fi
    done
    
    echo "✅ 推送完成"
fi

rm -f /tmp/test_run.py
