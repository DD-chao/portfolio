# 学术助手 — 项目架构

## 项目定位

面向工业设计/人因工程领域的学术文献研究工具。从零演进而来：理论学习 → Dify 原型 → 独立 Agent 系统。

## 架构全景

```
用户
 │
 ├── python search.py "关键词"        ──→ 单步搜索（本地 + 外部）
 ├── python research.py "研究方向"    ──→ Multi-Agent 流水线  ─┐
 │                                                              │
 ▼                                                              ▼
╔══════════════════════════════════════════════════════════════════╗
║                        Multi-Agent 流水线                       ║
║                                                                ║
║  ┌──────────┐    ┌──────────┐    ┌──────────┐                 ║
║  │ 搜索Agent │───→│ 筛选Agent │───→│ 提炼Agent │───→ JSON输出   ║
║  └──────────┘    └──────────┘    └──────────┘                 ║
║       │               │               │                       ║
║   只做搜索         只做筛选         只做翻译提炼                ║
║   不关心相关性     不关心翻译质量   不关心搜索源                ║
╚══════════════════════════════════════════════════════════════════╝
                              ↑
                    ┌─────────┴─────────┐
                    │     数据来源       │
                    ├───────────────────┤
                    │ ChromaDB 本地向量库│── 630篇PDF，BGE-M3向量化
                    │ SearXNG 外部搜索   │── OpenAlex PubMed Arxiv
                    │                   │   SemanticScholar Crossref
                    └───────────────────┘
```

## 目录结构

```
D:/agent-learning/
│
├── ARCHITECTURE.md          ← 本文件
├── 00-目录.md ~ 04-高阶模式.md  ← 理论学习笔记
│
├── academic/                ← 核心模块（可导入复用）
│   ├── config.py               配置：路径、API 端点、模型
│   ├── indexer.py              PDF → 分块 → BGE-M3向量 → ChromaDB
│   ├── searcher.py             搜索：本地向量库 + SearXNG 外部
│   ├── agents.py               Multi-Agent：Search/Filter/Extract
│   └── cli.py                  命令行入口
│
├── search.py                ← 单步搜索 python search.py "xx"
├── research.py              ← Multi-Agent调研 python research.py "xx"
├── agent_cli.py             ← Dify Agent 远程调用（保留可用）
├── run_agent.bat            ← Dify Agent 交互入口（备用）
│
├── searxng/                 ← SearXNG 搜索引擎（Docker）
│   ├── docker-compose.yml
│   ├── settings.yml
│   └── limiter.toml
│
├── .siliconflow_key         ← API Key（本地文件，勿提交 Git）
└── .conversation_id         ← Dify 会话 ID（保留）
```

## 组件详解

### 1. 数据层：indexer.py + ChromaDB

```
PDF文件 → PyMuPDF读取 → 分块(1000字/块，200字重叠)
       → SiliconFlow BGE-M3 → 1024维向量 → ChromaDB持久化
```

**关键参数**（config.py）：
- CHUNK_SIZE = 1000  → 每块字符数。越小越精细但索引越大
- CHUNK_OVERLAP = 200 → 块之间重叠字数，防止语义被切断
- Embedding: BAAI/bge-m3 → 中英跨语言，1024维

**怎么改**：
- 加新 PDF 源 → 改 config.py 的 LITERATURE_DIR
- 调搜索精度 → 改 CHUNK_SIZE（500 更精细，2000 更快）
- 换 Embedding 模型 → 改 config.py 的 EMBEDDING_MODEL

### 2. 搜索层：searcher.py

```
search_local()  → ChromaDB.query() → 按余弦距离排序
search_external() → SearXNG API → 5 个学术引擎聚合
                    ↑ 中文自动翻译为英文关键词
search_all()   → 合并两路结果
```

**关键设计**：
- `_to_english()`: 检测含中文 → 调 DeepSeek-V3 翻译 → 英文搜外部引擎
- 外部结果字段标准化：title, abstract, journal, year, authors, doi, pdf_url

**怎么改**：
- 调整外部搜索引擎 → 改 config.py 的 SEARXNG_ENGINES
- 不加外部搜索 → search_all() 里不调 search_external()
- 调 K 值 → search.py 或 research.py 调用时传参数

### 3. Agent 层：agents.py

每个 Agent = 一个 Python 类，只有一个 public 方法 `.run()`

