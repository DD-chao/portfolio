"""学术助手配置"""
from pathlib import Path

# 文献 PDF 目录
LITERATURE_DIR = Path("D:/academic-self/literature")
MY_PAPER_DIR = Path("D:/academic-self/my-paper/literature")

# ChromaDB 存储目录
VECTOR_DB_DIR = Path("D:/agent-learning/academic/chroma_db")

# SearXNG
SEARXNG_URL = "http://localhost:8080/search"
SEARXNG_ENGINES = "openalex,pubmed,arxiv,semantic_scholar,crossref"

# SiliconFlow Embedding API (BGE-M3)
EMBEDDING_API_URL = "https://api.siliconflow.cn/v1/embeddings"
EMBEDDING_MODEL = "BAAI/bge-m3"

# PDF 分块
CHUNK_SIZE = 1000  # 每块字符数
CHUNK_OVERLAP = 200  # 重叠字符数
