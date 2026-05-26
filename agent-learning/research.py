"""Multi-Agent 文献调研 — 搜索 → 筛选 → 提炼 全自动"""
import sys
import io
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

from academic.agents import MultiAgentPipeline


def main():
    if len(sys.argv) < 2:
        print("用法: python research.py \"研究问题\"")
        print("示例: python research.py \"动态办公椅对腰椎姿势与肌肉激活的影响\"")
        return

    query = sys.argv[1]
    pipeline = MultiAgentPipeline()
    result = pipeline.run(query)

    if result["papers"]:
        print("=" * 60)
        print(f"研究问题: {result['query']}")
        print(f"搜索 {result['total_found']} 篇 → 筛选保留 {result['kept']} 篇 → 翻译提炼完成")
        print("=" * 60)

        for i, p in enumerate(result["papers"], 1):
            print(f"\n{'─' * 50}")
            print(f"[{i}] {p.get('title_cn', '无标题')}")
            print(f"{'─' * 50}")
            if p.get("abstract_cn"):
                print(f"\n摘要: {p['abstract_cn'][:300]}")
            if p.get("key_points"):
                print(f"\n核心要点:")
                for j, kp in enumerate(p["key_points"], 1):
                    print(f"  {j}. {kp}")
    else:
        print(f"\n未找到相关论文: {result.get('status', '')}")


if __name__ == "__main__":
    main()
