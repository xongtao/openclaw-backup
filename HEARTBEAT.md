# HEARTBEAT.md - 定时任务配置

## 🧬 任务1：蛋白质设计论文推送（✅ 运行中）

**任务状态**: ✅ **运行中**  
**执行频率**: 每天 8:00 (北京时间)  
**目标领域**: 蛋白质设计 + 3D结构融合  
**推送内容**: 前24小时 arXiv/bioRxiv 新论文  

### 检索关键词
| 类别 | 关键词 |
|------|--------|
| 核心模型 | ESM3, KANZI, ProteinAE, SaProt, ESM-2, ESMFold |
| 3D结构融合 | structure-conditioned, geometric deep learning, GNN, equivariant |
| 离散型方法 | VQ-VAE, tokenizer, discrete diffusion, codebook |
| 连续型方法 | diffusion model, flow matching, RFdiffusion, Chroma |
| 任务类型 | protein design, inverse folding, sequence-structure co-design |

### 数据源
- arXiv (cs.LG, cs.AI, q-bio.BM, q-bio.QM)
- bioRxiv (Bioinformatics, Computational Biology)
- 检索窗口：过去24小时

### 推送格式
```
🧬 今日蛋白质设计论文 (YYYY-MM-DD)

📄 论文1: [标题]
👤 作者: [第一作者 et al.]
🏷️ 关键词: [匹配的关键词]
💡 看点: [一句话总结]
🔗 链接: [arXiv/bioRxiv URL]
---
[更多论文...]

📊 今日统计: 共 N 篇相关论文
```

**推送方式**: 微信 (WeCom)  
**接收人**: XiongTao  
**脚本**: `/root/.openclaw/workspace/paper_tracker/protein_paper_push.sh`  
**日志**: `/var/log/protein_paper.log`  

---

## 📕 任务2：租房发帖定时（⚠️ 已停止）

**任务状态**: ❌ **已停止** - cron 配置丢失  
（历史记录保留，略）

---

## 💬 任务3：南昌租房留言任务（⚠️ 已停止）

**任务状态**: ❌ **已停止** - cron 配置丢失  
（历史记录保留，略）

---

## 定时配置
```
0 8 * * * /root/.openclaw/workspace/paper_tracker/protein_paper_push.sh >> /var/log/protein_paper.log 2>&1
```

**创建时间**: 2026-03-11  
**负责人**: 皮皮虾 🦐