#### Agent 1: SearchAgent
```
输入: "用户问题"（中文或英文）
行为: 调用 search_local + search_external
输出: {"query": "...", "local": [...], "external": [...], ...}
职责: 只搜，不筛选
```

#### Agent 2: FilterAgent
```
输入: SearchAgent 输出
行为: 调 DeepSeek-V3，去重 + 相关性打分（0-1）+ 保留 ≥0.6
输出: {"papers": [...], "kept": 8, "discarded_reason": "..."}
职责: 只筛选，不翻译
System Prompt: 定位为"论文评审人"，只输出 JSON
```

#### Agent 3: ExtractAgent
```
输入: FilterAgent 输出的论文列表
行为: 调 DeepSeek-V3，翻译标题+摘要 + 提取 3-5 条核心要点
输出: {"papers": [{"title_cn":..., "abstract_cn":..., "key_points":[...]}]}
职责: 只翻译提炼，不关心搜索源
System Prompt: 定位为"翻译与提炼专家"，术语首次标注英文
```

#### MultiAgentPipeline（编排器）
```
搜索Agent.run() → 筛选Agent.run() → 提炼Agent.run() → 返回
```
每个环节的输出是下一个环节的输入，数据类型逐层收窄。

**怎么改**：
- 调整筛选阈值 → FilterAgent.SYSTEM 中改 `>= 0.6`
- 调整保留数量 → FilterAgent.SYSTEM 中改 `最多返回 8 篇`
- 调整 key_points 字数 → ExtractAgent.SYSTEM 中改 `50-100字`
- 加新 Agent → 在 agents.py 新增类，在 Pipeline 里插入
- 换 LLM → 改 agents.py 的 MODEL 变量

### 4. 通信协议

Agent 之间不传自然语言闲聊，传结构化 JSON：

```
SearchAgent 输出              FilterAgent 解析              ExtractAgent 输入
{                             {                             {
  "local": [                    "papers": [                   "papers": [
    {"title": "...",              {"title": "原英文标题",       {"title": "...",
     "snippet": "..."}             "abstract": "摘要片段",       "abstract": "摘要片段",
  ],                               "relevance": 0.9,           "relevance": 0.9}
  "external": [...]               "reason": "..."}           ],
}                               ],                          }
                                "kept": 8
                              }
```

## 数据流对比

### 单步搜索（search.py）
```
用户提问 → search_all() → 打印结果
```
适用：快速查找、验证是否有相关文献、非结构化浏览

### Multi-Agent 研究（research.py）
```
用户提问 → SearchAgent → FilterAgent → ExtractAgent → 格式化输出
              ↓ 23篇       ↓ 8篇          ↓ JSON
```
适用：正式文献调研、需要翻译提炼、可复现的批处理

## 外部依赖

| 组件 | 用途 | 运行位置 |
|------|------|----------|
| SiliconFlow API | BGE-M3 Embedding + DeepSeek-V3 LLM | 云端 API |
| SearXNG (Docker) | 聚合学数引擎搜索 | 本机 localhost:8080 |
| ChromaDB | 本地向量存储 | 本机 D:/agent-learning/academic/chroma_db/ |
| PyMuPDF | PDF 文本提取 | Python 库 |

## 性能参考

| 操作 | 耗时 | 备注 |
|------|------|------|
| 索引 1 篇 PDF | ~5-15秒 | 取决于 PDF 长度 |
| 单步搜索 search.py | ~5-10秒 | 本地 + 外部并行 |
| Multi-Agent 调研 23篇 | ~30-60秒 | 搜索+筛选+翻译三次 LLM 调用 |

## 版本历史

| 阶段 | 交付物 | 学到什么 |
|------|--------|----------|
| 理论学习 | 00-04 笔记 | Agent 概念 |
| Dify 单轮 | 翻译 Agent | System Prompt 设计 |
| Dify+工具 | SearXNG 集成 | 工具调用机制 |
| Dify+知识库 | 15→191 篇 PDF | RAG、Embedding、跨语言 |
| Dify Workflow | 搜索→翻译链 | 节点、变量传递、诊断 |
| Dify Memory | 对话变量 | 跨轮上下文 |
| 本地化 | 删 Dify，用 Python 重写 | 自主可控 |
| Multi-Agent | 搜索→筛选→提炼 | Agent 分工、结构化通信 |
