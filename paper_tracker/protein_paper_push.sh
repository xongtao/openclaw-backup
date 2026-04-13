#!/bin/bash
# 🧬 蛋白质设计论文推送脚本 - 智能评分版 v2
# 每天早上8点执行，推送前24小时的论文

set -e

LOG_FILE="/var/log/protein_paper.log"
LOCK_FILE="/tmp/protein_paper.lock"
SILENT_ON_EMPTY="true"  # 空结果时不推送

# 锁机制防止重复执行
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[$(date)] 另一个实例正在运行，退出" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] ========== 开始论文检索 ==========" >> "$LOG_FILE"

# 工作目录
WORK_DIR="/root/.openclaw/workspace/paper_tracker"
cd "$WORK_DIR"

# 计算日期范围（过去48小时，确保不遗漏）
START_DATE=$(date -u -d '48 hours ago' +%Y-%m-%d)

echo "[$(date)] 检索时间范围: 从 $START_DATE 至今" >> "$LOG_FILE"
echo "[$(date)] 正在获取 arXiv 数据..." >> "$LOG_FILE"

# 统一查询：蛋白质+生成模型（扩大查询范围）
QUERY="all:protein+AND+(all:diffusion+OR+all:generative+OR+all:design+OR+all:language+model+OR+all:autoencoder+OR+all:transformer+OR+all:tokenization+OR+all:flow+matching+OR+all:inverse+folding+OR+all:structure+prediction)"
URL="https://export.arxiv.org/api/query?search_query=${QUERY}&start=0&max_results=100&sortBy=submittedDate&sortOrder=descending"

# 获取数据
fetch_data() {
    local url=$1
    local output=$2
    for i in {1..3}; do
        if curl -sL --max-time 45 "$url" -o "$output" 2>/dev/null; then
            if [ -s "$output" ] && grep -q "<feed" "$output"; then
                return 0
            fi
        fi
        sleep 2
    done
    return 1
}

fetch_data "$URL" /tmp/arxiv_protein.xml || echo "[$(date)] arXiv查询失败" >> "$LOG_FILE"

echo "[$(date)] 数据获取完成，开始处理..." >> "$LOG_FILE"

# 使用 Python 处理结果
python3 -c "
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
import os

# ========== 关键词配置 ==========
# 高权重关键词（直接匹配给3分）
HIGH_WEIGHT = {
    'plm': ['protein language model', 'protein-language', 'plm '],
    'esm': ['esm', 'esm-2', 'esm-3', 'esm2', 'esm3', 'esmfold'],
    'ae': ['autoencoder', 'proteinae', 'protein-ae', 'protein ae', 'vae', 'variational autoencoder'],
    'tokenizer': ['tokenizer', 'tokenization', 'vq-vae', 'vqvae', 'codebook', 'discrete diffusion', 'quantization'],
    'flow': ['flow matching', 'flow-matching'],
}

# 中权重关键词（给2分）
MED_WEIGHT = [
    'diffusion', 'rfdiffusion', 'chroma', 'protein diffusion',
    'inverse folding', 'sequence-structure', 'co-design',
    'protein design', 'protein generation', 'de novo protein'
]

# 低权重关键词（给1分）
LOW_WEIGHT = [
    'structure prediction', 'backbone design', 'geometric deep learning',
    'equivariant', 'gnn protein', 'graph neural network protein',
    'structure-conditioned', '3d protein', 'protein structure'
]

ns = {'atom': 'http://www.w3.org/2005/Atom'}
cutoff_time = datetime.now(timezone.utc) - timedelta(hours=24)

xml_file = '/tmp/arxiv_protein.xml'
if not os.path.exists(xml_file) or os.path.getsize(xml_file) < 100:
    print('ERROR: 数据文件不存在或为空')
    exit(1)

try:
    root = ET.parse(xml_file).getroot()
except Exception as e:
    print(f'ERROR: 解析XML失败: {e}')
    exit(1)

all_papers = {}

