#!/bin/bash
# 小红书自动评论回复脚本 - 快速版
# 功能：监控帖子评论 → 自动回复新评论

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"
MCP_URL="http://localhost:18060/mcp"

# 超时控制
export CURL_TIMEOUT=30

# 记录文件
REPLIED_FILE="/tmp/xhs_replied_comments.txt"
touch $REPLIED_FILE

# 回复模板
replies=(
    "私聊我了，详情私信聊～"
    "私我，发你详细介绍"
    "私聊哈，这里说不太方便"
    "私信我了，详细跟你说"
    "私聊我，一起交流技术"
)

# 皮皮虾标识
signs=(
    "🦐 皮皮虾自动回复"
    "---皮皮虾助手---"
    "🦐 来自皮皮虾"
)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始检查评论..."

# 初始化 MCP
SESSION_ID=$(curl -s -D /tmp/h -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"openclaw","version":"1.0"}},"id":1}' > /dev/null && grep -i 'Mcp-Session-Id' /tmp/h 2>/dev/null | awk '{print $2}' | tr -d '\r')

curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

# 1. 获取用户的帖子列表
echo "📱 获取帖子列表..."
feeds_result=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_feeds","arguments":{}},"id":2}')

# 解析帖子列表
echo "$feeds_result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    feeds = json.loads(data['result']['content'][0]['text']).get('feeds', [])
    for feed in feeds[:5]:  # 只检查最近5个帖子
        if feed.get('modelType') == 'note':
            fid = feed.get('id', '')
            xsec = feed.get('xsecToken', '')
            title = feed.get('noteCard', {}).get('displayTitle', '无标题')[:30]
            print(f'{fid}|{xsec}|{title}')
except:
    pass
" > /tmp/my_feeds.txt

# 2. 检查每个帖子的评论
reply_count=0
while IFS='|' read -r feed_id xsec_token title; do
    [ -z "$feed_id" ] && continue
    
    echo ""
    echo "🔍 检查帖子: $title"
    
    # 获取帖子详情（包含评论）
    detail_result=$(curl -s -X POST "$MCP_URL" \
      -H "Content-Type: application/json" \
      -H "Mcp-Session-Id: $SESSION_ID" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"get_feed_detail\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\"}},\"id\":3}")
    
    # 解析评论
    echo "$detail_result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = json.loads(data['result']['content'][0]['text'])
    comments = content.get('comments', [])
    for c in comments[:3]:  # 只检查前3条评论
        cid = c.get('commentId', '')
        text = c.get('content', '')[:50]
        user = c.get('nickname', '用户')
        print(f'{cid}|{user}|{text}')
except:
    pass
" > /tmp/comments.txt
    
    # 3. 对未回复的评论进行回复
    while IFS='|' read -r comment_id user_nickname comment_text; do
        [ -z "$comment_id" ] && continue
        
        # 检查是否已回复
        if grep -q "^${feed_id}:${comment_id}$" $REPLIED_FILE; then
            continue
        fi
        
        # 只回复包含特定关键词的评论
        if echo "$comment_text" | grep -qE "私|价格|多少钱|怎么联系|还有吗|想要|怎么租|还有房"; then
            echo "  💬 回复 $user_nickname: $comment_text"
            
            # 随机选择回复
            reply="${replies[$((RANDOM % ${#replies[@]}))]}\n\n${signs[$((RANDOM % ${#signs[@]}))]}"
            reply_escaped=$(echo "$reply" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")')
            
            # 发送回复
            reply_result=$(curl -s -X POST "$MCP_URL" \
              -H "Content-Type: application/json" \
              -H "Mcp-Session-Id: $SESSION_ID" \
              -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"reply_comment_in_feed\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\",\"content\":$reply_escaped}},\"id\":4}")
            
            if echo "$reply_result" | grep -q '"result"'; then
                echo "${feed_id}:${comment_id}" >> $REPLIED_FILE
                reply_count=$((reply_count+1))
                echo "  ✅ 回复成功"
                
                # 企业微信通知
                /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "💬 小红书自动回复\n\n帖子: $title\n用户: $user_nickname\n评论: $comment_text\n\n✅ 已自动回复" 2>/dev/null
            else
                echo "  ❌ 回复失败"
            fi
            
            sleep 5  # 避免频率过高
        fi
    done < /tmp/comments.txt
    
done < /tmp/my_feeds.txt

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 完成，回复了 $reply_count 条评论"
