"""Multi-Agent 系统：搜索 → 筛选 → 提炼，每个 Agent 职责单一，通信靠结构化数据"""

import json
import requests
from typing import Optional

API_URL = "https://api.siliconflow.cn/v1/chat/completions"
MODEL = "deepseek-ai/DeepSeek-V3"


def _call_llm(system: str, user: str, temperature: float = 0.1) -> str:
    """通用 LLM 调用"""
    from .cli import load_api_key
    key = load_api_key()
    resp = requests.post(
        API_URL,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={
            "model": MODEL,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": temperature,
            "max_tokens": 3000,
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"]


# ============================================================
# Agent 1: 搜索 Agent
# ============================================================
class SearchAgent:
    """负责搜索：本地向量库 + 外部 SearXNG"""

    def run(self, query: str) -> dict:
        from .searcher import search_local, search_external
        from .cli import load_api_key
        key = load_api_key()

        local = search_local(query, key, top_k=10)
        external = search_external(query, max_results=15, api_key=key)

        return {
            "query": query,
            "local": [{"title": p["filename"], "snippet": p["snippet"][:500], "score": p["score"]}
                       for p in local],
            "external": [{"title": p["title"], "abstract": p.get("abstract", "")[:500],
                           "journal": p.get("journal", ""), "year": p.get("year", ""),
                           "authors": p.get("authors", [])}
                          for p in external],
            "local_count": len(local),
            "external_count": len(external),
        }


# ============================================================
# Agent 2: 筛选 Agent
# ============================================================
class FilterAgent:
    """负责筛选：去重 + 相关性打分 + 保留最相关的"""

    SYSTEM = """你是工业设计/人因工程领域的学术论文评审人。

任务：根据用户的研究问题，从论文列表中筛选最相关的论文。
规则：
1. 去重（标题相似度高的只保留信息最完整的那篇）
2. 根据标题和摘要判断与问题的相关性
3. 只保留相关度 >= 0.6 的论文
4. 最多返回 8 篇
5. 直接返回 JSON，不要其他内容

返回格式：
{
  "papers": [
    {
      "title": "原标题",
      "abstract": "原始摘要",
      "journal": "期刊",
      "year": "年份",
      "authors": ["作者1", "作者2"],
      "relevance": 0.9,
      "reason": "相关性理由（一句中文）"
    }
  ],
  "total_input": 25,
  "kept": 8,
  "discarded_reason": "例如：2篇重复，15篇相关性低于阈值"
}"""

    def run(self, search_result: dict) -> dict:
        # 构建结构化的论文列表
        papers_input = []
        for p in search_result.get("local", []):
            papers_input.append({
                "source": "本地库",
                "title": p["title"],
                "abstract": p["snippet"][:400],
            })
        for p in search_result.get("external", []):
            papers_input.append({
                "source": "外部搜索",
                "title": p["title"],
                "abstract": p.get("abstract", "")[:400],
                "journal": p.get("journal", ""),
                "year": p.get("year", ""),
                "authors": p.get("authors", []),
            })

        user_msg = f"""研究问题：{search_result['query']}

论文列表（共 {len(papers_input)} 篇）：
{json.dumps(papers_input, ensure_ascii=False, indent=2)}"""

        response = _call_llm(self.SYSTEM, user_msg, temperature=0.1)
        try:
            return json.loads(self._clean(response))
        except json.JSONDecodeError:
            return {"papers": [], "total_input": len(papers_input), "kept": 0,
                    "error": "解析失败", "raw": response[:500]}

    def _clean(self, text: str) -> str:
        text = text.strip()
        if text.startswith("```"):
            lines = text.split("\n")
            lines = [l for l in lines if not l.startswith("```")]
            text = "\n".join(lines)
        return text


# ============================================================
# Agent 3: 提炼 Agent
# ============================================================
class ExtractAgent:
    """负责提炼：翻译 + 提取核心要点"""

    SYSTEM = """你是工业设计/人因工程领域的英中学术翻译与信息提炼专家。

任务：对每篇论文，翻译标题和摘要，提取3-5条核心要点。
规则：
1. 专业术语首次出现时括号标注英文原文
2. key_points 每条 50-100 字，覆盖研究问题/方法/发现/意义
3. 若摘要缺失，从标题推断，标注"（基于标题推断）"
4. 直接返回 JSON，不要其他内容

返回格式：
{
  "papers": [
    {
      "title_cn": "中文标题",
      "abstract_cn": "中文摘要（术语首次出现标注英文）",
      "key_points": ["要点1", "要点2", "要点3"]
    }
  ]
}"""

    def run(self, filter_result: dict) -> dict:
        papers = filter_result.get("papers", [])
        if not papers:
            return {"papers": [], "status": "无相关论文"}

        # 构建输入：只传必要信息
        input_data = []
        for p in papers:
            input_data.append({
                "title": p.get("title", ""),
                "abstract": p.get("abstract", "")[:600],
                "relevance": p.get("relevance", 0),
            })

        user_msg = f"需要处理的论文：\n{json.dumps(input_data, ensure_ascii=False, indent=2)}"

        response = _call_llm(self.SYSTEM, user_msg, temperature=0.2)
        try:
            return json.loads(self._clean(response))
        except json.JSONDecodeError:
            return {"papers": [], "error": "解析失败", "raw": response[:500]}

    def _clean(self, text: str) -> str:
        text = text.strip()
        if text.startswith("```"):
            lines = text.split("\n")
            lines = [l for l in lines if not l.startswith("```")]
            text = "\n".join(lines)
        return text


# ============================================================
# 编排器：串起三个 Agent
# ============================================================
class MultiAgentPipeline:
    """Multi-Agent 流水线：搜索 → 筛选 → 提炼"""

    def __init__(self):
        self.search_agent = SearchAgent()
        self.filter_agent = FilterAgent()
        self.extract_agent = ExtractAgent()

    def run(self, query: str, verbose: bool = True) -> dict:
        if verbose:
            print(f"🔍 [搜索Agent] 正在搜索: {query}")

        # Step 1: 搜索
        search_result = self.search_agent.run(query)
        total = search_result["local_count"] + search_result["external_count"]
        if verbose:
            print(f"   本地 {search_result['local_count']} 篇 + 外部 {search_result['external_count']} 篇 = {total} 篇")

        if total == 0:
            return {"query": query, "papers": [], "status": "未找到相关论文"}

        # Step 2: 筛选
        if verbose:
            print(f"🔎 [筛选Agent] 正在筛选 {total} 篇论文...")
        filter_result = self.filter_agent.run(search_result)
        kept = filter_result.get("kept", 0)
        if verbose:
            print(f"   保留 {kept} 篇（相关度 ≥ 0.6）")

        if kept == 0:
            return {"query": query, "papers": [], "status": "筛选后无高相关论文",
                    "discarded_reason": filter_result.get("discarded_reason", "")}

        # Step 3: 提炼
        if verbose:
            print(f"✍️  [提炼Agent] 正在翻译 {kept} 篇论文...")
        extract_result = self.extract_agent.run(filter_result)

        if verbose:
            print(f"   完成！\n")

        return {
            "query": query,
            "total_found": total,
            "kept": kept,
            "papers": extract_result.get("papers", []),
        }
