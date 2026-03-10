# arXiv 蛋白质设计论文追踪器 - AlphaXiv 精简版
# 直接订阅类别 + 关键词预筛选 + AI精选

import os
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta
from typing import List, Dict

# 加载 .env 文件
def load_env():
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

load_env()

# 配置
TENCENT_API_KEY = os.getenv("TENCENT_API_KEY", "")
TENCENT_BASE_URL = os.getenv("TENCENT_BASE_URL", "https://api.lkeap.cloud.tencent.com/coding/v3")
TENCENT_MODEL = os.getenv("TENCENT_MODEL", "kimi-k2.5")
PAPER_DB_PATH = "/root/.openclaw/workspace/memory/arxiv_papers.json"

RESEARCH_INTEREST = """3D structure modality fusion in protein design.
Focus on: 1) Discrete tokenization of 3D structures, 2) Diffusion Models and Flow Matching."""

SUBSCRIBED_CATEGORIES = ["q-bio.BM", "cs.LG", "cs.AI"]
ARXIV_API_URL = "http://export.arxiv.org/api/query"

class ArxivTracker:
    def __init__(self):
        self.paper_db = self.load_paper_db()
    
    def load_paper_db(self) -> Dict:
        if os.path.exists(PAPER_DB_PATH):
            with open(PAPER_DB_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {"tracked_papers": []}
    
    def save_paper_db(self):
        os.makedirs(os.path.dirname(PAPER_DB_PATH), exist_ok=True)
        with open(PAPER_DB_PATH, 'w', encoding='utf-8') as f:
            json.dump(self.paper_db, f, ensure_ascii=False, indent=2)
    
    def fetch_category_papers(self, category: str, max_results: int = 20) -> List[Dict]:
        url = f"{ARXIV_API_URL}?search_query=cat:{category}&start=0&max_results={max_results}&sortBy=submittedDate&sortOrder=descending"
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=60) as response:
                return self.parse_arxiv_response(response.read().decode('utf-8'))
        except Exception as e:
            print(f"获取 {category} 失败: {e}")
            return []
    
    def parse_arxiv_response(self, xml_data: str) -> List[Dict]:
        import xml.etree.ElementTree as ET
        papers = []
        try:
            root = ET.fromstring(xml_data)
            ns = {'atom': 'http://www.w3.org/2005/Atom'}
            for entry in root.findall('atom:entry', ns):
                paper = {
                    "id": entry.find('atom:id', ns).text if entry.find('atom:id', ns) is not None else "",
                    "title": entry.find('atom:title', ns).text.strip() if entry.find('atom:title', ns) is not None else "",
                    "summary": entry.find('atom:summary', ns).text.strip() if entry.find('atom:summary', ns) is not None else "",
                    "published": entry.find('atom:published', ns).text if entry.find('atom:published', ns) is not None else "",
                    "authors": [a.find('atom:name', ns).text for a in entry.findall('atom:author', ns) if a.find('atom:name', ns) is not None],
                    "categories": [c.get('term') for c in entry.findall('atom:category', ns)]
                }
                arxiv_id = paper['id'].split('/')[-1].replace('abs/', '').split('v')[0]
                paper["link"] = f"https://arxiv.org/abs/{arxiv_id}"
                papers.append(paper)
        except Exception as e:
            print(f"解析出错: {e}")
        return papers
    
    def is_new_paper(self, paper_id: str) -> bool:
        return paper_id not in self.paper_db.get("tracked_papers", [])
    
    def is_recent_paper(self, paper: Dict, days: int = 14) -> bool:
        try:
            pub_date = datetime.fromisoformat(paper['published'].replace('Z', '+00:00').replace('+00:00', ''))
            return (datetime.now() - timedelta(days=days)) <= pub_date
        except:
            return True
    
    def keyword_score(self, paper: Dict) -> int:
        """关键词评分"""
        text = (paper['title'] + ' ' + paper['summary']).lower()
        score = 0
        # 必须含蛋白质相关
        if any(k in text for k in ['protein', 'peptide', 'enzyme', 'antibody', 'binding']):
            score += 10
        # 技术关键词
        tech_keywords = {
            'diffusion': 15, 'flow matching': 15, 'tokenization': 15, 'tokenizer': 15,
            'vqvae': 15, 'codebook': 15, 'generative': 10,
            '3d structure': 10, 'coordinate': 10, 'conformation': 10,
            'multimodal': 8, 'modality': 8, 'representation': 5
        }
        for kw, s in tech_keywords.items():
            if kw in text:
                score += s
        return score
    
    def batch_ai_screen(self, papers: List[Dict]) -> List[Dict]:
        """批量AI筛选（一次最多5篇）"""
        if not TENCENT_API_KEY or len(papers) == 0:
            return []
        
        # 只取前5篇
        batch = papers[:5]
        papers_text = "\n\n".join([
            f"[{i+1}] {p['title']}\n摘要: {p['summary'][:400]}"
            for i, p in enumerate(batch)
        ])
        
        prompt = f"""判断以下论文是否与蛋白质设计和AI生成模型相关。

关注：1)蛋白质结构表示 2)Diffusion/Flow Matching生成方法 3)3D结构tokenization

请返回JSON格式：
{{"results": [{{"index": 1, "relevant": true/false, "score": 0-100}}, ...]}}

论文：
{papers_text}"""
        
        try:
            req_data = json.dumps({
                "model": TENCENT_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3,
                "max_tokens": 600
            }).encode('utf-8')
            
            req = urllib.request.Request(
                f"{TENCENT_BASE_URL}/chat/completions",
                data=req_data,
                headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {TENCENT_API_KEY}'}
            )
            
            with urllib.request.urlopen(req, timeout=90) as response:
                result = json.loads(response.read().decode('utf-8'))
                content = result['choices'][0]['message'].get('content', '')
                
                # 提取JSON
                try:
                    if '```json' in content:
                        content = content.split('```json')[1].split('```')[0]
                    elif '```' in content:
                        content = content.split('```')[1].split('```')[0]
                    data = json.loads(content.strip())
                    results = data.get("results", [])
                    
                    selected = []
                    for r in results:
                        idx = r.get("index", 0) - 1
                        score = r.get("score", 0)
                        # 放宽到20分，只要是相关就通过
                        if 0 <= idx < len(batch) and r.get("relevant") == True:
                            selected.append({
                                "paper": batch[idx],
                                "score": score if score > 0 else 60,
                                "reason": "AI判定相关"
                            })
                    # 如果没选到，返回前2篇（保底）
                    if not selected and len(batch) > 0:
                        selected = [{"paper": batch[0], "score": 50, "reason": "关键词高匹配"}]
                    return selected
                except:
                    # 解析失败，返回前3篇
                    return [{"paper": batch[i], "score": 50, "reason": "关键词匹配"} for i in range(min(3, len(batch)))]
        except Exception as e:
            print(f"⚠️ AI筛选失败: {e}")
            # 失败时直接返回关键词分数最高的3篇
            print("   使用关键词匹配作为备选")
            return [{"paper": papers[i], "score": 50 + (5-i)*5, "reason": "关键词匹配"} for i in range(min(3, len(papers)))]
    
    def generate_summary(self, paper: Dict) -> str:
        """生成论文总结"""
        if not TENCENT_API_KEY:
            return "未配置API"
        
        prompt = f"""论文：{paper['title']}
摘要：{paper['summary'][:500]}

一句话总结核心技术："""
        
        try:
            req_data = json.dumps({
                "model": TENCENT_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3,
                "max_tokens": 200
            }).encode('utf-8')
            
            req = urllib.request.Request(
                f"{TENCENT_BASE_URL}/chat/completions",
                data=req_data,
                headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {TENCENT_API_KEY}'}
            )
            
            with urllib.request.urlopen(req, timeout=60) as response:
                result = json.loads(response.read().decode('utf-8'))
                msg = result['choices'][0]['message']
                content = msg.get('content', '').strip()
                reasoning = msg.get('reasoning_content', '').strip()
                
                if content:
                    return content
                elif reasoning:
                    # 从reasoning提取结论句
                    lines = [l.strip() for l in reasoning.split('\n') if l.strip()]
                    for line in reversed(lines):
                        if len(line) > 15 and not line.startswith(('用户', '我需要', '分析')):
                            return line[:200]
                    return reasoning[:200]
                return "该论文与蛋白质设计和生成模型相关"
        except Exception as e:
            return f"分析完成 ({str(e)[:30]})..."
    
    def generate_detailed_analysis(self, paper: Dict) -> str:
        """生成精读级别的论文分析"""
        if not TENCENT_API_KEY:
            return "未配置API，无法生成详细分析"
        
        # 精简版prompt，缩短生成时间
        prompt = f"""作为资深学术研究者，精读讲解以下论文（控制在800字内）：

论文：{paper['title']}
摘要：{paper['summary'][:800]}

输出格式：
📌 **研究背景** - 该问题为何重要？现有方法有何不足？
🔬 **核心方法** - 技术路线是什么？关键步骤？
💡 **创新点** - 相比现有工作的突破？
📊 **主要结论** - 关键实验结果？
⚠️ **局限性** - 方法缺陷或改进空间？

要求：
1. 中文输出
2. 原文引用用>标记
3. 聚焦专业知识讲解"""
        
        try:
            print("   🤖 生成精读分析...")
            req_data = json.dumps({
                "model": TENCENT_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.4,
                "max_tokens": 1500
            }).encode('utf-8')
            
            req = urllib.request.Request(
                f"{TENCENT_BASE_URL}/chat/completions",
                data=req_data,
                headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {TENCENT_API_KEY}'}
            )
            
            with urllib.request.urlopen(req, timeout=60) as response:
                result = json.loads(response.read().decode('utf-8'))
                msg = result['choices'][0]['message']
                content = msg.get('content', '').strip()
                
                if content:
                    return content
                return "详细分析生成失败"
        except Exception as e:
            return f"详细分析生成失败: {str(e)[:50]}"
    
    def run(self, target_count: int = 5, test_mode: bool = False):
        print("🦐 AlphaXiv 蛋白质设计论文追踪")
        print("="*60)
        
        # 1. 获取论文
        all_papers = []
        for cat in SUBSCRIBED_CATEGORIES:
            print(f"📥 获取 {cat}...")
            papers = self.fetch_category_papers(cat, max_results=20)
            for p in papers:
                if self.is_new_paper(p['id']) and self.is_recent_paper(p):
                    all_papers.append(p)
            print(f"   +{len([p for p in papers if self.is_new_paper(p['id'])])} 篇新论文")
        
        # 2. 去重
        seen = set()
        unique = []
        for p in all_papers:
            if p['id'] not in seen:
                seen.add(p['id'])
                unique.append(p)
        print(f"\n📊 候选: {len(unique)} 篇")
        
        if not unique:
            return "📭 无新论文"
        
        # 3. 关键词评分排序
        scored = [(p, self.keyword_score(p)) for p in unique]
        scored.sort(key=lambda x: x[1], reverse=True)
        
        # 测试模式：放宽条件，取前3篇
        if test_mode:
            top_candidates = [p for p, s in scored[:5]]
            print(f"🔍 【测试模式】取前 {len(top_candidates)} 篇")
        else:
            # 4. 取前10篇进行AI筛选
            top_candidates = [p for p, s in scored[:10] if s >= 15]
            print(f"🔍 关键词筛选: {len(top_candidates)} 篇")
        
        if not top_candidates:
            return "📭 关键词筛选无匹配"
        
        # 5. AI批量筛选（测试模式直接通过）
        print("🤖 AI筛选中...")
        if test_mode:
            selected = [{"paper": p, "score": 50, "reason": "测试模式"} for p in top_candidates[:3]]
        else:
            selected = self.batch_ai_screen(top_candidates)
        print(f"✅ AI通过: {len(selected)} 篇")
        
        if not selected:
            return "📭 AI筛选无通过"
        
        # 6. 生成报告
        selected.sort(key=lambda x: x["score"], reverse=True)
        final = selected[:target_count]
        
        report = [f"📚 蛋白质设计论文推荐 ({datetime.now().strftime('%m-%d %H:%M')})", "="*60]
        
        for i, item in enumerate(final, 1):
            p = item["paper"]
            print(f"📝 处理第 {i} 篇...")
            # 使用arXiv原文摘要
            summary = p.get('summary', '')[:200] + "..." if len(p.get('summary', '')) > 200 else p.get('summary', '')
            item['summary'] = summary
            
            authors = ", ".join(p['authors'][:2]) + (" et al." if len(p['authors']) > 2 else "")
            report.append(f"""
【{i}】{p['title']}
👤 {authors} | ⭐ {item['score']}/100 | 📅 {p['published'][:10]}
🔗 {p['link']}

💡 {summary}
""")
            
            self.paper_db.setdefault("tracked_papers", []).append(p['id'])
        
        self.save_paper_db()
        
        # 7. 推送到企业微信（基本信息+一句话摘要）
        self.push_to_wecom(final)
        
        # 8. 保存详细分析报告（可选，有需要时手动触发精读）
        self.save_analysis_report(final)
        
        return "\n".join(report)
    
    def push_to_wecom(self, papers):
        """推送到企业微信（基本信息+一句话摘要）"""
        import subprocess
        import os
        import time
        
        env = os.environ.copy()
        env['PATH'] = '/root/.nvm/versions/node/v22.22.0/bin:' + env.get('PATH', '')
        
        def send_msg(msg):
            """发送单条消息"""
            subprocess.run([
                '/root/.local/share/pnpm/openclaw', 'message', 'send',
                '--channel', 'wecom', '--target', 'XiongTao', '--message', msg
            ], env=env, capture_output=True)
            time.sleep(0.3)
        
        # 发送总标题
        title = f"🦐 📚 蛋白质设计论文推荐 ({datetime.now().strftime('%m-%d %H:%M')})"
        send_msg(title)
        send_msg(f"📖 共 {len(papers)} 篇论文 | 回复论文编号(1-{len(papers)})获取精读分析")
        
        # 发送每篇论文
        for idx, item in enumerate(papers, 1):
            p = item['paper']
            summary = item.get('summary', '分析中...')
            authors = ", ".join(p['authors'][:2]) + (" et al." if len(p['authors']) > 2 else "")
            
            msg = f"""━━━━━━━━━━━━━━━━━━━━
【{idx}】{p['title']}
👤 {authors} | ⭐ {item['score']}/100 | 📅 {p['published'][:10]}
🔗 {p['link']}

💡 {summary}
━━━━━━━━━━━━━━━━━━━━"""
            send_msg(msg)
            print(f"📤 已推送论文 {idx}/{len(papers)}: {p['title'][:30]}...")
        
        send_msg("✅ 推送完成！如需某篇论文的详细精读分析，回复对应编号(1/2/3...)")
    
    def save_analysis_report(self, papers):
        """保存论文分析报告到文件，供后续精读使用"""
        report_dir = "/root/.openclaw/workspace/arxiv_tracker/reports"
        os.makedirs(report_dir, exist_ok=True)
        
        date_str = datetime.now().strftime('%Y%m%d')
        report_file = f"{report_dir}/papers_{date_str}.json"
        
        data = []
        for item in papers:
            p = item['paper']
            data.append({
                'id': p['id'],
                'title': p['title'],
                'authors': p['authors'],
                'link': p['link'],
                'summary': item.get('summary', ''),
                'score': item['score']
            })
        
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        print(f"📄 论文列表已保存: {report_file}")
    
    def generate_full_analysis(self, paper_id: str) -> str:
        """生成单篇论文的完整精读分析（按需调用）"""
        # 从数据库查找论文
        all_papers = []
        for cat in SUBSCRIBED_CATEGORIES:
            all_papers.extend(self.fetch_category_papers(cat, max_results=50))
        
        paper = None
        for p in all_papers:
            if paper_id in p['id']:
                paper = p
                break
        
        if not paper:
            return "未找到该论文"
        
        return self.generate_detailed_analysis(paper)

if __name__ == "__main__":
    import sys
    test_mode = '--test' in sys.argv
    tracker = ArxivTracker()
    result = tracker.run(target_count=5, test_mode=test_mode)
    print(result)
