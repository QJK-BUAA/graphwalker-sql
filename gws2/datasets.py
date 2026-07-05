"""Dataset loaders + deterministic stratified samplers.

Three benchmarks, all reduced to a common ``Example``:
  * BIRD-Dev        (declared FKs; 1,534 q / 11 DBs; has difficulty labels)
  * Spider 1.0-Dev  (declared FKs; 1,034 q / 166 DBs)
  * Spider 2.0-Lite (FK-sparse; local SQLite subset with gold SQL; 24 q)

Sampling is seeded and stratified (by DB, and by difficulty for BIRD) so a small
"smoke" run still spans databases and hardness levels reproducibly.
"""
from __future__ import annotations

import glob
import json
import os
import random
from dataclasses import dataclass

from . import config


@dataclass
class Example:
    idx: int                 # original index in the source file (for gold alignment)
    instance_id: str
    db_id: str
    question: str
    evidence: str
    gold_sql: str
    sqlite_path: str
    difficulty: str = ""
    dialect: str = "SQLite"


# --------------------------------------------------------------------------- #
# Loaders
# --------------------------------------------------------------------------- #
def load_bird(root: str = config.BIRD_ROOT) -> list[Example]:
    data = json.load(open(config.BIRD_DEV_JSON))
    out: list[Example] = []
    for i, ex in enumerate(data):
        db = ex["db_id"]
        sp = os.path.join(config.BIRD_DB_DIR, db, f"{db}.sqlite")
        if not os.path.exists(sp):
            continue
        out.append(Example(
            idx=i, instance_id=f"bird_{ex['question_id']}", db_id=db,
            question=ex["question"], evidence=ex.get("evidence", ""),
            gold_sql=ex["SQL"], sqlite_path=sp,
            difficulty=ex.get("difficulty", ""),
        ))
    return out


def load_spider1(root: str = config.SPIDER1_ROOT) -> list[Example]:
    data = json.load(open(config.SPIDER1_DEV_JSON))
    gold_lines = [l.strip() for l in open(config.SPIDER1_DEV_GOLD)
                  if l.strip()]
    out: list[Example] = []
    for i, ex in enumerate(data):
        db = ex["db_id"]
        sp = os.path.join(config.SPIDER1_DB_DIR, db, f"{db}.sqlite")
        if not os.path.exists(sp):
            continue
        gold = ex.get("query", "")
        # dev_gold.sql lines are "SQL\tdb_id"; keep them index-aligned for eval.
        if i < len(gold_lines) and "\t" in gold_lines[i]:
            gold = gold_lines[i].rsplit("\t", 1)[0]
        out.append(Example(
            idx=i, instance_id=f"spider1_{i}", db_id=db,
            question=ex["question"], evidence="", gold_sql=gold, sqlite_path=sp,
        ))
    return out


def load_spider2_lite(root: str = config.SPIDER2_ROOT) -> list[Example]:
    meta = {json.loads(l)["instance_id"]: json.loads(l)
            for l in open(config.SPIDER2_JSONL)}
    out: list[Example] = []
    for gf in sorted(glob.glob(os.path.join(config.SPIDER2_GOLD_SQL_DIR, "local*.sql"))):
        iid = os.path.basename(gf).replace(".sql", "")
        if iid not in meta:
            continue
        db = meta[iid]["db"]
        sp = os.path.join(config.SPIDER2_LOCALDB, f"{db}.sqlite")
        if not os.path.exists(sp):
            continue
        out.append(Example(
            idx=len(out), instance_id=iid, db_id=db,
            question=meta[iid]["question"], evidence="",
            gold_sql=open(gf).read(), sqlite_path=sp,
        ))
    return out


def load_spider2_lite_local(root: str = config.SPIDER2_ROOT) -> list[Example]:
    """Load all Spider2-Lite local SQLite examples.

    The official gold/sql folder only contains a 24-question SQL subset, while
    gold/exec_result contains all 135 local examples. For SQL-mode evaluation,
    the official evaluator only needs our predicted SQL files and the local
    SQLite databases, so gold_sql can be empty here.
    """
    meta = {json.loads(l)["instance_id"]: json.loads(l)
            for l in open(config.SPIDER2_JSONL)}
    map_path = os.path.join(config.SPIDER2_LOCALDB, "local-map.jsonl")
    local_map = json.loads(open(map_path).read())
    out: list[Example] = []
    for iid in sorted(k for k in meta if k.startswith("local")):
        db = local_map.get(iid) or meta[iid]["db"]
        sp = os.path.join(config.SPIDER2_LOCALDB, f"{db}.sqlite")
        if not os.path.exists(sp):
            continue
        out.append(Example(
            idx=len(out), instance_id=iid, db_id=db,
            question=meta[iid]["question"],
            evidence=meta[iid].get("external_knowledge", ""),
            gold_sql="", sqlite_path=sp,
        ))
    return out


LOADERS = {
    "bird": load_bird,
    "spider1": load_spider1,
    "spider2-lite": load_spider2_lite,
    "spider2-lite-local": load_spider2_lite_local,
}


# --------------------------------------------------------------------------- #
# Deterministic stratified sampling
# --------------------------------------------------------------------------- #
def sample(examples: list[Example], limit: int | None,
           seed: int = config.DEFAULT_SEED) -> list[Example]:
    """Reproducible stratified subsample.

    Two-level round-robin: interleave difficulty groups at the top level (so a
    BIRD sample keeps its simple/moderate/challenging mix), and within each
    difficulty interleave databases (so the sample spans many DBs). Spider1/2
    have no difficulty labels, so they degrade to pure DB round-robin. Returns
    items sorted by original index for stable evaluator alignment.
    """
    if not limit or limit >= len(examples):
        return sorted(examples, key=lambda e: e.idx)

    rng = random.Random(seed)

    def db_interleaved(items: list[Example]) -> list[Example]:
        by_db: dict[str, list[Example]] = {}
        for e in items:
            by_db.setdefault(e.db_id, []).append(e)
        for db in by_db:
            rng.shuffle(by_db[db])
        order = sorted(by_db.keys())
        out: list[Example] = []
        while any(by_db[db] for db in order):
            for db in order:
                if by_db[db]:
                    out.append(by_db[db].pop())
        return out

    diff_groups: dict[str, list[Example]] = {}
    for e in examples:
        diff_groups.setdefault(e.difficulty or "", []).append(e)
    queues = {d: db_interleaved(items) for d, items in diff_groups.items()}

    diff_order = sorted(queues.keys())
    picked: list[Example] = []
    cursors = {d: 0 for d in diff_order}
    while len(picked) < limit and any(cursors[d] < len(queues[d]) for d in diff_order):
        for d in diff_order:
            if cursors[d] < len(queues[d]):
                picked.append(queues[d][cursors[d]])
                cursors[d] += 1
                if len(picked) >= limit:
                    break
    return sorted(picked, key=lambda e: e.idx)


def load_and_sample(dataset: str, limit: int | None,
                    seed: int = config.DEFAULT_SEED) -> list[Example]:
    if dataset not in LOADERS:
        raise ValueError(f"Unknown dataset {dataset!r}; choose from {list(LOADERS)}")
    return sample(LOADERS[dataset](), limit, seed=seed)
