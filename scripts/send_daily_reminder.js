#!/usr/bin/env node
/**
 * 皮皮虾每日任务提醒 - 微信发送脚本
 * 直接从crontab调用，不依赖Gateway
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const WEIXIN_ACCOUNT_FILE = '/home/ubuntu/.openclaw/openclaw-weixin/accounts/14b81d4c4839-im-bot.json';
const TASKS_FILE = '/home/ubuntu/.openclaw/workspace/tasks/daily_tasks.json';

// 读取微信账号配置
function loadWeixinConfig() {
  const data = JSON.parse(fs.readFileSync(WEIXIN_ACCOUNT_FILE, 'utf8'));
  return {
    token: data.token,
    baseUrl: data.baseUrl,
    botUserId: data.userId
  };
}

// 读取任务列表
function loadTasks() {
  const data = JSON.parse(fs.readFileSync(TASKS_FILE, 'utf8'));
  return data.tasks;
}

// 计算剩余天数
function daysUntil(deadline) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const d = new Date(deadline);
  d.setHours(0, 0, 0, 0);
  const diff = d - today;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

// 格式化日期
function formatDate(date) {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const dayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return `${m}/${d} ${dayNames[date.getDay()]}`;
}

// 生成随机ID
function generateId() {
  return 'openclaw-weixin-' + crypto.randomBytes(8).toString('hex');
}

// 生成提醒消息
function buildMessage() {
  const tasks = loadTasks();
  const today = new Date();
  const isWednesday = today.getDay() === 3;

  let msg = `🌅 早上好大哥！\n\n📅 ${formatDate(today)} 任务概览\n━━━━━━━━━━━━━━━\n\n`;

  // 紧急任务（<3天）
  const urgent = tasks.filter(t => daysUntil(t.deadline) <= 3 && daysUntil(t.deadline) >= 0);
  if (urgent.length > 0) {
    msg += `🚨 紧急任务（<3天）：\n`;
    urgent.forEach(t => {
      const days = daysUntil(t.deadline);
      const daysText = days === 0 ? '今天截止！' : days === 1 ? '明天截止！' : `剩 ${days} 天`;
      msg += `• ${t.name} - ${daysText}\n`;
    });
    msg += `\n`;
  }

  // 其他进行中的任务
  const others = tasks.filter(t => daysUntil(t.deadline) > 3);
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

  return msg;
}

// 发送微信消息
async function sendMessage(to, text) {
  const config = loadWeixinConfig();
  const clientId = generateId();

  const payload = {
    msg: {
      from_user_id: "",
      to_user_id: to,
      client_id: clientId,
      message_type: 2, // BOT message
      message_state: 2, // FINISH
      item_list: [{ type: 1, text_item: { text } }], // TEXT type
      context_token: undefined
    },
    base_info: { channel_version: "2.1.8" }
  };

  const url = config.baseUrl + '/ilink/bot/sendmessage';

  // 随机生成X-WECHAT-UIN
  const uint32 = crypto.randomBytes(4).readUInt32BE(0);
  const xWechatUin = Buffer.from(String(uint32), 'utf-8').toString('base64');

  const headers = {
    'Content-Type': 'application/json',
    'AuthorizationType': 'ilink_bot_token',
    'Authorization': `Bearer ${config.token}`,
    'X-WECHAT-UIN': xWechatUin,
    'iLink-App-Id': '',
    'iLink-App-ClientVersion': '131337'
  };

  console.log(`Sending message to ${to}...`);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(payload)
    });

    const responseText = await response.text();

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${responseText}`);
    }

    console.log('Message sent successfully!');
    console.log('Response:', responseText);
    return true;
  } catch (error) {
    console.error('Failed to send message:', error.message);
    return false;
  }
}

// 主函数
async function main() {
  try {
    // 大哥的微信ID (从session记录中获取)
    const TARGET_USER_ID = 'o9cq806kOSemtC80YryA6r-eQ7fU@im.wechat';

    console.log('皮皮虾每日提醒 -', new Date().toISOString());
    console.log('================================');

    const message = buildMessage();
    console.log('\n消息内容:');
    console.log(message);
    console.log('\n================================');

    const success = await sendMessage(TARGET_USER_ID, message);

    if (success) {
      console.log('\n✅ 提醒发送成功！');
      process.exit(0);
    } else {
      console.error('\n❌ 提醒发送失败');
      process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
