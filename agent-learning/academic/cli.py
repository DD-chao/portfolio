"""学术助手 CLI"""
import sys
import json
import argparse
from pathlib import Path

# 配置 API Key — 通过环境变量或文件
def load_api_key() -> str:
    env_file = Path(__file__).parent.parent / ".siliconflow_key"
    if env_file.exists():
        return env_file.read_text().strip()
    return ""


def cmd_index(args):
    key = args.key or load_api_key()
    if not key:
        print("请先设置 SiliconFlow API Key:")
        print("  python -m academic.cli set-key <your_key>")
        return

    from .indexer import index_pdfs, index_status
    print("索引中...")
    stats = index_pdfs(api_key=key, max_pdfs=args.max)
    print(f"\n索引完成: {stats}")


def cmd_search(args):
    key = args.key or load_api_key()
    if not key:
        print("需要 SiliconFlow API Key")
        return

    from .searcher import search_all
    results = search_all(args.query, api_key=key,
                         top_k_local=args.local, top_k_external=args.external)

    if args.fmt == "json":
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print(f"\n查询: {results['query']}")
        print(f"本地库: {results['local_count']} 篇 | 外部搜索: {results['external_count']} 篇\n")

        if results["local"]:
            print("── 本地知识库 ──")
            for i, p in enumerate(results["local"], 1):
                print(f"  [{i}] {p['filename']}  (相关度: {p['score']})")
                print(f"      {p['snippet'][:200]}...\n")

        if results["external"]:
            print("── 外部搜索 ──")
            for i, p in enumerate(results["external"], 1):
                authors = ", ".join(p.get("authors", [])[:3])
                year = p.get("year", "?")
                print(f"  [{i}] {p['title']}")
                print(f"      {authors} | {p['journal']} | {year}")
                print(f"      {p['abstract'][:200]}...\n")


def cmd_status(args):
    from .indexer import index_status
    s = index_status()
    print(f"已索引: {s['total_pdfs']} 篇, {s['total_chunks']} 个文本块")


def cmd_set_key(args):
    env_file = Path(__file__).parent.parent / ".siliconflow_key"
    env_file.write_text(args.api_key)
    env_file.chmod(0o600)
    print("API Key 已保存")


def main():
    parser = argparse.ArgumentParser(description="学术助手")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("status", help="查看索引状态")

    p = sub.add_parser("set-key", help="保存 SiliconFlow API Key")
    p.add_argument("api_key", help="SiliconFlow API Key")

    p = sub.add_parser("index", help="索引 PDF")
    p.add_argument("--key", help="API Key")
    p.add_argument("--max", type=int, help="最大索引数量")

    p = sub.add_parser("search", help="搜索论文")
    p.add_argument("query", help="搜索关键词")
    p.add_argument("--key", help="API Key")
    p.add_argument("--local", type=int, default=10, help="本地 K (默认 10)")
    p.add_argument("--external", type=int, default=15, help="外部 K (默认 15)")
    p.add_argument("--fmt", default="text", choices=["text", "json"], help="格式")

    args = parser.parse_args()

    if args.cmd == "set-key":
        cmd_set_key(args)
    elif args.cmd == "index":
        cmd_index(args)
    elif args.cmd == "search":
        cmd_search(args)
    elif args.cmd == "status":
        cmd_status(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
