"""学术助手快捷入口 — 直接运行 python search.py "关键词" """
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from academic.indexer import index_pdfs, index_status
from academic.searcher import search_all, search_local, search_external
from academic.cli import load_api_key


def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  python search.py \"查询关键词\"")
        print("  python search.py \"关键词\" --json")
        print("  python search.py --status")
        print("  python search.py --index")
        return

    cmd = sys.argv[1]
    key = load_api_key()

    if cmd == "--status":
        s = index_status()
        print(f"已索引: {s['total_pdfs']} 篇, {s['total_chunks']} 个文本块")
        return

    if cmd == "--index":
        print("索引中 (Ctrl+C 停止)...")
        stats = index_pdfs(api_key=key)
        print(f"完成: {stats}")
        return

    # 搜索
    query = cmd
    fmt = "json" if "--json" in sys.argv else "text"
    results = search_all(query, api_key=key)

    if fmt == "json":
        import json
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return

    print(f"\n查询: {results['query']}")
    print(f"本地库: {results['local_count']} 篇 | 外部: {results['external_count']} 篇\n")

    if results["local"]:
        print("── 本地知识库 ──")
        for i, p in enumerate(results["local"], 1):
            print(f"  [{i}] {p['filename']} (相关度: {p['score']})")
            print(f"      {p['snippet'][:200]}\n")

    if results["external"]:
        print("── 外部搜索 ──")
        for i, p in enumerate(results["external"], 1):
            authors = ", ".join(p.get("authors", [])[:3])
            year = p.get("year", "?")
            print(f"  [{i}] {p['title']}")
            print(f"      {authors} | {p['journal']} | {year}")
            abstract = p.get("abstract", "")
            if abstract:
                print(f"      {abstract[:200]}...")
            print()


if __name__ == "__main__":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    main()
