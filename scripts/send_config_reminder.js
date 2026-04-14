#!/usr/bin/env node
/**
 * 皮皮虾 - 提醒配置脚本
 */

const fs = require('fs');
const crypto = require('crypto');

const WEIXIN_ACCOUNT_FILE = '/home/ubuntu/.openclaw/openclaw-weixin/accounts/14b81d4c4839-im-bot.json';

function loadWeixinConfig() {
  const data = JSON.parse(fs.readFileSync(WEIXIN_ACCOUNT_FILE, 'utf8'));
  return { token: data.token, baseUrl: data.baseUrl };
}

function generateId() {
  return 'openclaw-weixin-' + crypto.randomBytes(8).toString('hex');
}

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
    return response.ok;
  } catch (error) {
    console.error('发送失败:', error.message);
    return false;
  }
}

async function main() {
  const TARGET_USER_ID = 'o9cq806kOSemtC80YryA6r-eQ7fU@im.wechat';
  
  const message = `📢 提醒一下！

⏰ 该配置脚本啦～
之前删掉的那些定时任务还记得怎么配吗？

需要配置的：
- 论文推送（Arxiv/AlphaXiv）
- 小红书自动发布
- 租房帖子
- 评论自动回复

赶紧的，别忘了！🦐`;

  console.log('发送提醒...');
  const success = await sendMessage(TARGET_USER_ID, message);
  process.exit(success ? 0 : 1);
}

main();
