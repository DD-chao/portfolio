# 论文大纲

> 基于稿件 Manuscript.docx (2026-03-31) 反填

## 一、Introduction（引言）

**研究背景与问题**：
- 知识经济时代，办公室久坐人群扩大，约 80% 工作时间处于坐姿
- 久坐与肌肉骨骼疾病 (MSDs)、心血管疾病、糖尿病等慢性病相关
- 办公椅优化成为促进舒适与健康的关键干预手段

**研究缺口 (Research Gap)**：
- 客观生物力学改善 ≠ 主观舒适感知提升（"pain developers" 现象）
- 主观舒适与客观风险通常被当作独立终点处理，缺乏统一的量化与优化框架
- 传统姿态评估（如手工 RULA）耗时且存在评分者间差异，难以支持大样本个性化优化
- 现有 ML 研究多聚焦姿态分类/风险评分，而非通过多目标优化生成座椅参数并做生物力学验证

**核心贡献 (Contributions)**：
1. 约束决策建模：将舒适作为满意性约束 (satisficing criterion)，风险最小化为目标
2. 数据驱动参数推荐：RF 代理模型 + NSGA-II 多目标优化
3. 设计导向洞察：揭示全局结构参数 vs 局部支撑参数的不同功能角色
4. JACK 仿真验证：L4/L5 压缩力、剪切力、躯干力矩的 biomechanical validation

## 二、Literature Review（文献综述）

**2.1 椅设计中的舒适-风险错配**
- 生物力学视角：靠背角度、座深对腰椎负荷的影响
- 舒适视角：不存在单一"最优坐姿"，个体间差异大
- 核心矛盾：生物力学有利的配置 ≠ 用户感知舒适的配置

**2.2 姿态风险评估方法**
- RULA: 快速上肢评估，广泛应用于办公/工业场景
- OWAS, REBA: 替代评估工具
- 计算机视觉 + ML 自动化评估：减少人工评分变异性

**2.3 多目标优化在人机工效中的应用**
- NSGA-II: 快速非支配排序 + 精英策略 + 拥挤度距离
- 装配线平衡中的 REBA 约束优化
- 代理模型 (surrogate model) 在参数空间探索中的作用

## 三、Method（研究方法）

**3.1 总体框架**
- Phase 1: 数据采集 → Phase 2: 代理建模 → Phase 3: 多目标优化 → Phase 4: JACK 仿真验证

**3.2 两阶段 RF 代理模型**
- Stage 1: [6 人体 + 6 座椅] → 5 个姿态角度
- Stage 2: [12 原始特征 + 5 预测姿态] → P(RULA ≤ 3) 和 P(Comfort ≥ 7)
- Z-score 标准化，训练集参数复用于优化阶段
- Nested subject-grouped CV：外圈估计泛化性能，内圈调超参

**3.3 NSGA-II 多目标优化**
- Comfort-satisficing, health-first 策略
- 目标: max P(RULA ≤ 3) s.t. P(Comfort ≥ 7) ≥ 0.80
- 约束违反惩罚函数
- 种群 150，80 代

## 四、Experiment and Results（实验与结果）

**4.1 实验设计**
- 100 名健康成年人 (41M/59F)，年龄 20–50
- 南昌大学伦理委员会批准
- 两个阶段：(1) 自主调节 → (2) 受控扰动扩展设计空间覆盖
- 200 样本采集，190 有效样本

**4.2 数据分析**
- 人体测量特征描述统计 (Table 4)
- RULA 分数集中于 4 分左右（典型办公坐姿处于需干预区间）
- 舒适度集中于 7–9 分高位 → 舒适-风险错配证据

**4.3 代理模型性能**
- RF > LogReg > SVM（subject-grouped OOF）
- Nested CV 泛化估计 (Table 5):
  - Risk AUC: 0.696 [0.623, 0.769]
  - Comfort AUC: 0.668 [0.491, 0.845]（跨被试变异大）
- 特征重要性 (Fig. 6):
  - 舒适驱动因素: 头枕高度、扶手高度（局部支撑）
  - 风险驱动因素: 座高、靠背角度（全局结构）

**4.4 优化结果**
- 目标用户: Male, 175cm, 70kg
- 推荐解: P(LowRisk)=0.8+, P(HighComfort)≥0.80
- vs 数据集均值对比 (Table 7)：座高降低、头枕降低、靠背角度略增

**4.5 JACK 仿真验证 (Table 8)**
- L4/L5 压缩: -6.6%
- L4/L5 前后剪切: -39.6%
- 躯干屈曲力矩: -13.1%

## 五、Discussion（讨论）

- 舒适-风险错配的机制解释：局部 vs 全局参数的不同感知灵敏度
- 用户对靠背角度等结构性参数变化不敏感 → 潜在风险
- 约束决策建模 vs 传统单目标优化的优势
- 设计策略建议：先定全局结构参数控风险，再用局部支撑参数调舒适
- JACK 仿真一致性地支持优化方向

## 六、Conclusions（结论）

- 提出并验证了 RF → NSGA-II → JACK 闭环流程
- 全局-局部参数差异化设计策略
- 框架可推广至其他 bounded design space 的人机工效决策问题
- 局限：短期坐姿、准静态仿真、样本设计空间约束
- 未来方向：更大样本/更广人群、动态任务 + EMG、实际办公环境用户研究

---

## 关键参数速查

| 参数 | 范围 | 单位 |
|------|------|------|
| Seat Height | 42.0 – 50.0 | cm |
| Seat Depth | 47.5 – 53.5 | cm |
| Backrest Angle | 95.0 – 140.0 | ° |
| Armrest Height | 17.0 – 23.0 | cm |
| Lumbar Height | 13.0 – 18.0 | cm |
| Headrest Height | 55.0 – 69.0 | cm |

## 核心参考文献
- RULA: McAtamney & Corlett (1993)
- Random Forest: Breiman (2001)
- NSGA-II: Deb et al. (2002)
- Comfort-Risk mismatch: Helander (2010); De Carvalho & Callaghan (2022)
- JACK simulation: Siemens JACK ForceSolver