for entry in root.findall('atom:entry', ns):
    try:
        published_str = entry.find('atom:published', ns).text
        published = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
        
        # 只取最近24小时
        if published < cutoff_time:
            continue
        
        title = entry.find('atom:title', ns).text.strip().replace(chr(10), ' ')
        summary_elem = entry.find('atom:summary', ns)
        summary = summary_elem.text.strip() if summary_elem is not None else ''
        authors = [a.find('atom:name', ns).text for a in entry.findall('atom:author', ns)]
        link = entry.find('atom:id', ns).text
        
        # 去重
        if title in all_papers:
            continue
        
        text = (title + ' ' + summary).lower()
        
        # ========== 评分系统 ==========
        score = 0
        matched_tags = []
        
        # 高权重匹配（+3分）
        for category, keywords in HIGH_WEIGHT.items():
            for kw in keywords:
                if kw.lower() in text:
                    score += 3
                    matched_tags.append(f'🔥{category.upper()}')
                    break
        
        # 中权重匹配（+2分）
        for kw in MED_WEIGHT:
            if kw.lower() in text:
                score += 2
                matched_tags.append(kw.replace(' ', '-'))
        
        # 低权重匹配（+1分）
        for kw in LOW_WEIGHT:
            if kw.lower() in text:
                score += 1
                matched_tags.append(kw.replace(' ', '-'))
        
        # 去重标签
        matched_tags = list(dict.fromkeys(matched_tags))
        
        # 只保留评分 >= 4 的论文（相关性较高）
        if score < 4:
            continue
        
        all_papers[title] = {
            'title': title,
            'authors': authors[:2],
            'summary': summary[:350] + '...' if len(summary) > 350 else summary,
            'link': link,
            'published': published.strftime('%Y-%m-%d'),
            'score': score,
            'tags': matched_tags[:6]  # 最多显示6个标签
        }
    except Exception as e:
        continue

# 按评分和日期排序
papers = list(all_papers.values())
papers.sort(key=lambda x: (x['score'], x['published']), reverse=True)

# 生成推送消息
if not papers:
    with open('/tmp/paper_push_msg.txt', 'w') as f:
        f.write('EMPTY')
    print('OK:0')
else:
    lines = [
        f'🧬 蛋白质设计论文速递 ({datetime.now().strftime(\"%Y-%m-%d\")})',
        '',
        f'📊 发现 {len(papers)} 篇高相关论文（按相关度排序）',
        ''
    ]
    for i, p in enumerate(papers[:10], 1):
        authors_str = ', '.join(p['authors']) + (' et al.' if len(p['authors']) == 2 else '')
        tags_str = ' | '.join(p['tags']) if p['tags'] else 'protein-AI'
        fire_emoji = '🔥' if p['score'] >= 7 else ('⭐' if p['score'] >= 5 else '•')
        lines.extend([
            f'{fire_emoji} [{i}] {p[\"title\"]}',
            f'   👤 {authors_str} | 📅 {p[\"published\"]}',
            f'   🏷️ 相关度:{p[\"score\"]}/10 | {tags_str}',
            f'   💡 {p[\"summary\"][:150]}...',
            f'   🔗 {p[\"link\"]}',
            ''
        ])
    if len(papers) > 10:
        lines.append(f'... 还有 {len(papers) - 10} 篇论文未显示')
    lines.extend(['', f'📡 推送时间: {datetime.now().strftime(\"%Y-%m-%d %H:%M\")}', '🦐 by 皮皮虾'])
    
    with open('/tmp/paper_push_msg.txt', 'w', encoding='utf-8') as f:
        f.write(chr(10).join(lines))
    print(f'OK:{len(papers)}')
" 2>&1 | tee -a "$LOG_FILE"

# 检查结果
if [ -f /tmp/paper_push_msg.txt ]; then
    MSG=$(cat /tmp/paper_push_msg.txt)
    if [ "$MSG" = "EMPTY" ] && [ "$SILENT_ON_EMPTY" = "true" ]; then
        echo "[$(date)] 未发现高相关论文，静默处理" >> "$LOG_FILE"
        echo "[$(date)] ========== 完成（无推送）==========" >> "$LOG_FILE"
        echo "未发现高相关论文（评分>=4），静默处理。"
        exit 0
    fi
    
    echo "[$(date)] 消息生成成功" >> "$LOG_FILE"
    echo "[$(date)] 消息长度: ${#MSG} 字符" >> "$LOG_FILE"
    cat /tmp/paper_push_msg.txt
else
    echo "[$(date)] ❌ 消息生成失败" >> "$LOG_FILE"
    echo "消息生成失败，请检查日志"
fi

echo "[$(date)] ========== 完成 ==========" >> "$LOG_FILE"
exit 0
