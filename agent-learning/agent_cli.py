"""
Dify Agent 本地命令行工具
用法:
  python agent_cli.py "搜索动态办公椅对腰椎姿势影响的研究"
  python agent_cli.py --file topics.txt    # 批量处理
  python agent_cli.py --watch literature/  # 监控目录，新PDF自动翻译
"""

import requests
import sys
import json
import time
import argparse
from pathlib import Path

API_URL = "http://localhost/v1/chat-messages"
API_KEY = "app-YmYlNOuYw8J945aMtK3vrJwl"
CONV_FILE = Path(__file__).parent / ".conversation_id"


def load_conversation_id() -> str | None:
    if CONV_FILE.exists():
        return CONV_FILE.read_text().strip()
    return None


def save_conversation_id(cid: str):
    CONV_FILE.write_text(cid)


def ask_agent(query: str, user: str = "cli-user", new_session: bool = False) -> str:
    """向 Dify Agent 发送提问，返回回答文本。
    默认保持同一会话上下文；传 new_session=True 开启新对话。"""
    payload: dict = {
        "inputs": {
            "term_style": "首次出现标注英文原文",
            "preferred_length": "50-100字",
            "last_topic": "",
        },
        "query": query,
        "response_mode": "streaming",
        "user": user,
    }

    if not new_session:
        existing = load_conversation_id()
        if existing:
            payload["conversation_id"] = existing

    resp = requests.post(
        API_URL,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=120,
        stream=True,
    )
    resp.raise_for_status()
    full_answer = []
    cid = None
    for line in resp.iter_lines():
        if not line:
            continue
        line = line.decode("utf-8")
        if not line.startswith("data:"):
            continue
        try:
            event = json.loads(line[5:].strip())
            cid = event.get("conversation_id") or cid
            evt_type = event.get("event", "")
            if evt_type == "agent_message":
                chunk = event.get("answer", "")
                print(chunk, end="", flush=True)
                full_answer.append(chunk)
            elif evt_type == "agent_message_end":
                break
        except json.JSONDecodeError:
            continue
    print()
    if cid:
        save_conversation_id(cid)
    return "".join(full_answer)


def batch_from_file(filepath: str):
    """从文件读取多行主题，逐条处理"""
    topics = Path(filepath).read_text(encoding="utf-8").strip().split("\n")
    for i, topic in enumerate(topics, 1):
        topic = topic.strip()
        if not topic or topic.startswith("#"):
            continue
        print(f"\n{'='*60}")
        print(f"[{i}/{len(topics)}] {topic}")
        print("=" * 60)
        try:
            result = ask_agent(topic)
            print(result)
        except Exception as e:
            print(f"ERROR: {e}")


def main():
    parser = argparse.ArgumentParser(description="Dify Agent CLI")
    parser.add_argument("query", nargs="?", help="直接提问")
    parser.add_argument("--file", "-f", help="批量处理文件，每行一个主题")
    parser.add_argument("--new", "-n", action="store_true", help="开启新会话（不继承上下文）")
    args = parser.parse_args()

    if args.file:
        batch_from_file(args.file)
    elif args.query:
        result = ask_agent(args.query, new_session=args.new)
        print(result)
    else:
        print("用法: python agent_cli.py \"你的问题\"")
        print("     python agent_cli.py --file topics.txt")
        print("     python agent_cli.py --new \"新话题\"  # 开启新会话")


if __name__ == "__main__":
    main()
