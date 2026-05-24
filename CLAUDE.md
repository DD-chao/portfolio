# 作品集项目 — 用户研究实习岗位

## 项目定位

面向用户研究实习岗位的个人作品集网站，展示学术研究能力和 Agent 开发能力。

## 作品展示顺序

1. **已发表 SCI 论文** — BioRes 期刊，基于用户需求的宿舍家具设计与评估
2. **在投 SCI 论文** — IJHCI 期刊，数据驱动的办公椅调节与设计决策支持框架
3. **Multi-Agent 学术助手** — 从零构建的 AI Agent 文献调研系统

## 目录结构

```
D:/zuopingji/
├── CLAUDE.md              # 项目配置（本文件）
├── BioRes/                # 已发表论文 + 图片素材
├── my-paper/              # 在投论文 + 文献 + 数据
├── agent-learning/        # Agent 项目源码 + 文档 + portfolio.html
├── .claude/skills/        # UI/UX 设计技能
├── .claude-plugin/        # 插件配置
└── ui-ux-pro-max-skill/   # Skill 源码（参考用）
```

## 设计系统

本项目使用三阶段设计流程：
1. **品牌建立** — 使用 brand skill 定义作品集品牌（色彩、排版、声音）
2. **设计系统** — 使用 design-system skill 建立 token 架构和组件规范
3. **页面构建** — 基于设计 tokens 构建作品集页面

### 技能清单

| Skill | 路径 | 用途 |
|-------|------|------|
| brand | `.claude/skills/brand/` | 品牌标识、配色、排版、声音 |
| design-system | `.claude/skills/design-system/` | Token 架构、组件规范、幻灯片生成 |
| banner-design | `.claude/skills/banner-design/` | 社交媒体/网站横幅设计 |

### 关键设计规范

- **Token 三层结构**: Primitive（原始值）→ Semantic（语义别名）→ Component（组件专用）
- **禁止硬编码颜色**: 所有组件必须通过 CSS 变量引用 token
- **WCAG AA 合规**: 文字对比度 ≥ 4.5:1，交互元素 ≥ 3:1
- **组件状态**: default → hover → focus → active → disabled → loading
- **响应式**: 移动端优先，使用 design tokens 统一断点

## 人员信息

- **姓名**: Chaoran Deng
- **单位**: 南昌大学建筑与设计学院
- **方向**: 工业设计 / 人机工效学 / 用户研究
- **目标岗位**: 用户研究实习
- **技能**: 用户需求调研、人因实验设计、数据分析（MATLAB/Python）、AI Agent 开发、文献系统综述
