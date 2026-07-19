"""Retrieval-based few-shot exemplars (DAIL-SQL style, training-free).

Given a test question, retrieve the most similar solved ``(question, gold SQL)``
pairs from the benchmark TRAIN split and inject them into the generation prompt.
Retrieval is a dependency-free BM25 over question tokens (optionally masked), so
this adds no heavy packages and no extra LLM calls.

Exemplar sources:
  * BIRD   -> data/fewshot/bird_train.jsonl (HF birdsql/bird23-train-filtered)
  * Spider -> <SPIDER1_ROOT>/train_spider.json (+ train_others.json)

The retriever is built ONCE per run and shared across questions.
"""
from __future__ import annotations

import json
import math
import os
import re
from collections import Counter

from . import config

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_TOK = re.compile(r"[a-z0-9]+")
# strip quoted literals / bare numbers so retrieval matches question STRUCTURE
# (intent) rather than the specific entity values of one question.
_QUOTED = re.compile(r"'[^']*'|\"[^\"]*\"")
_NUM = re.compile(r"\b\d+(\.\d+)?\b")


def _mask(text: str) -> str:
    text = _QUOTED.sub(" _VAL_ ", text)
    text = _NUM.sub(" _NUM_ ", text)
    return text


def _tok(text: str) -> list[str]:
    return _TOK.findall(_mask(text).lower())


class FewShotRetriever:
    """BM25 retriever over training questions."""

    def __init__(self, examples: list[dict], with_evidence: bool = False,
                 k1: float = 1.5, b: float = 0.75):
        self.examples = examples
        self.with_evidence = with_evidence
        self.k1, self.b = k1, b
        self._docs = [_tok(e["question"]) for e in examples]
        self._dl = [len(d) for d in self._docs]
        self._avgdl = (sum(self._dl) / len(self._dl)) if self._dl else 0.0
        self._tf = [Counter(d) for d in self._docs]
        df: Counter = Counter()
        for d in self._docs:
            for t in set(d):
                df[t] += 1
        n = len(self._docs)
        self._idf = {t: math.log(1 + (n - c + 0.5) / (c + 0.5)) for t, c in df.items()}

    def _score(self, q_tokens: list[str], i: int) -> float:
        tf = self._tf[i]
        dl = self._dl[i]
        denom_norm = self.k1 * (1 - self.b + self.b * dl / (self._avgdl or 1))
        s = 0.0
        for t in q_tokens:
            f = tf.get(t)
            if not f:
                continue
            s += self._idf.get(t, 0.0) * (f * (self.k1 + 1)) / (f + denom_norm)
        return s

    def retrieve(self, question: str, k: int = 3) -> list[dict]:
        q = _tok(question)
        if not q or not self.examples:
            return []
        order = sorted(range(len(self.examples)),
                       key=lambda i: self._score(q, i), reverse=True)
        return [self.examples[i] for i in order[:k]]

    def block(self, question: str, k: int = 3) -> str:
        picks = self.retrieve(question, k)
        if not picks:
            return ""
        parts = [
            "Reference examples (similar natural-language questions already solved "
            "on OTHER databases; use them to guide the SQL STRUCTURE and style, but "
            "ONLY use tables/columns from the Grounded Schema above):", ""]
        for i, e in enumerate(picks, 1):
            parts.append(f"Example {i}:")
            parts.append(f"Q: {e['question'].strip()}")
            if self.with_evidence and e.get("evidence"):
                parts.append(f"Evidence: {e['evidence'].strip()}")
            parts.append(f"SQL: {e['sql'].strip()}")
            parts.append("")
        return "\n".join(parts)


def load_bird_exemplars(path: str) -> list[dict]:
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            sql = r.get("SQL") or r.get("sql") or ""
            if not sql:
                continue
            out.append({"question": r.get("question", ""), "sql": sql,
                        "evidence": r.get("evidence", ""), "db_id": r.get("db_id", "")})
    return out


def load_spider_exemplars(paths: list[str]) -> list[dict]:
    out = []
    for p in paths:
        if not os.path.exists(p):
            continue
        for r in json.load(open(p)):
            sql = r.get("query") or r.get("SQL") or ""
            if not sql:
                continue
            out.append({"question": r.get("question", ""), "sql": sql,
                        "evidence": "", "db_id": r.get("db_id", "")})
    return out


def build_retriever(dataset: str) -> FewShotRetriever | None:
    """Build the exemplar retriever for a dataset, or None if unavailable."""
    if dataset == "bird":
        path = os.path.join(_REPO_ROOT, "data", "fewshot", "bird_train.jsonl")
        if not os.path.exists(path):
            return None
        return FewShotRetriever(load_bird_exemplars(path), with_evidence=True)
    if dataset == "spider1":
        base = config.SPIDER1_ROOT
        paths = [os.path.join(base, "train_spider.json"),
                 os.path.join(base, "train_others.json")]
        exs = load_spider_exemplars(paths)
        return FewShotRetriever(exs, with_evidence=False) if exs else None
    # Spider2 has no train split; few-shot not supported there yet.
    return None
