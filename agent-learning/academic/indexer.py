"""PDF 索引：读取 PDF → 分块 → 向量化 → 存入 ChromaDB"""
import os
from pathlib import Path
import chromadb
from chromadb.config import Settings
import requests

from .config import (
    LITERATURE_DIR, MY_PAPER_DIR, VECTOR_DB_DIR,
    EMBEDDING_API_URL, EMBEDDING_MODEL, CHUNK_SIZE, CHUNK_OVERLAP
)


def get_client():
    return chromadb.PersistentClient(path=str(VECTOR_DB_DIR), settings=Settings(anonymized_telemetry=False))


def get_collection():
    client = get_client()
    return client.get_or_create_collection(
        name="papers",
        metadata={"hnsw:space": "cosine"}
    )


def read_pdf(filepath: str) -> str:
    """读取 PDF 文本内容"""
    import fitz
    doc = fitz.open(filepath)
    text = "\n".join(page.get_text() for page in doc)
    doc.close()
    return text.strip()


def chunk_text(text: str) -> list[str]:
    """将文本切分成有重叠的块"""
    chunks = []
    start = 0
    while start < len(text):
        end = start + CHUNK_SIZE
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks


def get_embedding(texts: list[str], api_key: str, batch_size: int = 8) -> list[list[float]]:
    """调用 SiliconFlow BGE-M3 获取向量，分批发送避免 413 错误"""
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        resp = requests.post(
            EMBEDDING_API_URL,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": EMBEDDING_MODEL,
                "input": batch,
                "encoding_format": "float"
            },
            timeout=120
        )
        resp.raise_for_status()
        data = resp.json()
        all_embeddings.extend(item["embedding"] for item in data["data"])
    return all_embeddings


def index_pdfs(api_key: str, source_dirs: list[str] = None, max_pdfs: int = None):
    """扫描目录，索引未入库的 PDF，返回统计信息"""
    if source_dirs is None:
        source_dirs = [str(LITERATURE_DIR), str(MY_PAPER_DIR)]

    collection = get_collection()

    # 收集所有 PDF 路径
    pdf_files = []
    for d in source_dirs:
        for root, _, files in os.walk(d):
            for f in files:
                if f.lower().endswith(".pdf"):
                    pdf_files.append(os.path.join(root, f))

    # 检查哪些已入库
    existing = set()
    existing_meta = collection.get() if collection.count() > 0 else {"metadatas": [], "ids": []}
    if existing_meta["metadatas"]:
        for meta in existing_meta["metadatas"]:
            existing.add(meta.get("path", ""))

    new_files = [p for p in pdf_files if p not in existing]
    if max_pdfs:
        new_files = new_files[:max_pdfs]

    if not new_files:
        return {"indexed": 0, "total": len(pdf_files), "message": "全部已入库"}

    stats = {"indexed": 0, "total": len(pdf_files), "errors": 0, "skipped": len(pdf_files) - len(new_files)}

    for i, pdf_path in enumerate(new_files):
        try:
            # 读取 PDF
            text = read_pdf(pdf_path)
            if len(text) < 100:
                stats["errors"] += 1
                continue

            # 分块
            chunks = chunk_text(text)
            if not chunks:
                continue

            # 取向量
            embeddings = get_embedding(chunks, api_key)

            # 存入 ChromaDB
            fid = str(abs(hash(pdf_path)) % (10 ** 12))
            for j, (chunk, emb) in enumerate(zip(chunks, embeddings)):
                collection.add(
                    ids=[f"{fid}_{j}"],
                    embeddings=[emb],
                    documents=[chunk],
                    metadatas=[{
                        "path": pdf_path,
                        "filename": os.path.basename(pdf_path),
                        "chunk_idx": j,
                        "total_chunks": len(chunks)
                    }]
                )

            stats["indexed"] += 1

            if (i + 1) % 10 == 0:
                print(f"  已索引 {stats['indexed']}/{len(new_files)} ...")

        except Exception as e:
            stats["errors"] += 1
            print(f"  错误 [{os.path.basename(pdf_path)}]: {e}")

    return stats


def index_status():
    """查看索引状态"""
    collection = get_collection()
    count = collection.count()
    paths = set()
    if count > 0:
        metas = collection.get()["metadatas"]
        for m in metas:
            paths.add(m.get("path", ""))
    return {"total_chunks": count, "total_pdfs": len(paths)}
