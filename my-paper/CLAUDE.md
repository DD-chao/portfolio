# 办公椅人机工效优化论文项目

## 项目信息
- **笔名**: Chaoran Deng
- **论文题目**: A data-driven decision-support framework for office chair adjustment and design: from global risk control to local comfort optimization
  - 数据驱动的办公椅调节与设计决策支持框架：从全局风险控制到局部舒适优化
- **学科方向**: 人机工效学 (Ergonomics) / 机器学习 (Machine Learning)
- **目标期刊**: International Journal of Human-Computer Interaction (IJHCI) — 已投稿，等待编辑答复
- **作者单位**: 南昌大学建筑与设计学院
- **通讯作者**: qiruiwen@ncu.edu.cn

## 研究方法概览

### Phase 1 — 数据采集与处理
- 100 名受试者（41M/59F）× 2 种条件（自主调节 / 受控扰动）= 200 个试验样本，质控后 190 个有效样本
- 侧视照片 → MATLAB 人工标注 9 个人体关键点 → 几何计算 5 个关节角度
  - 关键点: 眼角、耳屏、肩峰、手肘、手腕、手掌、大转子、膝盖、脚踝
  - 角度: 颈部前屈、躯干前倾、上臂前屈、肘关节角、膝关节角
- RULA 分数按严格标准由关节角度查表计算
- 主观舒适度评分 (Likert 1–9)

### Phase 2 — 两阶段 RF 代理模型
- **Stage 1**: [6 人体特征 + 6 座椅参数] → 预测 5 个关节角度
- **Stage 2**: [12 原始特征 + 5 预测角度] → 分类 P(RULA ≤ 3) 和 P(Comfort ≥ 7)
- 人体特征: Gender, Stature, Weight, Sitting Height, Popliteal Height, Buttock-Popliteal Length
- 座椅参数: Seat Height, Seat Depth, Backrest Angle, Armrest Height, Lumbar Height, Headrest Height
- 超参数: Random Search + subject-grouped CV 调优
- 对比基线: Logistic Regression + Pose, SVM + Pose

### Phase 3 — 验证
- Tuned OOF subject-grouped CV (模型比较用)
- Nested subject-grouped CV + 95% CI (泛化估计)
- 概率校准: Brier Score + Reliability Diagram

### Phase 4 — NSGA-II 多目标优化
- 策略: Global risk control → local comfort optimization（先全局控风险，再局部优舒适）
- 目标: max P(RULA ≤ 3) subject to P(Comfort ≥ 7) ≥ 0.80
- 示例目标用户: Male, 175cm, 70kg
- 设计变量边界 (Table 3): Seat Ht [42–50], Seat Dp [47.5–53.5], Back Angle [95–140], Arm Ht [17–23], Lumbar Ht [13–18], Head Ht [55–69]

### Phase 5 — JACK 仿真验证（计划中）
- L4/L5 椎间盘压缩力对比
- 关节力矩对比

## 关键数据文件
| 文件 | 说明 |
|------|------|
| `data/shuju.xlsx` | 主数据集（所有特征+标签） |
| `data/RULA_Data_Final_Perfect.xlsx` | 最终 RULA 评分 |
| `data/舒适度评分数据.xlsx` | 舒适度主观评分 |
| `data/*.jpg` (1–190) | 实验侧视照片（原始 + _Marked 标注版） |
| `data/nested_cv_results.csv` | 嵌套 CV 结果 |

## 核心代码 (MATLAB)
| 文件 | 功能 |
|------|------|
| `data/biaoji.m` | 人体关键点交互式标注系统 |
| `data/RULA.m` | RULA 分数计算器 |
| `data/RF_NSGA2_22Solved_Final.m` | **论文最终版完整流程**: 模型比较 + 嵌套 CV + 校准 + 优化 |
| `data/RF_NSGA2_NestedCV_CI.m` | 嵌套 CV + 95% CI（审稿人友好验证） |
| `data/evaluate_chair.m` | NSGA-II 适应度函数 |
| `data/tu.m` | 方法论流程图 (Mermaid/MATLAB 图) |

## 稿件状态
- 完整稿件: `drafts/Manuscript.docx` / `Manuscript.pdf`（约 2026-03-31)
- Cover Letter: `drafts/Cover Letter.docx`
- Highlights: `drafts/Highlights.docx`

## 写作规范
- 所有笔记、草稿使用中文撰写
- 文献引用使用 DOI 链接
- 术语首次出现时标注英文原文

## 技术环境
- MATLAB: 数据处理、机器学习建模、NSGA-II 优化
- Python 路径: `D:\Program Files\Python311\python.exe`（备用）
- 默认命令行使用 bash (Git Bash / WSL)

## 文献工作流
- 用户负责：搜索、筛选文献，提供摘要和 DOI
- AI 协助：整理文献笔记、格式检查、思路讨论
- 用户自行下载全文 PDF

## 目录说明
```
my-paper/
├── CLAUDE.md           # 项目配置（本文件）
├── outline.md          # 论文大纲（待填充）
├── notes/              # 讨论笔记、想法、会议记录
├── drafts/             # 论文草稿（Manuscript + Cover Letter + Highlights）
├── literature/         # 文献笔记和参考列表
├── figures/            # 图表文件
└── data/               # 实验照片、MATLAB 脚本、数据文件
```
