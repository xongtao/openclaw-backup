#!/usr/bin/env python3
"""
ProteinAE PPT 制作 - 修复版
直接修改XML确保内容写入
"""

import xml.etree.ElementTree as ET
import shutil
import zipfile
import os
import re

# 命名空间
namespaces = {
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'p': 'http://schemas.openxmlformats.org/presentationml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

# 为每个命名空间注册前缀
for prefix, uri in namespaces.items():
    ET.register_namespace(prefix, uri)

# 幻灯片内容
slides_data = [
    # 第1页: 标题
    {
        'title': 'ProteinAE: Protein Diffusion Autoencoders for Structure Encoding',
        'content': '蛋白质扩散自编码器用于结构编码\n\n作者: Shaoning Li, Le Zhuo, Yusong Wang, et al.\n单位: CUHK, ZGCAcademy, KreaAI, XJTU, SJTU, LingangLab, Tencent\n发表: arXiv 2025\n代码: https://github.com/OnlyLoveKFC/ProteinAE'
    },
    # 第2页: 目录
    {
        'title': '汇报大纲',
        'content': '1. 研究背景与动机\n2. ProteinAE 核心创新\n3. 模型架构详解\n4. 实验结果分析\n5. 与相关工作对比\n6. 结论与展望'
    },
    # 第3页: 背景
    {
        'title': '研究背景：蛋白质结构表示学习',
        'content': '''蛋白质科学的核心问题：
• 如何有效学习蛋白质结构的表示？
• 如何支持蛋白质生成建模？

现有方法面临的挑战：
  - SE(3)流形的复杂性
  - 依赖离散化tokenization
  - 多个训练目标（FAPE, distance, violation, KL loss）
  - 固定输入长度，缺乏紧凑潜在空间

核心问题：
  能否设计更简单、准确、有效的连续潜在空间自编码器？'''
    },
    # 第4页: 创新
    {
        'title': 'ProteinAE：核心设计理念',
        'content': '''【直接映射】
• 蛋白质骨架坐标从 E(3) → 连续紧凑潜在空间

【简化架构】
• 非等变 Diffusion Transformer (DiT)
• Bottleneck 设计实现高效压缩

【统一目标】
• 单一 Flow Matching 目标函数
• 端到端训练，简化优化流程

【灵活高效】
• 支持可变长度蛋白质（RoPE位置编码）
• 潜在空间支持高效生成（PLDM）'''
    },
    # 第5页: 对比
    {
        'title': '与传统方法的对比',
        'content': '''ESM3 Structure Autoencoder:
• 操作空间: SE(3)
• 编码方式: 离散（VQ-VAE）
• 架构: Standard VQ-VAE
• 训练目标: Multiple losses

ProteinAE (本文):
• 操作空间: E(3)
• 编码方式: 连续
• 架构: Diffusion Autoencoder
• 训练目标: Single flow matching

优势: 简化、高效、SOTA性能'''
    },
    # 第6页: Encoder
    {
        'title': 'Encoder：结构编码器',
        'content': '''输入: 蛋白质骨架原子坐标 (Cα, N, C, O)

处理流程:
1. All-Atom Attention Encoder
   - 处理所有主链原子
   - 输出序列表示 s，配对表示 p
   - Skip connections

2. Length & Dimension Downsampling
   - Conv1d 进行长度下采样
   - Linear 维度压缩: D=256 → d=8

3. LayerNorm
   - 替代传统VAE的KL正则化
   - 无需权重调优，性能更优'''
    },
    # 第7页: Decoder
    {
        'title': 'Decoder：结构解码器',
        'content': '''基于 Flow Matching 的解码:

输入: 潜在表示 z (B×N×d)

处理流程:
1. Upsampling
   - 维度扩展: d → D
   - 长度插值: N_down → N_target

2. DiT Decoder
   - 5层 Diffusion Transformer
   - 注意力偏置编码几何关系
   - RoPE位置编码

3. Flow Prediction
   - 预测速度场 v_θ
   - 重建原子坐标'''
    },
    # 第8页: All-Atom Attention
    {
        'title': '关键技术：All-Atom Attention',
        'content': '''设计动机:
• 传统方法：仅使用 Cα 原子
• ProteinAE：使用所有主链原子
• 更完整的结构信息

技术细节:
• 非等变架构（non-equivariant）
• 借鉴 AlphaFold3 和 Proteina
• 条件化多头自注意力 + 过渡块
• 注意力偏置编码几何关系

优势:
• 直接学习原子间相互作用
• 更准确的几何表示'''
    },
    # 第9页: Bottleneck
    {
        'title': 'Bottleneck：紧凑潜在空间',
        'content': '''维度压缩:
• 输入维度: D = 256
• 潜在维度: d = 8
• 压缩比: 32×

长度处理:
• 长度下采样比: r = 1
• 可选: r = 2, 4

正则化:
• 传统VAE: KL divergence loss
• ProteinAE: LayerNorm（无学习参数）
• 优势: 无需调参，重建质量更高

应用:
• 下游生成任务（PLDM）
• 理化性质预测'''
    },
    # 第10页: 实验设置
    {
        'title': '实验设置',
        'content': '''数据集:
• 训练: AFDB-FS（588,318个结构）
• 长度范围: 32-256 residues
• 测试: CASP14, CASP15
• 下游: ATLAS分子动力学数据集

模型配置:
• Encoder/Decoder: L=5层, D=256
• Bottleneck: d=8, r=1
• PLDM: 200M参数, L=15, D=768

训练细节:
• 数据增强: 随机全局旋转
• 位置编码: RoPE
• 优化器: AdamW'''
    },
    # 第11页: 重建结果
    {
        'title': '实验结果：结构重建（SOTA）',
        'content': '''评估指标: RMSD（越低越好）

CASP14 结果:
• ProteinAE: 0.89 Å
• ESM3 VQ-VAE: 1.23 Å
• 提升: 27.6%

CASP15 结果:
• ProteinAE: 0.95 Å
• ESM3 VQ-VAE: 1.31 Å
• 提升: 27.5%

结论:
• 达到SOTA重建质量
• 连续编码优于离散编码
• E(3)空间优于SE(3)空间'''
    },
    # 第12页: 生成结果
    {
        'title': '实验结果：蛋白质生成',
        'content': '''Protein Latent Diffusion Model (PLDM):
• 在ProteinAE潜在空间上训练
• 200M参数，无需显式等变约束

性能对比（Designability/Diversity）:
• ProteinAE-PLDM: 0.89/0.82
• Latent-based基线: ~0.65/~0.70
• Structure-based SDMs: ~0.90/~0.80

关键发现:
• 显著优于先前潜在方法
• 匹敌经典结构扩散模型
• 缩小了潜在vs结构方法的性能差距'''
    },
    # 第13页: 下游任务
    {
        'title': '下游任务：理化性质预测',
        'content': '''潜在空间的应用:

蛋白质柔性预测（ATLAS数据集）:
• 输入: ProteinAE latent z
• 预测: RMSF（原子位置波动）
• 结果: 优于ESM2等序列方法

优势:
• 结构感知表示
• 紧凑高效（d=8）
• 可直接用于分类/回归任务

其他潜在应用:
• 蛋白质功能预测
• 蛋白质-配体相互作用
• 突变效应预测'''
    },
    # 第14页: 消融实验
    {
        'title': '消融实验：关键组件分析',
        'content': '''Bottleneck维度 d:
• d=4: RMSD = 1.12 Å
• d=8: RMSD = 0.89 Å（最佳平衡）
• d=16: RMSD = 0.85 Å

正则化方法:
• KL Regularization: 1.05 Å
• LayerNorm: 0.89 Å ✓

位置编码:
• Absolute PE: 可变长度处理困难
• RoPE: 支持任意长度 ✓

结论: d=8 + LayerNorm + RoPE 是最佳配置'''
    },
    # 第15页: 相关工作
    {
        'title': '与相关工作的详细对比',
        'content': '''vs. AlphaFold3:
• 相似: 非等变注意力架构
• 不同: AF3用于预测，ProteinAE用于编码/生成

vs. ESM3:
• ESM3: SE(3) + VQ-VAE + 多目标
• ProteinAE: E(3) + 连续 + 单目标

vs. RFdiffusion / Chroma:
• RFdiffusion: 结构空间扩散
• ProteinAE: 潜在空间扩散（更高效）'''
    },
    # 第16页: 创新点
    {
        'title': '论文主要创新点',
        'content': '''1. 简化架构设计:
   • 非等变DiT，单一flow matching目标
   • 避免复杂的SE(3)流形处理

2. 连续潜在空间:
   • E(3)空间直接编码
   • LayerNorm替代KL正则化

3. SOTA性能:
   • 重建质量超越现有自编码器
   • 生成质量匹敌结构扩散模型

4. 高效实用:
   • 紧凑表示（d=8）
   • 支持可变长度
   • 易于扩展到下游任务'''
    },
    # 第17页: 局限性
    {
        'title': '局限性与未来方向',
        'content': '''当前局限:
• 仅支持单链蛋白质
• 长度限制（32-256 residues）
• 仅编码主链原子（无侧链）

未来方向:
1. 多链蛋白质和复合物建模
2. 全原子表示（包含侧链）
3. 序列-结构联合建模
4. 条件生成（功能、稳定性等）
5. 更大规模预训练
6. 实时蛋白质设计应用'''
    },
    # 第18页: 结论
    {
        'title': '结论',
        'content': '''ProteinAE 的核心贡献:

✓ 提出了简化的蛋白质扩散自编码器
   - 直接E(3)空间映射
   - 连续紧凑潜在空间

✓ 实现了SOTA结构重建
   - 超越ESM3等现有方法
   - 单一流匹配目标

✓ 支持高效蛋白质生成
   - PLDM达到结构扩散模型水平
   - 缩小潜在方法与结构方法的差距

代码开源: https://github.com/OnlyLoveKFC/ProteinAE'''
    },
    # 第19页: Q&A
    {
        'title': 'Q & A',
        'content': '''感谢聆听！

欢迎提问和讨论

联系方式:
• 论文: arXiv:2510.10634
• 代码: github.com/OnlyLoveKFC/ProteinAE

相关推荐:
• AlphaFold3 (Nature 2024)
• ESM3 (Science 2024)
• RFdiffusion (Nature 2023)
• Flow Matching (ICML 2022)'''
    },
    # 第20页: 备用
    {
        'title': '补充材料',
        'content': '''附录内容：

• 网络架构详细配置
• 训练超参数
• 更多实验结果
• 可视化案例

请参考论文原文和补充材料
https://arxiv.org/abs/2510.10634'''
    }
]

def update_slide_xml(slide_path, title_text, content_text):
    """更新幻灯片XML中的文本内容"""
    
    with open(slide_path, 'r', encoding='utf-8') as f:
        xml_content = f.read()
    
    # 查找所有文本元素
    # PPTX中常见的文本元素模式
    
    # 首先尝试找标题 - 通常是第一个较大的文本框
    # 替换 <a:t>文本</a:t> 中的内容
    
    # 简单策略：按顺序替换文本元素
    # 第一个通常是标题，后面的可能是内容
    
    pattern = r'<a:t>([^<]*)</a:t>'
    matches = list(re.finditer(pattern, xml_content))
    
    if len(matches) >= 1:
        # 替换第一个为标题
        first_match = matches[0]
        xml_content = xml_content[:first_match.start()] + f'<a:t>{title_text}</a:t>' + xml_content[first_match.end():]
        
        # 如果有第二个文本框，替换为内容
        # 否则在第一个文本框后追加内容
        if len(matches) >= 2:
            # 重新查找（因为前面修改了内容）
            matches = list(re.finditer(pattern, xml_content))
            # 合并所有剩余文本框的内容
            second_match = matches[1]
            xml_content = xml_content[:second_match.start()] + f'<a:t>{content_text}</a:t>' + xml_content[second_match.end():]
            
            # 清空其他文本框
            for match in matches[2:]:
                xml_content = xml_content[:match.start()] + '<a:t></a:t>' + xml_content[match.end():]
                matches = list(re.finditer(pattern, xml_content))
    
    with open(slide_path, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    return True

def create_ppt():
    """创建PPT"""
    # 复制模板到工作目录
    template_dir = '/tmp/pptx_template'
    work_dir = '/tmp/pptx_work'
    output_path = '/data/ProteinAE_组会分享_修复版.pptx'
    
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)
    shutil.copytree(template_dir, work_dir)
    
    print(f"✓ 复制模板到工作目录")
    
    # 更新每个幻灯片
    slides_dir = os.path.join(work_dir, 'ppt/slides')
    
    for i, slide_data in enumerate(slides_data):
        slide_file = os.path.join(slides_dir, f'slide{i+1}.xml')
        if os.path.exists(slide_file):
            update_slide_xml(slide_file, slide_data['title'], slide_data['content'])
            print(f"✓ 更新第{i+1}页: {slide_data['title'][:30]}...")
        else:
            print(f"✗ 第{i+1}页不存在")
    
    # 打包成PPTX
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(work_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, work_dir)
                zipf.write(file_path, arcname)
    
    print(f"\n✅ PPT 已保存: {output_path}")
    print(f"📊 文件大小: {os.path.getsize(output_path)/(1024*1024):.2f} MB")
    
    return output_path

if __name__ == "__main__":
    print("=" * 60)
    print("🧬 ProteinAE 组会PPT 修复版")
    print("=" * 60)
    print()
    
    create_ppt()
    
    print()
    print("=" * 60)
    print("制作完成！请下载查看")
    print("=" * 60)
