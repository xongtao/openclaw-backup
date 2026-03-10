#!/bin/bash
# 南昌租房批量留言任务 - 留言50条
# 功能：搜索南昌租房帖子 → 批量留言 → 引导查看主页

export PATH="/root/.nvm/versions/node/v22.22.0/bin:$PATH"

# 皮皮虾专属标记（随机选）
signs=(
    "🦐 来自顺外站地铁口租房小助手"
    "---深海特工007号情报员---"
    "🦐 顺外站房东直租 | 女生合租"
    "---来自赣江边的小虾米---"
    "🦐 南昌租房情报站 | 欢迎私信"
    "---虾兵蟹将租房团---"
    "🌊 2号线顺外站 | 全女生合租"
    "🦐 皮皮虾 says: 租房找我！"
)

# 搜索关键词列表
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

# 留言内容模板
comments=(
    "姐妹！我也在找合租室友～ 2号线顺外站地铁口，电梯房全女生合租，主卧带独卫8张，阳台房7张出头，押一付一。有兴趣可以看我主页！"
    "宝子看这里！顺外站地铁口0距离，133平全女生合租，电梯房主卧独卫，性价比超高～ 详情看我主页呀！"
    "姐妹！顺外站这边有房子～ 地铁口超近，全女生合租，环境好空间大，价格美丽。可以看我主页了解！"
    "看我主页！顺外站地铁口有房招室友，全女生、电梯房、押一付一，主卧独卫和阳台房都有空～"
    "南昌合租看过来！2号线顺外站，全女生合租，地铁口0距离，价格美丽欢迎看房。详情主页！"
)

# MCP 配置
MCP_URL="http://localhost:18060/mcp"

# 已留言记录
COMMENTED_FILE="/tmp/xhs_commented.txt"
touch $COMMENTED_FILE

# 计数器
success_count=0
target_count=50

# 循环直到留言50条
while [ $success_count -lt $target_count ]; do
    echo ""
    echo "=========================================="
    echo "[$(date '+%H:%M:%S')] 当前进度: $success_count/$target_count"
    echo "=========================================="
    
    # 随机选择关键词
    keyword="${keywords[$((RANDOM % ${#keywords[@]}))]}"
    echo "🔍 搜索关键词: $keyword"
    
    # 初始化 MCP
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
    
    # 解析搜索结果
    echo "$search_result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    result_text = data['result']['content'][0]['text']
    inner_data = json.loads(result_text)
    feeds = inner_data.get('feeds', [])
    
    count = 0
    for feed in feeds:
        if count >= 5:  # 每次搜索处理5个
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
    
    echo "  找到 $(wc -l < /tmp/target_posts.txt) 个目标帖子"
    
    # 对每个目标帖子留言
    while IFS='|' read -r feed_id xsec_token title; do
        [ -z "$feed_id" ] && continue
        
        # 检查是否已经留言过
        if grep -q "^$feed_id$" $COMMENTED_FILE; then
            echo "  ⏭️ 已留言过: $feed_id"
            continue
        fi
        
        # 随机选择留言内容和标识
        comment_idx=$((RANDOM % ${#comments[@]}))
        sign_idx=$((RANDOM % ${#signs[@]}))
        comment_text="${comments[$comment_idx]}\n\n${signs[$sign_idx]}"
        
        echo "  💬 [$((success_count+1))/$target_count] 准备留言: ${title:-无标题}"
        
        # JSON转义
        comment_escaped=$(echo "$comment_text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")')
        
        # 发送留言
        json_payload="{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"post_comment_to_feed\",\"arguments\":{\"feed_id\":\"$feed_id\",\"xsec_token\":\"$xsec_token\",\"content\":$comment_escaped}},\"id\":3}"
        
        comment_result=$(curl -s -X POST "$MCP_URL" \
          -H "Content-Type: application/json" \
          -H "Mcp-Session-Id: $SESSION_ID" \
          -d "$json_payload")
        
        if echo "$comment_result" | grep -q '"result"'; then
            echo "$feed_id" >> $COMMENTED_FILE
            success_count=$((success_count + 1))
            echo "  ✅ 留言成功 ($success_count/$target_count)"
            
            # 企业微信通知（每10条通知一次）
            if [ $((success_count % 10)) -eq 0 ]; then
                /root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "💬 南昌租房批量留言\n\n✅ 已完成: $success_count/$target_count 条\n🔍 关键词: $keyword\n📝 最新: ${title:0:20}..." 2>/dev/null
            fi
            
            # 达到50条就退出
            if [ $success_count -ge $target_count ]; then
                break
            fi
            
            # 休息5秒，避免频率过高
            sleep 5
        else
            error_msg=$(echo "$comment_result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
            echo "  ❌ 留言失败: ${error_msg:-未知错误}"
            # 休息10秒再继续
            sleep 10
        fi
    done < /tmp/target_posts.txt
    
    # 搜索之间休息10秒
    if [ $success_count -lt $target_count ]; then
        echo "  ⏳ 休息10秒后继续搜索..."
        sleep 10
    fi
done

echo ""
echo "=========================================="
echo "🎉 任务完成！共留言 $success_count 条"
echo "=========================================="

# 最终通知
/root/.local/share/pnpm/openclaw message send --channel wecom --target "XiongTao" --message "🎉 批量留言任务完成！\n\n✅ 共留言: $success_count 条\n📊 详见记录: /tmp/xhs_commented.txt" 2>/dev/null
