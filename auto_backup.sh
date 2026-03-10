#!/bin/bash
# 皮皮虾 Agent 自动备份脚本 - 优化版
# 确保每次备份都是最新版本

BACKUP_DIR="/root/.openclaw/workspace-backup"
SOURCE_DIR="/root/.openclaw/workspace"
LOG_FILE="/var/log/openclaw-backup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "开始备份..."

cd $BACKUP_DIR

# 方法1: 使用 rsync（如果有安装）
if command -v rsync &> /dev/null; then
    log "使用 rsync 同步..."
    
    # 同步根目录 MD 文件
    rsync -av --delete --include='*.md' --exclude='*' $SOURCE_DIR/ ./ 2>/dev/null || true
    
    # 同步 memory 目录
    mkdir -p memory
    rsync -av --delete $SOURCE_DIR/memory/ memory/ 2>/dev/null || true
    
    # 同步 scripts
    mkdir -p scripts
    if [ -d $SOURCE_DIR/arxiv_tracker ]; then
        rsync -av --delete $SOURCE_DIR/arxiv_tracker/ scripts/ 2>/dev/null || true
    fi
    
else
    # 方法2: 使用 cp -f 强制覆盖（确保最新版本）
    log "使用 cp 同步..."
    
    # 复制根目录 MD 文件（强制覆盖）
    for file in $SOURCE_DIR/*.md; do
        if [ -f "$file" ]; then
            cp -f "$file" ./ 2>/dev/null || true
        fi
    done
    
    # 同步 memory 目录
    mkdir -p memory
    for file in $SOURCE_DIR/memory/*.md; do
        if [ -f "$file" ]; then
            cp -f "$file" memory/ 2>/dev/null || true
        fi
    done
    
    # 同步 scripts
    mkdir -p scripts
    if [ -d $SOURCE_DIR/arxiv_tracker ]; then
        for file in $SOURCE_DIR/arxiv_tracker/*.sh; do
            if [ -f "$file" ]; then
                cp -f "$file" scripts/ 2>/dev/null || true
            fi
        done
    fi
fi

# 检查是否有变更
if git diff --quiet && git diff --cached --quiet; then
    log "无变更，跳过提交"
    exit 0
fi

# 统计变更
CHANGED=$(git diff --name-only | wc -l)
ADDED=$(git ls-files --others --exclude-standard | wc -l)

log "检测到变更: $CHANGED 个文件修改, $ADDED 个新文件"

# 提交
git add .
git commit -m "🦐 自动备份: $(date '+%Y-%m-%d %H:%M:%S')

变更统计:
- 修改: $CHANGED 个文件
- 新增: $ADDED 个文件

由皮皮虾 Agent 自动备份" >> $LOG_FILE 2>&1

# 推送到 GitHub
if git remote get-url origin 2>/dev/null; then
    if git push origin master >> $LOG_FILE 2>&1; then
        log "✅ 已推送到 GitHub"
    else
        log "❌ 推送失败"
    fi
else
    log "⚠️ 未配置远程仓库"
fi

log "备份完成"
