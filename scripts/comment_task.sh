#!/bin/bash
# 南昌租房留言任务 - 持续执行
# 功能：搜索南昌租房/合租帖子 → 留言介绍房子 → 引导查看主页

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

# 注意：锁由crontab的flock管理，脚本内不再加锁

# 皮皮虾专属标记（随机选）
signs=(
    "🦐 来自顺外站地铁口租房小助手"
    "🌊 皮皮虾跑腿 | 地铁口0距离"
    "---深海特工007号情报员---"
    "🦐 顺外站房东直租 | 女生合租"
    "---来自赣江边的租房小虾米---"
    "🦐 南昌租房情报站 | 欢迎私信"
    "---虾兵蟹将租房团---"
    "🌊 2号线顺外站 | 全女生合租"
    "🦐 皮皮虾 says: 租房找我！"
    "---南昌租房界的皮皮虾---"
)
sign_idx=$((RANDOM % ${#signs[@]}))
sign="${signs[$sign_idx]}"

# 搜索关键词（必须带南昌，精确匹配）
keywords=(
    "南昌租房"
    "南昌合租"
    "南昌找室友"
    "南昌女生合租"
    "南昌2号线"
    "南昌火车站"
    "南昌顺外站"
    "南昌地铁口"
    "南昌青山湖"
    "南昌求租"
)
keyword="${keywords[$((RANDOM % ${#keywords[@]}))]}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始搜索: $keyword"

# MCP 配置
MCP_URL="http://localhost:18060/mcp"

# 初始化
SESSION_ID=$(curl -s -D /tmp/xhs_headers -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"openclaw","version":"1.0"}},"id":1}' > /dev/null && grep -i 'Mcp-Session-Id' /tmp/xhs_headers | tr -d '\r' | awk '{print $2}')

curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

# 搜索帖子
search_result=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"search_feeds\",\"arguments\":{\"keyword\":\"$keyword\"}},\"id\":2}")

# 解析搜索结果（取前3个未留言的帖子）
echo "$search_result" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    # 直接从JSON解析feeds
    result_text = data['result']['content'][0]['text']
    inner_data = json.loads(result_text)
    feeds = inner_data.get('feeds', [])
    
    # 输出前3个note类型的帖子
    count = 0
    for feed in feeds:
        if count >= 3:
            break
        if feed.get('modelType') == 'note':
            feed_id = feed.get('id', '')
            xsec = feed.get('xsecToken', '')
            title = feed.get('noteCard', {}).get('displayTitle', '无标题')[:50]
            if feed_id and xsec:
                print(f'{feed_id}|{xsec}|{title}')
                count += 1
except Exception as e:
    print(f'解析错误: {e}', file=sys.stderr)
" > /tmp/target_posts.txt

echo "  找到目标帖子:"
cat /tmp/target_posts.txt | while read line; do
    echo "    - $line"
done

# 已留言记录
COMMENTED_FILE="/tmp/xhs_commented.txt"
touch $COMMENTED_FILE

# 留言内容模板
comments=(
    "姐妹！我也在找合租室友～ 2号线顺外站地铁口，电梯房全女生合租，主卧带独卫8张，阳台房7张出头，押一付一。有兴趣可以看我主页置顶！"
    "宝子看这里！顺外站地铁口0距离，133平全女生合租，电梯房主卧独卫，性价比超高～ 详情看我主页呀！"
    "姐妹！顺外站这边有房子～ 地铁口超近，全女生合租，环境好空间大，价格美丽。可以看我主页了解！"
    "看我主页！顺外站地铁口有房招室友，全女生、电梯房、押一付一，主卧独卫和阳台房都有空～"
    "南昌合租看过来！2号线顺外站，全女生合租，地铁口0距离，价格美丽欢迎看房。详情主页！"
)

# 对每个目标帖子留言
while IFS='|' read -r feed_id xsec_token title; do
    [ -z "$feed_id" ] && continue
    
    # 检查是否已经留言过
    if grep -q "^$feed_id$" $COMMENTED_FILE; then
        echo "  ⏭️ 已留言过: $feed_id"
        continue
    fi
    
    # 随机选择留言内容
    comment_idx=$((RANDOM % ${#comments[@]}))
    comment_text="${comments[$comment_idx]}\n\n$sign"
    
    echo "  💬 准备留言: $title"
    
    # JSON转义留言内容
    comment_escaped=$(echo "$comment_text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")')
    
    # 发送留言
    json_payload="{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"post_comment_to_feed\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\",\"content\":$comment_escaped}},\"id\":3}"
    
    comment_result=$(curl -s -X POST "$MCP_URL" \
      -H "Content-Type: application/json" \
      -H "Mcp-Session-Id: $SESSION_ID" \
      -d "$json_payload")
    
    if echo "$comment_result" | grep -q '"error":null' || echo "$comment_result" | grep -q '"result"'; then
        echo "$feed_id" >> $COMMENTED_FILE
        echo "  ✅ 留言成功: $feed_id"
        
        # 企业微信通知
        /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "💬 南昌租房留言任务\n\n✅ 成功留言\n🔍 关键词: $keyword\n📝 帖子: ${title:0:20}...\n\n$sign" 2>/dev/null
        
        # 每个任务只留言1条，避免频繁
        break
    else
        error_msg=$(echo "$comment_result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "  ❌ 留言失败: $error_msg"
    fi
done < /tmp/target_posts.txt

count=$(wc -l < $COMMENTED_FILE)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务完成，已留言 $count 个帖子"
