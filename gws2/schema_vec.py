"""Column-level semantic vector store for schema linking (AutoLink-style E_VS).

Each column becomes a short document (name + table + type + description + value
examples); we embed all columns with a bge model and retrieve the top-k most
semantically similar columns for a natural-language query. This is the missing
piece vs AutoLink/LinkAlign: a semantic bridge from question concepts to concrete
columns, which sets the recall ceiling for Spider2 schema linking.

Design notes:
  * embedding via sentence-transformers (bge-*); model is a lazy global singleton;
  * retrieval is plain numpy cosine (columns per DB are <= a few thousand, so an
    exhaustive dot product is fast and avoids a faiss dependency);
  * per-DB embeddings are cached to disk so building is a one-time cost;
  * ``retrieve`` supports an ``exclude`` set of already-returned column indices,
    mirroring AutoLink's non-redundant iterative retrieval.
"""
from __future__ import annotations

import json
import os
import threading

import numpy as np

_MODEL = None
_MODEL_NAME = os.environ.get("GWS2_EMBED_MODEL", "BAAI/bge-small-en-v1.5")
_ENC_LOCK = threading.Lock()  # sentence-transformers encode is not thread-safe


def _get_model():
    global _MODEL
    if _MODEL is None:
        # Prefer local cache; broken corporate proxies often break HF downloads.
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
        os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
        from sentence_transformers import SentenceTransformer
        try:
            _MODEL = SentenceTransformer(
                _MODEL_NAME,
                local_files_only=True,
                device="cpu",
                model_kwargs={"low_cpu_mem_usage": False},
            )
        except Exception:
            os.environ.pop("HF_HUB_OFFLINE", None)
            os.environ.pop("TRANSFORMERS_OFFLINE", None)
            os.environ.setdefault("HF_ENDPOINT", "https://hf-mirror.com")
            _MODEL = SentenceTransformer(
                _MODEL_NAME,
                device="cpu",
                model_kwargs={"low_cpu_mem_usage": False},
            )
    return _MODEL


def _col_doc(c: dict) -> str:
    """AutoLink-style column document string used for embedding."""
    parts = [f"Column: {c.get('column', '')}", f"Table: {c.get('table', '')}"]
    if c.get("type"):
        parts.append(f"Type: {c['type']}")
    if c.get("description"):
        parts.append(f"Description: {c['description']}")
    if c.get("value_examples"):
        parts.append(f"Values: {c['value_examples']}")
    return "; ".join(parts)


class ColumnVectorStore:
    def __init__(self, columns: list[dict], embeddings: np.ndarray):
        self.columns = columns
        self.embeddings = embeddings  # [N, D], L2-normalized float32

    def __len__(self) -> int:
        return len(self.columns)

    @classmethod
    def build(cls, columns: list[dict], cache_path: str | None = None,
              batch_size: int = 64) -> "ColumnVectorStore":
        if cache_path and os.path.exists(cache_path + ".npy") \
                and os.path.exists(cache_path + ".json"):
            emb = np.nan_to_num(np.load(cache_path + ".npy"), posinf=0.0, neginf=0.0)
            cols = json.load(open(cache_path + ".json"))
            if len(cols) == emb.shape[0]:
                return cls(cols, emb)
        if not columns:
            return cls([], np.zeros((0, 384), dtype="float32"))
        docs = [_col_doc(c) for c in columns]
        model = _get_model()
        with _ENC_LOCK:
            emb = model.encode(docs, normalize_embeddings=True, batch_size=batch_size,
                               show_progress_bar=False).astype("float32")
        emb = np.nan_to_num(emb, posinf=0.0, neginf=0.0)  # empty docs can normalize to nan
        store = cls(columns, emb)
        if cache_path:
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            np.save(cache_path + ".npy", emb)
            json.dump(columns, open(cache_path + ".json", "w"), ensure_ascii=False)
        return store

    def retrieve(self, query: str, top_k: int = 5,
                 exclude: set | None = None) -> list[dict]:
        """Return up to top_k column dicts (with _idx, _score) most similar to query."""
        exclude = exclude or set()
        if self.embeddings.shape[0] == 0:
            return []
        with _ENC_LOCK:
            qv = _get_model().encode([query], normalize_embeddings=True)[0].astype("float32")
        qv = np.nan_to_num(qv, posinf=0.0, neginf=0.0)
        with np.errstate(over="ignore", invalid="ignore", divide="ignore"):
            scores = np.nan_to_num(self.embeddings @ qv, posinf=0.0, neginf=0.0)
        order = np.argsort(-scores)
        out: list[dict] = []
        for idx in order:
            i = int(idx)
            if i in exclude:
                continue
            c = dict(self.columns[i])
            c["_idx"] = i
            c["_score"] = float(scores[i])
            out.append(c)
            if len(out) >= top_k:
                break
        return out


