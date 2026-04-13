#!/bin/bash
# OpenClaw Data Auto Sync Script
# 自动同步 /root/data 到 GitHub

REPO_NAME="openclaw-data"
GITHUB_USER="xongtao"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
DATA_DIR="/root/data"
LOG_FILE="/var/log/openclaw-data-sync.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检查 token
check_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        # 尝试从 .bashrc 加载
        source ~/.bashrc 2>/dev/null || true
        if [ -z "$GITHUB_TOKEN" ]; then
            log "❌ GITHUB_TOKEN 环境变量未设置"
            return 1
        fi
    fi
    return 0
}

# 同步数据
sync_data() {
    log "🔄 开始同步数据..."
    
    cd "$DATA_DIR" || exit 1
    
    # 更新 README 中的时间戳
    sed -i "s/Last sync: .*/Last sync: $(date '+%Y-%m-%d %H:%M:%S')/" README.md
    
    # 检查是否有变更
    if git diff --quiet && git diff --staged --quiet; then
        log "ℹ️ 没有变更需要提交"
        return 0
    fi
    
    # 添加所有变更
    git add -A
    
    # 提交
    git commit -m "Auto sync: $(date '+%Y-%m-%d %H:%M:%S')" || {
        log "⚠️ 提交失败或没有变更"
        return 0
    }
    
    # 推送到 GitHub（使用 token）
    if git push "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git" master 2>/dev/null || \
       git push "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git" main 2>/dev/null; then
        log "✅ 数据同步成功: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    else
        log "❌ 推送失败"
        return 1
    fi
}

# 主函数
main() {
    log "=== OpenClaw Data Sync Started ==="
    
    if ! check_token; then
        exit 1
    fi
    
    sync_data
    log "=== OpenClaw Data Sync Completed ==="
}

# 运行主函数
main
