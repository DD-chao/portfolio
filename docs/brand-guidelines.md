# Brand Guidelines v1.0 — Chaoran Deng 作品集

## Quick Reference
- **Primary Color:** #1a365d (深蓝)
- **Accent Color:** #2b6cb0 (中蓝)
- **Warm Accent:** #c05621 (暖橙)
- **Primary Font:** Inter, system-ui, sans-serif
- **Voice:** 专业、清晰、真诚

## 1. Color Palette

### Primary Colors
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Navy 900 | #1a365d | rgb(26,54,93) | 主品牌色，标题，Hero 背景 |
| Navy 700 | #2b6cb0 | rgb(43,108,176) | 链接，CTA 按钮，强调元素 |
| Navy 500 | #4299e1 | rgb(66,153,225) | 次要强调，图表辅助色 |

### Warm Accent
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Orange 700 | #c05621 | rgb(192,86,33) | 高亮标签，数据亮点，关键数字 |
| Orange 500 | #ed8936 | rgb(237,137,54) | 图表暖色，图示元素 |
| Orange 100 | #ffedd5 | rgb(255,237,213) | 暖色背景强调 |

### Neutral Palette
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| White | #ffffff | rgb(255,255,255) | 卡片背景，内容区背景 |
| Gray 50 | #f7fafc | rgb(247,250,252) | 页面背景 |
| Gray 100 | #edf2f7 | rgb(237,242,247) | 分区背景，次要卡片 |
| Gray 200 | #e2e8f0 | rgb(226,232,240) | 边框，分割线 |
| Gray 700 | #4a5568 | rgb(74,85,104) | 正文文字 |
| Gray 900 | #1a202c | rgb(26,32,44) | 标题文字 |

### Accessibility
- 正文/背景对比度: 7.2:1 (WCAG AAA)
- CTA 按钮对比度: 5.4:1 (WCAG AA)
- 所有交互元素满足 WCAG 2.1 AA

## 2. Typography

### Font Stack
```css
--font-heading: 'Inter', system-ui, -apple-system, sans-serif;
--font-body: 'Inter', system-ui, -apple-system, sans-serif;
--font-mono: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
```

### Type Scale
| Element | Font | Weight | Size (Desktop/Mobile) | Line Height |
|---------|------|--------|----------------------|-------------|
| H1 | Inter | 700 | 48px / 32px | 1.15 |
| H2 | Inter | 700 | 36px / 28px | 1.2 |
| H3 | Inter | 600 | 24px / 20px | 1.3 |
| H4 | Inter | 600 | 20px / 18px | 1.35 |
| Body | Inter | 400 | 18px / 16px | 1.7 |
| Small | Inter | 400 | 14px / 14px | 1.6 |
| Caption | Inter | 400 | 12px / 12px | 1.5 |

## 3. Voice & Tone

### Brand Personality
- **专业 (Professional)**: 基于数据和证据，用学术严谨性说话
- **清晰 (Clear)**: 复杂概念用简洁语言表达，中英术语兼顾
- **真诚 (Authentic)**: 展现真实的研究过程和思考，不夸大

### Voice Chart
| Trait | We Are | We Are Not |
|-------|--------|------------|
| 专业 | 引用数据和研究支撑观点 | 堆砌术语让人困惑 |
| 清晰 | 一句话讲清楚做了什么和为什么重要 | 模糊笼统的描述 |
| 真诚 | 呈现研究局限和反思 | 吹嘘或隐瞒不足 |

### Tone by Context
| Context | Tone | Example |
|---------|------|---------|
| 项目介绍 | 清晰自信 | "本研究发现了舒适-风险错配现象..." |
| 个人介绍 | 真诚谦逊 | "我从用户研究中体会到..." |
| 数据展示 | 客观专业 | "RF 模型的 AUC 达到 0.696..." |
| CTA | 温和邀请 | "查看完整论文 →" |
