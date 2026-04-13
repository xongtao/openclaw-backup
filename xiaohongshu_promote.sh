#!/bin/bash
# 小红书租房推广脚本（修复版：根据搜索关键词动态选择房子）
# 每2小时执行一次

LOG_FILE="/root/.openclaw/workspace/xiaohongshu_promote.log"
SKILL_DIR="/root/.openclaw/workspace/skills/xiaohongshu-skill"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] 开始执行推广任务" >> $LOG_FILE

# 南昌房子信息（更新）
NANCHANG_HOUSE="南昌青山湖大道地铁站附近有房子出租（电梯房，南北通透，两室一厅，有主卧和次卧，有停车位）"

# 上海房子信息
SHANGHAI_HOUSE="上海华师大金沙江路附近有房子出租（2室1厅1厨1卫，步梯2楼朝南，1450元/月，近环球港）"

# 评论模板（随机选择）
COMMENTS=(
    "同学你好！看到你在找室友，{HOUSE}。如果你或者朋友有租房需求可以私聊我～"
    "你好！看到你在找房子，{HOUSE}。如果你或者朋友有租房需求可以联系我～"
    "同学！看到你在找合租室友，{HOUSE}。如果你或者朋友有租房需求可以聊聊～"
)

# 搜索关键词配置（格式：关键词|城市）
SEARCH_CONFIG=(
    "南昌求租|南昌"
    "南昌找室友|南昌"
    "南昌顺外站找室友|南昌"
    "上海普陀合租|上海"
    "上海合租|上海"
    "上海找室友|上海"
)

# 已评论过的帖子ID（避免重复）
COMMENTED_FILE="/root/.openclaw/workspace/commented_ids.txt"
mkdir -p $(dirname $COMMENTED_FILE)
touch $COMMENTED_FILE

# 函数：检查是否已评论
is_commented() {
    local id=$1
    grep -q "^$id$" $COMMENTED_FILE
}

# 函数：标记已评论
mark_commented() {
    local id=$1
    echo $id >> $COMMENTED_FILE
}

# 函数：随机选择评论模板
get_random_comment() {
    local size=${#COMMENTS[@]}
    local index=$((RANDOM % size))
    echo "${COMMENTS[$index]}"
}

# 函数：根据关键词选择房子信息
get_house_info() {
    local keyword=$1
    local city=""

    # 遍历配置找到对应城市
    for config in "${SEARCH_CONFIG[@]}"; do
        local config_keyword=$(echo "$config" | cut -d'|' -f1)
        local config_city=$(echo "$config" | cut -d'|' -f2)

        if [[ "$keyword" == *"$config_keyword"* ]]; then
            city="$config_city"
            break
        fi
    done

    # 根据城市返回房子信息
    if [ "$city" == "南昌" ]; then
        echo "$NANCHANG_HOUSE"
    elif [ "$city" == "上海" ]; then
        echo "$SHANGHAI_HOUSE"
    else
        # 默认返回南昌（因为主要推广南昌）
        echo "$NANCHANG_HOUSE"
    fi
}

# 遍历搜索配置
for config in "${SEARCH_CONFIG[@]}"; do
    keyword=$(echo "$config" | cut -d'|' -f1)
    city=$(echo "$config" | cut -d'|' -f2)

    echo "[$DATE] 搜索关键词: $keyword (城市: $city)" >> $LOG_FILE

    # 搜索（3天内，最新，限制10条）
    result=$(cd $SKILL_DIR && python3 -m scripts search "$keyword" --sort-by=最新 --publish-time=三天内 --limit=10 2>&1)

    # 提取帖子ID和xsec_token
    ids=$(echo "$result" | grep -o '"id": "[^"]*"' | sed 's/"id": "\([^"]*\)"/\1/')
    tokens=$(echo "$result" | grep -o '"xsec_token": "[^"]*"' | sed 's/"xsec_token": "\([^"]*\)"/\1/')

    # 转换为数组
    id_array=($ids)
    token_array=($tokens)

    # 获取对应城市的房子信息
    house_info=$(get_house_info "$keyword")
    echo "[$DATE] 使用房子信息: $house_info" >> $LOG_FILE

    # 遍历结果
    for i in "${!id_array[@]}"; do
        id=${id_array[$i]}
        token=${token_array[$i]}

        if [ -z "$id" ] || [ -z "$token" ]; then
            continue
        fi

        # 检查是否已评论
        if is_commented "$id"; then
            echo "[$DATE] 帖子 $id 已评论过，跳过" >> $LOG_FILE
            continue
        fi

        # 获取评论模板并替换房子信息
        comment_template=$(get_random_comment)
        comment=$(echo "$comment_template" | sed "s/{HOUSE}/$house_info/g")

        # 发送评论
        echo "[$DATE] 评论帖子 $id: $comment" >> $LOG_FILE

        comment_result=$(cd $SKILL_DIR && python3 -m scripts comment "$id" "$token" --content "$comment" 2>&1)

        # 检查结果
        if echo "$comment_result" | grep -q '"status": "success"'; then
            echo "[$DATE] 评论成功: $id" >> $LOG_FILE
            mark_commented "$id"
        else
            echo "[$DATE] 评论失败: $id" >> $LOG_FILE
            echo "[$DATE] 错误详情: $comment_result" >> $LOG_FILE
        fi

        # 随机延迟，避免被限流
        sleep $((RANDOM % 10 + 5))
    done
done

echo "[$DATE] 任务完成" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
