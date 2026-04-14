#!/usr/bin/env node
/**
 * 皮皮虾备份完成通知
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

// 生成随机ID
function generateId() {
  return 'openclaw-weixin-' + crypto.randomBytes(8).toString('hex');
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
      message_type: 2,
      message_state: 2,
      item_list: [{ type: 1, text_item: { text } }],
      context_token: undefined
    },
    base_info: { channel_version: "2.1.8" }
  };

  const url = config.baseUrl + '/ilink/bot/sendmessage';

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

    console.log('✅ 备份通知发送成功!');
    return true;
  } catch (error) {
    console.error('❌ 备份通知发送失败:', error.message);
    return false;
  }
}

// 主函数
async function main() {
  try {
    const TARGET_USER_ID = 'o9cq806kOSemtC80YryA6r-eQ7fU@im.wechat';
    
    const now = new Date();
    const time = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    
    const message = `✅ 皮皮虾备份完成！\n\n⏰ 时间: ${time}\n📦 已自动提交并推送到 GitHub\n\n💪 放心，数据安全！`;

    console.log('发送备份通知...');
    const success = await sendMessage(TARGET_USER_ID, message);

    process.exit(success ? 0 : 1);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
