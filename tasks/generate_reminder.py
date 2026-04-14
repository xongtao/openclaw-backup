#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
每日任务倒计时提醒生成器
"""
import json
from datetime import datetime, timedelta

def load_tasks():
    with open('/home/ubuntu/.openclaw/workspace/tasks/daily_tasks.json', 'r', encoding='utf-8') as f:
        return json.load(f)

def days_until(deadline_str):
    """计算距离截止日期的天数"""
    deadline = datetime.fromisoformat(deadline_str)
    now = datetime.now()
    diff = deadline - now
    return diff.days

def format_countdown(days):
    """格式化倒计时显示"""
    if days < 0:
        return "⚠️ 已过期"
    elif days == 0:
        return "🔥 今天截止"
    elif days == 1:
        return "⏰ 明天截止"
    elif days <= 3:
        return f"🚨 剩{days}天"
    elif days <= 7:
        return f"⚡ 剩{days}天"
    else:
        return f"📅 剩{days}天"

def get_weekday_cn(weekday):
    """获取中文星期"""
    weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
    return weekdays[weekday]

def generate_reminder():
    data = load_tasks()
    tasks = data['tasks']
    now = datetime.now()
    
    # 获取今天星期几
    today_weekday = now.weekday()  # 0=周一, 1=周二...
    
    message = f"""📅 **早安！今日任务打卡** {now.strftime('%m月%d日')} {get_weekday_cn(today_weekday)}

"""
    
    # 紧急任务（<3天）
    urgent_tasks = []
    normal_tasks = []
    
    for task in tasks:
        # 处理周期性任务（组会）
        if task.get('recurring') == 'weekly':
            # 找到最近的周三
            target_weekday = task.get('recurringDay', 3) - 1  # 转为0-based
            days_until_meeting = (target_weekday - today_weekday) % 7
            if days_until_meeting == 0:
                # 今天就是周三
                message += f"🔴 **今天 13:00 组会！**\n"
            else:
                normal_tasks.append({
                    'name': task['name'],
                    'countdown': f"📅 还有{days_until_meeting}天",
                    'is_meeting': True
                })
            continue
        
        # 计算剩余天数
        days = days_until(task['deadline'])
        countdown = format_countdown(days)
        
        task_info = {
            'name': task['name'],
            'countdown': countdown,
            'days': days,
            'notes': task.get('notes', '')
        }
        
        if days <= 3:
            urgent_tasks.append(task_info)
        else:
            normal_tasks.append(task_info)
    
    # 紧急任务优先显示
    if urgent_tasks:
        message += "🚨 **紧急任务**\n"
        for t in urgent_tasks:
            notes = f" ({t['notes']})" if t.get('notes') else ""
            message += f"  • {t['countdown']} | {t['name']}{notes}\n"
        message += "\n"
    
    # 普通任务
    if normal_tasks:
        message += "📋 **进行中**\n"
        for t in normal_tasks:
            if t.get('is_meeting'):
                message += f"  • {t['countdown']} | {t['name']}\n"
            else:
                notes = f" ({t['notes']})" if t.get('notes') else ""
                message += f"  • {t['countdown']} | {t['name']}{notes}\n"
    
    message += """
💪 新的一天，冲！
"""
    return message

if __name__ == '__main__':
    print(generate_reminder())
