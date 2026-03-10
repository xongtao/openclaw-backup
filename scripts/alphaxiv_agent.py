#!/usr/bin/env python3
"""
AlphaXiv Agent 自动化 - 高级版
带反爬虫绕过和调试功能
"""

import asyncio
import sys
import json
from playwright.async_api import async_playwright

RESEARCH_PROMPT = """Search for the latest papers on 3D structure modality fusion in protein design. 
Specifically focus on two technical directions: 
1) Discrete tokenization of 3D structures (tokenizer discretization), 
and 2) Continuous generative methods including Diffusion Models and Flow Matching."""

async def alphaxiv_search(prompt: str = RESEARCH_PROMPT):
    """在 AlphaXiv 搜索论文"""
    
    print("🦐 启动 AlphaXiv Agent 自动化...")
    print(f"研究问题: {prompt[:80]}...")
    print("")
    
    async with async_playwright() as p:
        # 启动浏览器 - 更真实的配置
        browser = await p.chromium.launch(
            headless=True,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-web-security',
                '--disable-features=IsolateOrigins,site-per-process',
            ]
        )
        
        # 创建带真实指纹的上下文
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            locale='en-US',
            timezone_id='America/New_York',
            color_scheme='light',
        )
        
        # 注入脚本绕过 webdriver 检测
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
            Object.defineProperty(navigator, 'plugins', {
                get: () => [1, 2, 3, 4, 5]
            });
            window.chrome = { runtime: {} };
        """)
        
        page = await context.new_page()
        
        # 设置超时
        page.set_default_timeout(60000)
        
        try:
            # 1. 打开 AlphaXiv
            print("🌐 打开 AlphaXiv...")
            response = await page.goto("https://www.alphaxiv.org/", 
                                      wait_until="domcontentloaded",
                                      timeout=60000)
            print(f"   页面状态: {response.status if response else 'unknown'}")
            
            # 等待初始加载
            await asyncio.sleep(3)
            
            # 保存初始截图
            await page.screenshot(path="/tmp/alphaxiv_step1_open.png")
            print("   📸 截图: /tmp/alphaxiv_step1_open.png")
            
            # 2. 查找输入框 - 多种策略
            print("🔍 查找输入框...")
            
            input_box = None
            input_selector = None
            
            # 策略1: 找 placeholder 包含 Ask 的元素
            for placeholder in ['Ask', 'Search', 'search', 'ask']:
                try:
                    elem = await page.wait_for_selector(f'[placeholder*="{placeholder}"]', timeout=2000)
                    if elem:
                        input_box = elem
                        input_selector = f'[placeholder*="{placeholder}"]'
                        print(f"   ✅ 找到输入框 (placeholder): {input_selector}")
                        break
                except:
                    continue
            
            # 策略2: 找 contenteditable
            if not input_box:
                try:
                    elem = await page.wait_for_selector('[contenteditable="true"]', timeout=3000)
                    if elem:
                        input_box = elem
                        input_selector = '[contenteditable="true"]'
                        print(f"   ✅ 找到输入框 (contenteditable)")
                except:
                    pass
            
            # 策略3: 找 textarea
            if not input_box:
                try:
                    elem = await page.wait_for_selector('textarea', timeout=3000)
                    if elem:
                        input_box = elem
                        input_selector = 'textarea'
                        print(f"   ✅ 找到输入框 (textarea)")
                except:
                    pass
            
            if not input_box:
                print("❌ 无法找到输入框")
                # 保存页面源码调试
                html = await page.content()
                with open('/tmp/alphaxiv_page.html', 'w') as f:
                    f.write(html[:10000])
                print("   📝 HTML已保存: /tmp/alphaxiv_page.html")
                await browser.close()
                return None
            
            # 3. 填入 prompt
            print("📝 填入研究问题...")
            
            # 先点击输入框聚焦
            await input_box.click()
            await asyncio.sleep(0.5)
            
            # 清空并输入
            await input_box.fill("")
            await asyncio.sleep(0.3)
            await input_box.fill(prompt)
            await asyncio.sleep(1)
            
            # 保存截图
            await page.screenshot(path="/tmp/alphaxiv_step2_input.png")
            print("   📸 截图: /tmp/alphaxiv_step2_input.png")
            
            # 4. 提交查询
            print("🚀 提交查询...")
            
            # 尝试点击发送按钮
            button_clicked = False
            for btn_text in ['Search', 'Ask', 'Send', 'Submit']:
                try:
                    btn = await page.wait_for_selector(f'button:has-text("{btn_text}")', timeout=2000)
                    if btn:
                        await btn.click()
                        button_clicked = True
                        print(f"   ✅ 点击按钮: {btn_text}")
                        break
                except:
                    continue
            
            if not button_clicked:
                # 按 Enter
                print("   📝 按 Enter 提交")
                await input_box.press("Enter")
            
            await asyncio.sleep(2)
            
            # 保存截图
            await page.screenshot(path="/tmp/alphaxiv_step3_submit.png")
            print("   📸 截图: /tmp/alphaxiv_step3_submit.png")
            
            # 5. 等待结果加载
            print("⏳ 等待 AI 生成结果...")
            
            papers = []
            max_wait = 12  # 最多等60秒
            
            for i in range(max_wait):
                await asyncio.sleep(5)
                print(f"   等待中... ({i+1}/{max_wait})")
                
                # 检查是否有 arxiv 链接出现
                links = await page.query_selector_all('a[href*="arxiv.org/abs/"]')
                if len(links) > 0:
                    print(f"   ✅ 检测到 {len(links)} 个结果！")
                    
                    # 等待内容稳定
                    await asyncio.sleep(3)
                    
                    # 提取论文
                    papers = await extract_papers_from_page(page)
                    if papers:
                        break
            
            # 保存最终截图
            await page.screenshot(path="/tmp/alphaxiv_step4_final.png", full_page=True)
            print("   📸 截图: /tmp/alphaxiv_step4_final.png")
            
            # 6. 关闭浏览器
            await browser.close()
            
            return papers
            
        except Exception as e:
            print(f"❌ 出错: {e}")
            import traceback
            traceback.print_exc()
            
            # 保存错误截图
            try:
                await page.screenshot(path="/tmp/alphaxiv_error.png")
                print("   📸 错误截图: /tmp/alphaxiv_error.png")
            except:
                pass
            
            await browser.close()
            return None

async def extract_papers_from_page(page):
    """从页面提取论文"""
    
    print("📄 提取论文信息...")
    
    # 获取所有 arxiv 链接
    links = await page.query_selector_all('a[href*="arxiv.org/abs/"]')
    print(f"   找到 {len(links)} 个 arXiv 链接")
    
    papers = []
    seen = set()
    
    for link in links[:10]:
        try:
            href = await link.get_attribute('href')
            if not href or href in seen:
                continue
            
            seen.add(href)
            
            # 获取链接文本作为标题
            text = await link.inner_text()
            
            # 如果文本太短，尝试父元素
            if not text or len(text) < 15:
                parent = await link.evaluate('el => el.parentElement?.textContent?.substring(0, 200)')
                if parent:
                    text = parent
            
            # 清理标题
            title = text.strip().replace('\n', ' ').replace('  ', ' ')[:300]
            
            if title and len(title) > 10:
                papers.append({
                    'title': title,
                    'link': href
                })
                print(f"   📑 [{len(papers)}] {title[:60]}...")
        except Exception as e:
            print(f"   ⚠️ 提取失败: {e}")
            continue
    
    return papers

def format_output(papers):
    """格式化输出"""
    if not papers:
        print("\n📭 未找到论文")
        return
    
    print("\n" + "="*70)
    print("📚 AlphaXiv 推荐论文")
    print("="*70)
    print("")
    
    for i, paper in enumerate(papers[:5], 1):
        print(f"【{i}】{paper['title']}")
        print(f"🔗 {paper['link']}")
        print("")
    
    # 也输出 JSON 格式方便后续处理
    print("\n" + "="*70)
    print("JSON 格式:")
    print(json.dumps(papers[:5], ensure_ascii=False, indent=2))

if __name__ == "__main__":
    papers = asyncio.run(alphaxiv_search(RESEARCH_PROMPT))
    
    if papers:
        format_output(papers)
    else:
        print("\n❌ 未能获取论文列表")
        print("\n调试文件:")
        print("  - /tmp/alphaxiv_step1_open.png")
        print("  - /tmp/alphaxiv_step2_input.png")
        print("  - /tmp/alphaxiv_step3_submit.png")
        print("  - /tmp/alphaxiv_step4_final.png")
        sys.exit(1)