def columns_from_local_schema(schema) -> list[dict]:
    """Build column dicts from a local gws2.schema.Schema (with optional BIRD/
    Spider2 descriptions already loaded into schema.descriptions)."""
    out: list[dict] = []
    for t, cols in schema.tables.items():
        desc_map = schema.descriptions.get(t.lower(), {}) if schema.descriptions else {}
        for c in cols:
            info = desc_map.get(c.name.lower(), {})
            out.append({
                "table": t,
                "column": c.name,
                "type": c.type,
                "description": (info.get("desc", "") + (
                    " | " + info["value_desc"] if info.get("value_desc") else "")).strip(" |"),
                "value_examples": "",
                "pk": bool(getattr(c, "pk", False)),
            })
    return out


def columns_from_online_schema(online_schema) -> list[dict]:
    """Build column dicts from gws2.online_schema.OnlineSchema (BQ/SF DDL)."""
    out: list[dict] = []
    for t in online_schema.tables:
        fqn = t.fqn()
        desc = (t.description or "").strip()
        for name, typ in t.columns():
            out.append({
                "table": fqn,
                "column": name,
                "type": typ,
                "description": desc[:200] if desc else "",
                "value_examples": "",
                "pk": name.lower().endswith("_id") or name.lower() == "id",
            })
    return out


def enrich_value_examples(columns: list[dict], sqlite_path: str,
                          n: int = 5, timeout: float = 2.0,
                          max_cols: int = 400) -> list[dict]:
    """Sample DISTINCT non-null values into each column's ``value_examples``.

    AutoLink-style: value examples improve semantic retrieval for filters /
    join keys / categorical columns. Caps work to ``max_cols`` (prefer text /
    short-name columns) so large DBs stay cheap.
    """
    from .execute import run_query

    # Prefer categorical / name-like columns; skip huge blobs.
    def _prio(c: dict) -> int:
        name = (c.get("column") or "").lower()
        typ = (c.get("type") or "").upper()
        score = 0
        if any(k in name for k in ("name", "code", "type", "status", "id",
                                   "date", "year", "month", "city", "country",
                                   "league", "team", "gender", "category")):
            score += 3
        if any(t in typ for t in ("CHAR", "TEXT", "VARCHAR", "DATE", "TIME")):
            score += 2
        if c.get("pk"):
            score += 1
        if "BLOB" in typ or "BINARY" in typ:
            score -= 5
        return -score  # lower = earlier

    ranked = sorted(range(len(columns)), key=lambda i: _prio(columns[i]))
    out = [dict(c) for c in columns]
    done = 0
    for i in ranked:
        if done >= max_cols:
            break
        c = out[i]
        t, col = c["table"], c["column"]
        # Quote identifiers safely for SQLite
        sql = (f'SELECT DISTINCT "{col}" FROM "{t}" '
               f'WHERE "{col}" IS NOT NULL LIMIT {n}')
        r = run_query(sqlite_path, sql, max_rows=n, timeout=timeout)
        if not r.get("ok"):
            continue
        vals = []
        for row in r.get("rows") or []:
            v = row[0]
            if v is None:
                continue
            s = str(v).replace("\n", " ").strip()
            if len(s) > 60:
                s = s[:57] + "..."
            if s:
                vals.append(s)
        if vals:
            c["value_examples"] = ", ".join(vals)
            done += 1
    return out
