#!/bin/bash
# 皮皮虾每日任务提醒脚本

WORKSPACE="/home/ubuntu/.openclaw/workspace"
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M")

# 读取任务JSON并计算剩余天数
cd "$WORKSPACE"

# 使用Node.js计算剩余天数并生成提醒消息
node << 'EOF'
const fs = require('fs');
const path = require('path');

const tasksPath = path.join(__dirname, '../tasks/daily_tasks.json');
const data = JSON.parse(fs.readFileSync(tasksPath, 'utf8'));

const today = new Date();
today.setHours(0, 0, 0, 0);

const formatDate = (date) => {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const dayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return `${m}/${d} ${dayNames[date.getDay()]}`;
};

const daysUntil = (deadline) => {
  const d = new Date(deadline);
  d.setHours(0, 0, 0, 0);
  const diff = d - today;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
};

const isWednesday = today.getDay() === 3;

let msg = `🌅 早上好大哥！\n\n📅 ${formatDate(today)} 任务概览\n━━━━━━━━━━━━━━━\n\n`;

// 紧急任务（<3天）
const urgent = data.tasks.filter(t => daysUntil(t.deadline) <= 3 && daysUntil(t.deadline) >= 0);
if (urgent.length > 0) {
  msg += `🚨 紧急任务（<3天）：\n`;
  urgent.forEach(t => {
    const days = daysUntil(t.deadline);
    const daysText = days === 0 ? '今天截止！' : `剩 ${days} 天`;
    msg += `• ${t.name} - ${daysText}\n`;
  });
  msg += `\n`;
}

// 其他进行中的任务
const others = data.tasks.filter(t => daysUntil(t.deadline) > 3);
if (others.length > 0) {
  msg += `📋 进行中的任务：\n`;
  others.slice(0, 3).forEach(t => {
    const days = daysUntil(t.deadline);
    msg += `• ${t.name} - 剩 ${days} 天\n`;
  });
  msg += `\n`;
}

// 周三组会提醒
if (isWednesday) {
  msg += `⚡ 今天13:00组会，别忘了！\n\n`;
}

msg += `━━━━━━━━━━━━━━━\n💪 今天也是充满活力的一天！`;

console.log(msg);
EOF
