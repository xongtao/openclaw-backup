#!/bin/bash
# 皮皮虾 Agent 自动备份脚本 - GitHub 同步版
# 每6小时同步 workspace 到 GitHub

BACKUP_DIR="/root/.openclaw/workspace-backup"
SOURCE_DIR="/root/.openclaw/workspace"
LOG_FILE="/var/log/openclaw-backup.log"

# GitHub 配置（从环境变量读取 token）
GITHUB_USER="xongtao"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_NAME="openclaw-backup"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "开始备份..."

cd $BACKUP_DIR

# 检查 token
if [ -z "$GITHUB_TOKEN" ]; then
    log "❌ GITHUB_TOKEN 环境变量未设置"
    exit 1
fi

# 方法1: 使用 rsync（如果有安装）
if command -v rsync &> /dev/null; then
    log "使用 rsync 同步..."
    
    rsync -av $SOURCE_DIR/*.md ./ 2>/dev/null || true
    
    mkdir -p memory
    rsync -av --delete $SOURCE_DIR/memory/ memory/ 2>/dev/null || true
    
    mkdir -p scripts
    if [ -d $SOURCE_DIR/arxiv_tracker ]; then
        rsync -av $SOURCE_DIR/arxiv_tracker/*.sh scripts/ 2>/dev/null || true
    fi
else
    log "使用 cp 同步..."
    
    for file in $SOURCE_DIR/*.md; do
        [ -f "$file" ] && cp -f "$file" ./ 2>/dev/null || true
    done
    
    mkdir -p memory
    for file in $SOURCE_DIR/memory/*.md; do
        [ -f "$file" ] && cp -f "$file" memory/ 2>/dev/null || true
    done
    
    mkdir -p scripts
    if [ -d $SOURCE_DIR/arxiv_tracker ]; then
        for file in $SOURCE_DIR/arxiv_tracker/*.sh; do
            [ -f "$file" ] && cp -f "$file" scripts/ 2>/dev/null || true
        done
    fi
fi

# 检查是否有变更
if git diff --quiet && git diff --cached --quiet; then
    log "无变更，跳过提交"
    exit 0
fi

CHANGED=$(git diff --name-only | wc -l)
ADDED=$(git ls-files --others --exclude-standard | wc -l)

log "检测到变更: $CHANGED 个文件修改, $ADDED 个新文件"

git add .
git commit -m "🦐 自动备份: $(date '+%Y-%m-%d %H:%M:%S')

变更统计:
- 修改: $CHANGED 个文件
- 新增: $ADDED 个文件

由皮皮虾 Agent 自动备份" >> $LOG_FILE 2>&1

# 推送到 GitHub
REMOTE_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
if git push "$REMOTE_URL" master >> $LOG_FILE 2>&1 || git push "$REMOTE_URL" main >> $LOG_FILE 2>&1; then
    log "✅ 已推送到 GitHub"
else
    log "❌ 推送失败"
fi

log "备份完成"
