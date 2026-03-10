#!/bin/bash
# 小红书自动评论回复脚本 - 精简版

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"
MCP_URL="http://localhost:18060/mcp"

REPLIED_FILE="/tmp/xhs_replied_comments.txt"
touch $REPLIED_FILE

echo "[$(date '+%H:%M:%S')] 检查评论..."

# 初始化
SESSION_ID=$(curl -s -m 10 -D /tmp/h -X POST "$MCP_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"x","version":"1"}},"id":1}' > /dev/null && grep -i 'Mcp-Session-Id' /tmp/h 2>/dev/null | awk '{print $2}' | tr -d '\r')

[ -z "$SESSION_ID" ] && { echo "初始化失败"; exit 1; }

curl -s -m 5 -X POST "$MCP_URL" -H "Content-Type: application/json" -H "Mcp-Session-Id: $SESSION_ID" -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

# 只检查最新1个帖子
echo "获取帖子..."
feeds_result=$(curl -s -m 15 -X POST "$MCP_URL" -H "Content-Type: application/json" -H "Mcp-Session-Id: $SESSION_ID" -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_feeds","arguments":{}},"id":2}')

# 解析第一个帖子
feed_info=$(echo "$feeds_result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    feeds = json.loads(data['result']['content'][0]['text']).get('feeds', [])
    for feed in feeds[:1]:
        if feed.get('modelType') == 'note':
            print(f\"{feed.get('id')}|{feed.get('xsecToken')}|{feed.get('noteCard', {}).get('displayTitle', '')[:20]}\")
except: pass
")

[ -z "$feed_info" ] && { echo "没有帖子"; exit 0; }

IFS='|' read -r feed_id xsec_token title <<< "$feed_info"
echo "帖子: $title"

# 获取评论
echo "获取评论..."
detail=$(curl -s -m 20 -X POST "$MCP_URL" -H "Content-Type: application/json" -H "Mcp-Session-Id: $SESSION_ID" -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"get_feed_detail\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\"}},\"id\":3}")

# 检查最新评论
comment=$(echo "$detail" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = json.loads(data['result']['content'][0]['text'])
    comments = content.get('comments', [])
    if comments:
        c = comments[0]
        print(f\"{c.get('commentId')}|{c.get('nickname')}|{c.get('content', '')[:30]}\")
except: pass
")

[ -z "$comment" ] && { echo "没有评论"; exit 0; }

IFS='|' read -r cid user text <<< "$comment"
echo "最新评论: $user - $text"

# 检查是否已回复
if grep -q "^${feed_id}:${cid}$" $REPLIED_FILE 2>/dev/null; then
    echo "已回复过"
    exit 0
fi

# 判断是否回复
if echo "$text" | grep -qE "私|价格|多少钱|联系|还有|想要|租|房|怎么"; then
    echo "准备回复..."
    
    reply="私聊我了，详情私信聊～\n\n🦐 皮皮虾自动回复"
    reply_escaped=$(echo "$reply" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")')
    
    result=$(curl -s -m 30 -X POST "$MCP_URL" -H "Content-Type: application/json" -H "Mcp-Session-Id: $SESSION_ID" -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"reply_comment_in_feed\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\",\"content\":$reply_escaped}},\"id\":4}")
    
    if echo "$result" | grep -q '"result"'; then
        echo "${feed_id}:${cid}" >> $REPLIED_FILE
        echo "✅ 回复成功"
        /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "💬 自动回复：$user - $text" 2>/dev/null
    else
        echo "❌ 失败"
    fi
else
    echo "无需回复"
fi

echo "[$(date '+%H:%M:%S')] 完成"
