#!/bin/bash
# AlphaXiv Agent 自动化脚本
# 模拟用户在 AlphaXiv 输入研究问题并获取推荐论文

set -e

PROMPT="$1"
if [ -z "$PROMPT" ]; then
    PROMPT="Search for the latest papers on 3D structure modality fusion in protein design. Specifically focus on two technical directions: 1) Discrete tokenization of 3D structures (tokenizer discretization), and 2) Continuous generative methods including Diffusion Models and Flow Matching."
fi

echo "🦐 启动 AlphaXiv Agent 自动化..."
echo "研究问题: ${PROMPT:0:80}..."
echo ""

# 1. 打开 AlphaXiv
agent-browser open "https://www.alphaxiv.org/" 2>/dev/null || {
    echo "❌ 无法打开 AlphaXiv，尝试安装 agent-browser..."
    npm install -g agent-browser 2>/dev/null || {
        echo "❌ agent-browser 安装失败"
        exit 1
    }
    agent-browser open "https://www.alphaxiv.org/"
}

echo "✅ 已打开 AlphaXiv"

# 2. 等待页面加载并获取元素
echo "⏳ 等待页面加载..."
sleep 3

# 获取页面快照
SNAPSHOT=$(agent-browser snapshot -i 2>/dev/null || echo "")

# 3. 查找输入框（通常是 textarea 或 textbox）
echo "🔍 查找输入框..."
INPUT_REF=$(echo "$SNAPSHOT" | grep -iE "(textarea|textbox|search|input)" | grep -iE "(ask|search|query|prompt)" | head -1 | grep -oE '@e[0-9]+' | head -1)

if [ -z "$INPUT_REF" ]; then
    # 尝试找第一个 textarea
    INPUT_REF=$(echo "$SNAPSHOT" | grep -i "textarea" | head -1 | grep -oE '@e[0-9]+' | head -1)
fi

if [ -z "$INPUT_REF" ]; then
    echo "❌ 无法找到输入框"
    echo "页面内容:"
    echo "$SNAPSHOT" | head -20
    agent-browser close 2>/dev/null
    exit 1
fi

echo "✅ 找到输入框: $INPUT_REF"

# 4. 填入 prompt
echo "📝 填入研究问题..."
agent-browser fill "$INPUT_REF" "$PROMPT" 2>/dev/null || {
    echo "⚠️ fill 失败，尝试 type..."
    agent-browser type "$INPUT_REF" "$PROMPT" 2>/dev/null
}

# 5. 查找并点击提交按钮
echo "🔍 查找提交按钮..."
sleep 1
SNAPSHOT=$(agent-browser snapshot -i 2>/dev/null || echo "")
SUBMIT_REF=$(echo "$SNAPSHOT" | grep -iE "(button|submit|send)" | head -1 | grep -oE '@e[0-9]+' | head -1)

if [ -z "$SUBMIT_REF" ]; then
    # 尝试按 Enter 键
    echo "📝 按 Enter 提交..."
    agent-browser press Enter 2>/dev/null
else
    echo "✅ 找到提交按钮: $SUBMIT_REF"
    agent-browser click "$SUBMIT_REF" 2>/dev/null
fi

# 6. 等待 AI 生成结果
echo "⏳ 等待 AI 生成结果（约 10-30 秒）..."
sleep 15

# 7. 获取结果
echo "📄 抓取结果..."
RESULT=$(agent-browser snapshot 2>/dev/null || echo "")

# 8. 提取论文信息
echo ""
echo "="$(printf '%*s' 70 '' | tr ' ' '=')
echo "📚 AlphaXiv 推荐论文"
echo "="$(printf '%*s' 70 '' | tr ' ' '=')
echo ""

# 尝试提取论文标题和链接
echo "$RESULT" | grep -iE "(https://arxiv.org/abs/|title|paper)" | head -30 || echo "💡 请查看上方完整输出"

# 9. 关闭浏览器
agent-browser close 2>/dev/null || true

echo ""
echo "✅ 完成！"
