#!/usr/bin/env python3
"""
用 Playwright 截取上海天气页面
"""

from playwright.sync_api import sync_playwright
import time

def main():
    with sync_playwright() as p:
        # 启动浏览器（无头模式）
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={'width': 1920, 'height': 1080})
        page = context.new_page()

        # 打开 wttr.in 天气页面（ASCII艺术界面）
        print("打开 wttr.in 天气页面...")
        page.goto('https://wttr.in/Shanghai?lang=zh')
        page.wait_for_load_state('networkidle')
        time.sleep(2)

        # 截图
        screenshot_path = '/root/.openclaw/workspace/shanghai_weather.png'
        page.screenshot(path=screenshot_path, full_page=True)
        print(f"截图已保存: {screenshot_path}")

        # 保持浏览器打开5秒让你看到
        time.sleep(5)

        browser.close()

if __name__ == '__main__':
    main()
