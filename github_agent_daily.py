#!/usr/bin/env python3
"""
GitHub Agent 项目每日推送
每天早上9点抓取 GitHub trending，筛选5个 agent 相关项目推送
"""

import time
import subprocess
import os
import re
import json
from datetime import datetime, timedelta

# 配置
TARGET_HOUR = 9
TARGET_MINUTE = 0
MESSAGE_PREFIX = "🐙 GitHub 今日 Agent 项目推荐\n\n"
LOG_FILE = "/root/.openclaw/workspace/github_agent_daily.log"
OPENCLAW_PATH = "/root/.local/share/pnpm/openclaw"
NODE_PATH = "/root/.nvm/versions/node/v22.22.0/bin/node"

def log(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def send_message(message):
    """发送企业微信消息"""
    try:
        env = os.environ.copy()
        env['PATH'] = f"{NODE_PATH.rsplit('/', 1)[0]}:{env.get('PATH', '')}"
        env['NODE_PATH'] = "/root/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.2_@napi-rs+canvas@0.1.95_@types+express@5.0.6_hono@4.12.5_node-llama-cpp@3.16.2/node_modules/openclaw/node_modules:/root/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.2_@napi-rs+canvas@0.1.95_@types+express@5.0.6_hono@4.12.5_node-llama-cpp@3.16.2/node_modules:/root/.local/share/pnpm/global/5/.pnpm/node_modules"

        result = subprocess.run(
            ['bash', OPENCLAW_PATH, 'message', 'send', '--channel', 'wecom', '--target', 'XiongTao', '--message', message],
            capture_output=True,
            text=True,
            timeout=60,
            env=env
        )

        log(f"发送结果: {result.stdout}")
        if result.stderr:
            log(f"错误输出: {result.stderr}")

        return result.returncode == 0
    except Exception as e:
        log(f"❌ 发送失败: {e}")
        return False

def fetch_github_trending():
    """抓取 GitHub trending 页面"""
    try:
        result = subprocess.run(
            ['curl', '-s', '-L', '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
             'https://github.com/trending'],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout
    except Exception as e:
        log(f"❌ 抓取失败: {e}")
        return None

def parse_agent_projects(html):
    """解析 HTML，提取 agent 相关项目"""
    if not html:
        return []

    projects = []

    # 匹配项目块 - 更新后的 GitHub trending 页面结构
    # 尝试多种可能的模式
    patterns = [
        # 新模式：article 标签内的 repo
        r'<article[^>]*class="[^"]*Box-row[^"]*"[^>]*>.*?<h2[^>]*>.*?<a[^>]*href="(/[^/]+/[^"]+)"[^>]*>([^<]+)</a>.*?</h2>',
        # 旧模式
        r'<h2[^>]*>\s*<a[^>]*href="(/[^/]+/[^"]+)"[^>]*>([^<]+)</a>\s*</h2>',
    ]

    matches = []
    for pattern in patterns:
        matches = re.findall(pattern, html, re.DOTALL)
        if matches:
            break

    agent_keywords = ['agent', 'ai', 'llm', 'gpt', 'claude', 'openai', 'automation', 'bot', 'assistant', 'copilot', 'mcp', 'swarm', 'workflow']

    seen = set()
    for match in matches:
        repo_path = match[0].strip()  # /owner/repo
        repo_name = match[1].strip()

        # 去重
        if repo_path in seen:
            continue
        seen.add(repo_path)

        # 清理路径
        repo_path = repo_path.strip('/')

        # 检查是否包含 agent 相关关键词
        repo_lower = (repo_path + ' ' + repo_name).lower()
        is_agent_related = any(keyword in repo_lower for keyword in agent_keywords)

        if is_agent_related:
            # 提取星数 - 尝试多种模式
            stars = "?"
            star_patterns = [
                rf'<a[^>]*href="/{re.escape(repo_path)}/stargazers"[^>]*>\s*([\d,.kKmM]+)\s*</a>',
                rf'href="/{re.escape(repo_path)}/stargazers"[^>]*>([^<]+)</a>',
                rf'{re.escape(repo_path)}.*?([\d,.kKmM]+)\s*stars?',
            ]
            for star_pattern in star_patterns:
                star_match = re.search(star_pattern, html, re.IGNORECASE)
                if star_match:
                    stars = star_match.group(1).strip()
                    break

            # 提取描述
            description = "No description"
            desc_patterns = [
                rf'<article[^>]*>.*?<h2[^>]*>.*?{re.escape(repo_path)}.*?</h2>.*?<p[^>]*>(.*?)</p>',
                rf'<h2[^>]*>.*?{re.escape(repo_path)}.*?</h2>.*?<p[^>]*class="[^"]*col-9[^"]*"[^>]*>([^<]+)</p>',
                rf'{re.escape(repo_path)}.*?<p[^>]*>([^<]+)</p>',
            ]
            for desc_pattern in desc_patterns:
                desc_match = re.search(desc_pattern, html, re.DOTALL)
                if desc_match:
                    description = re.sub(r'<[^>]+>', '', desc_match.group(1)).strip()
                    break

            projects.append({
                'name': repo_path,
                'url': f"https://github.com/{repo_path}",
                'stars': stars,
                'description': description[:100] + ('...' if len(description) > 100 else '')
            })

            if len(projects) >= 5:
                break

    return projects

def fetch_github_search():
    """备选方案：通过 GitHub API 搜索 agent 项目"""
    try:
        # 搜索最近更新的 agent 相关项目
        result = subprocess.run(
            ['curl', '-s', '-H', 'Accept: application/vnd.github.v3+json',
             '-H', 'User-Agent: Mozilla/5.0',
             'https://api.github.com/search/repositories?q=agent+language:python+stars:>1000&sort=updated&order=desc&per_page=5'],
            capture_output=True,
            text=True,
            timeout=30
        )

        if not result.stdout:
            log("API 返回空数据")
            return []

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            log(f"JSON 解析失败: {e}")
            return []

        if 'items' not in data:
            log(f"API 返回异常: {data.get('message', '未知错误')}")
            return []

        projects = []
        for item in data.get('items', []):
            desc = item.get('description', '') or "No description"
            projects.append({
                'name': item['full_name'],
                'url': item['html_url'],
                'stars': str(item['stargazers_count']),
                'description': desc[:100] + ('...' if len(desc) > 100 else '')
            })

        return projects
    except Exception as e:
        log(f"❌ API 搜索失败: {e}")
        return []

def format_message(projects):
    """格式化消息"""
    if not projects:
        return "🐙 今天没找到 agent 相关的热门项目"

    msg = MESSAGE_PREFIX
    for i, p in enumerate(projects, 1):
        msg += f"{i}. **{p['name']}** ⭐{p['stars']}\n"
        msg += f"   {p['description']}\n"
        msg += f"   {p['url']}\n\n"

    msg += "---\n每天9点自动推送 🦐"
    return msg

def wait_until_next_run():
    """等待到下次运行时间（明天9点）"""
    now = datetime.now()
    next_run = now.replace(hour=TARGET_HOUR, minute=TARGET_MINUTE, second=0, microsecond=0)

    if now >= next_run:
        # 如果已经过了今天的9点，等到明天
        next_run = next_run + timedelta(days=1)

    log(f"等待到下次运行: {next_run.strftime('%Y-%m-%d %H:%M')}")

    while datetime.now() < next_run:
        remaining = (next_run - datetime.now()).total_seconds()
        if remaining > 60:
            log(f"距离下次运行还有 {int(remaining // 60)} 分钟")
            time.sleep(60)
        else:
            time.sleep(1)

def main():
    log("=" * 50)
    log("GitHub Agent 项目每日推送脚本启动")
    log(f"推送时间: 每天 {TARGET_HOUR:02d}:{TARGET_MINUTE:02d}")

    while True:
        now = datetime.now()

        # 检查是否到了推送时间
        if now.hour == TARGET_HOUR and now.minute == TARGET_MINUTE:
            log("⏰ 开始抓取 GitHub...")

            # 抓取 trending
            html = fetch_github_trending()
            projects = parse_agent_projects(html)

            # 如果没找到，用 API 搜索备选
            if not projects:
                log("Trending 未找到 agent 项目，尝试 API 搜索...")
                projects = fetch_github_search()

            # 格式化并发送
            message = format_message(projects)
            log(f"找到 {len(projects)} 个项目，正在发送...")

            success = send_message(message)
            if success:
                log("✅ 推送成功")
            else:
                log("❌ 推送失败")

            # 等待1分钟，避免重复发送
            time.sleep(60)

            # 等待到明天
            wait_until_next_run()
        else:
            # 每分钟检查一次
            time.sleep(60)

if __name__ == '__main__':
    main()
