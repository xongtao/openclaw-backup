#!/bin/bash
# 租房发帖定时 - 使用 flock 确保单实例执行
# 用法: flock -n /tmp/rent_post.lock -c '/bin/bash /root/.openclaw/workspace/arxiv_tracker/rent_post_timer.sh'

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

cd /root/.openclaw/workspace

# 读取已发记录
POSTED_FILE="/tmp/rent_posted_list.txt"
touch $POSTED_FILE

# 5条内容的标题前缀
titles=(
    "南昌租房🚇地铁口0距离！下楼就是2号线顺外站"
    "南昌全女生合租👭133平大空间，安全感满满！"
    "南昌租房🛁主卧带独卫！地铁口电梯房"
    "南昌租房☀️阳光房带阳台！地铁口超舒服"
    "南昌房东直租📦无中介费！2号线地铁口随时入住"
)

contents=(
    "/tmp/xhs_content_1.txt"
    "/tmp/xhs_content_2.txt"
    "/tmp/xhs_content_3.txt"
    "/tmp/xhs_content_4.txt"
    "/tmp/xhs_content_5.txt"
)

covers=(
    "/tmp/rent_1.png"
    "/tmp/rent_2.png"
    "/tmp/rent_3.png"
    "/tmp/rent_4.png"
    "/tmp/rent_5.png"
)

signs=(
    "---来自大哥的皮皮虾agent的助手自动生成"
    "---🦐皮皮虾为你服务"
    "---深海特工007号已投递"
    "---来自海底两万里的租房小助手"
    "---皮皮虾的租房情报站"
    "---🌊浪里个浪，租房找我"
    "---虾兵蟹将租房团出品"
    "---🦐皮皮虾 says: 租房不踩坑！"
    "---来自赣江边的小虾米"
    "---南昌租房界的皮皮虾"
)

# 找到下一条要发的
next_idx=0
for i in 0 1 2 3 4; do
    if ! grep -q "^$i$" $POSTED_FILE; then
        next_idx=$i
        break
    fi
done

# 如果5条都发过了，重置
if [ $(wc -l < $POSTED_FILE) -ge 5 ]; then
    > $POSTED_FILE
    next_idx=0
fi

sign_idx=$((RANDOM % ${#signs[@]}))
sign="${signs[$sign_idx]}"

content_file="${contents[$next_idx]}"
content=$(cat "$content_file" | sed "s/---来自大哥的皮皮虾agent的助手自动生成/$sign/g" | tr '\n' ' ' | sed 's/"/\\"/g')

title="${titles[$next_idx]}"
title_escaped=$(echo "$title" | sed 's/"/\\"/g')
cover="${covers[$next_idx]}"

current_time=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$current_time] 租房发帖定时启动 - 第 $((next_idx+1))/5 篇"

# 1. 发送前通知
/root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "🦐 租房发帖定时启动\n\n📱 第 $((next_idx+1))/5 篇\n📌 $title\n🕐 $current_time\n\n发送中..." 2>/dev/null

# 2. 执行发送
MCP_URL="http://localhost:18060/mcp"

SESSION_ID=$(curl -s -D /tmp/xhs_headers -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"openclaw","version":"1.0"}},"id":1}' > /dev/null && grep -i 'Mcp-Session-Id' /tmp/xhs_headers | tr -d '\r' | awk '{print $2}')

curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

json_payload="{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"publish_content\",\"arguments\":{\"title\":\"$title_escaped\",\"content\":\"$content\",\"images\":[\"$cover\"]}},\"id\":2}"

result=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d "$json_payload")

# 3. 发送后汇报
if echo "$result" | grep -q '"error":null' || echo "$result" | grep -q '"result"'; then
    echo "$next_idx" >> $POSTED_FILE
    posted_count=$(wc -l < $POSTED_FILE)
    remaining=$((5 - posted_count))
    
    /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "✅ 租房发帖定时完成\n\n📱 第 $((next_idx+1))/5 篇已发布\n📌 $title\n\n📊 进度：$posted_count/5\n🔄 剩余：$remaining\n\n$sign" 2>/dev/null
    
    echo "[$current_time] ✅ 成功: $title" >> /var/log/rent_post.log
    echo "✅ 第 $((next_idx+1))/5 篇发送成功"
else
    error_msg=$(echo "$result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
    [ -z "$error_msg" ] && error_msg="未知错误"
    
    /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "❌ 租房发帖定时失败\n\n📱 第 $((next_idx+1))/5 篇\n💥 $error_msg" 2>/dev/null
    
    echo "[$current_time] ❌ 失败: $error_msg" >> /var/log/rent_post.log
    echo "❌ 失败: $error_msg"
fi
