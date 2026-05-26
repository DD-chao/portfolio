"""搜索：本地向量搜索 + SearXNG 外部搜索"""
import requests
from .indexer import get_collection, get_embedding
from .config import SEARXNG_URL, SEARXNG_ENGINES


def search_local(query: str, api_key: str, top_k: int = 10) -> list[dict]:
    """在本地 ChromaDB 中搜索，返回相关论文片段"""
    collection = get_collection()
    if collection.count() == 0:
        return []

    embedding = get_embedding([query], api_key)[0]
    results = collection.query(query_embeddings=[embedding], n_results=top_k)

    papers = []
    seen: set[str] = set()
    if results["ids"] and results["ids"][0]:
        for i, cid in enumerate(results["ids"][0]):
            meta = results["metadatas"][0][i]
            path = meta.get("path", "")
            filename = meta.get("filename", "")
            text = results["documents"][0][i][:2000] if results["documents"] and results["documents"][0] else ""
            score = float(results["distances"][0][i]) if results.get("distances") and results["distances"][0] else 0.0

            if path not in seen:
                seen.add(path)
                papers.append({
                    "source": "local",
                    "filename": filename,
                    "path": path,
                    "snippet": text,
                    "score": round(1.0 - min(score, 1.0), 4)
                })
    return papers


def _to_english(query: str, api_key: str) -> str:
    """如果查询含中文，用 LLM 翻译为英文搜索关键词"""
    has_cjk = any('一' <= c <= '鿿' for c in query)
    if not has_cjk:
        return query
    import requests as req
    resp = req.post(
        "https://api.siliconflow.cn/v1/chat/completions",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json={
            "model": "deepseek-ai/DeepSeek-V3",
            "messages": [{"role": "user", "content": f"将以下中文研究问题翻译为英文搜索关键词，只输出关键词不要句子：{query}"}],
            "max_tokens": 60,
            "temperature": 0.1,
        },
        timeout=30,
    )
    if resp.status_code == 200:
        return resp.json()["choices"][0]["message"]["content"].strip().strip('"')
    return query


def search_external(query: str, engines: str = None, max_results: int = 15, api_key: str = "") -> list[dict]:
    """通过 SearXNG 搜索外部学术数据库"""
    if engines is None:
        engines = SEARXNG_ENGINES

    # 中文自动翻译为英文关键词
    search_query = _to_english(query, api_key) if api_key else query

    resp = requests.get(
        SEARXNG_URL,
        params={"q": search_query, "format": "json", "engines": engines},
        timeout=30
    )
    resp.raise_for_status()
    data = resp.json()

    papers = []
    seen: set[str] = set()
    for r in data.get("results", [])[:max_results]:
        title = r.get("title", "")
        if title in seen:
            continue
        seen.add(title)
        papers.append({
            "source": r.get("engine", "external"),
            "title": title,
            "abstract": r.get("content", ""),
            "url": r.get("url", ""),
            "doi": r.get("doi", ""),
            "authors": r.get("authors", []),
            "year": (r.get("publishedDate") or "")[:4],
            "journal": r.get("journal", ""),
            "pdf_url": r.get("pdf_url", ""),
        })
    return papers


def search_all(query: str, api_key: str, top_k_local: int = 10, top_k_external: int = 15) -> dict:
    """组合搜索：本地 + 外部"""
    local = search_local(query, api_key, top_k=top_k_local)
    external = search_external(query, max_results=top_k_external, api_key=api_key)
    return {
        "query": query,
        "local_count": len(local),
        "external_count": len(external),
        "local": local,
        "external": external,
    }
