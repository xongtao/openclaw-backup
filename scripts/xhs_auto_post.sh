#!/bin/bash
# 小红书自动发房脚本 - 每30分钟发一篇

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

cd /root/.openclaw/workspace

# 读取已发记录
POSTED_FILE="/tmp/xhs_posted_list.txt"
touch $POSTED_FILE

# 5条内容的标题前缀
titles=(
    "南昌租房🚇地铁口0距离！下楼就是2号线顺外站"
    "南昌全女生合租👭133平大空间，安全感满满！"
    "南昌租房🛁主卧带独卫！地铁口电梯房"
    "南昌租房☀️阳光房带阳台！地铁口超舒服"
    "南昌房东直租📦无中介费！2号线地铁口随时入住"
)

# 5条内容的正文文件
contents=(
    "/tmp/xhs_content_1.txt"
    "/tmp/xhs_content_2.txt"
    "/tmp/xhs_content_3.txt"
    "/tmp/xhs_content_4.txt"
    "/tmp/xhs_content_5.txt"
)

# 5张封面图
covers=(
    "/tmp/rent_1.png"
    "/tmp/rent_2.png"
    "/tmp/rent_3.png"
    "/tmp/rent_4.png"
    "/tmp/rent_5.png"
)

# 皮皮虾心情标识（随机选）
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

# 随机选标识
sign_idx=$((RANDOM % ${#signs[@]}))
sign="${signs[$sign_idx]}"

# 读取正文并替换标识，转义JSON特殊字符
content_file="${contents[$next_idx]}"
content=$(cat "$content_file" | sed "s/---来自大哥的皮皮虾agent的助手自动生成/$sign/g" | tr '\n' ' ' | sed 's/"/\\"/g')

title="${titles[$next_idx]}"
title_escaped=$(echo "$title" | sed 's/"/\\"/g')
cover="${covers[$next_idx]}"

# 记录日志
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 准备发送第 $((next_idx+1)) 篇: $title" >> /var/log/xhs_auto_post.log
echo "使用标识: $sign" >> /var/log/xhs_auto_post.log

# 发送到小红书
MCP_URL="http://localhost:18060/mcp"

# 初始化并获取 Session ID
SESSION_ID=$(curl -s -D /tmp/xhs_headers -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"openclaw","version":"1.0"}},"id":1}' > /dev/null && grep -i 'Mcp-Session-Id' /tmp/xhs_headers | tr -d '\r' | awk '{print $2}')

curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

# 构建JSON payload
json_payload="{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"publish_content\",\"arguments\":{\"title\":\"$title_escaped\",\"content\":\"$content\",\"images\":[\"$cover\"]}},\"id\":2}"

# 发布图文
result=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d "$json_payload")

# 检查结果
if echo "$result" | grep -q '"error":null' || echo "$result" | grep -q '"result"'; then
    echo "$next_idx" >> $POSTED_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 发送成功: $title" >> /var/log/xhs_auto_post.log
    echo "✅ 第 $((next_idx+1))/5 篇发送成功！"
    echo "🦐 下次标识可能变成: ${signs[$((RANDOM % ${#signs[@]}))]}"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 发送失败: $result" >> /var/log/xhs_auto_post.log
    echo "❌ 发送失败"
    echo "错误: $result"
fi
