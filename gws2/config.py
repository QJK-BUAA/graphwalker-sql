"""Central configuration: dataset paths, evaluator paths, and default hyper-parameters.

All paths are resolved relative to the repository root of the surrounding
workspace (``研二下``) so the code runs without further setup on this machine.
Override any of them with environment variables of the same name if needed.
"""
from __future__ import annotations

import os

# --------------------------------------------------------------------------- #
# Workspace roots
# --------------------------------------------------------------------------- #
# .../研二下/GraphWalker-SQL-2.0/gws2/config.py -> .../研二下
_THIS = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(_THIS, "..", ".."))


def _p(*parts: str) -> str:
    return os.path.join(PROJECT_ROOT, *parts)


# --------------------------------------------------------------------------- #
# Dataset locations (discovered on this machine)
# --------------------------------------------------------------------------- #
_ITS = _p("论文复现", "Interactive-Text-to-SQL", "dataset", "_extracted")

# BIRD-Dev (declared FKs): 1,534 questions / 11 databases.
BIRD_ROOT = os.environ.get("GWS2_BIRD_ROOT", _p(_ITS, "bird_dev", "dev_20240627"))
BIRD_DEV_JSON = os.path.join(BIRD_ROOT, "dev.json")
BIRD_DEV_GOLD = os.path.join(BIRD_ROOT, "dev.sql")
BIRD_DB_DIR = os.path.join(BIRD_ROOT, "dev_databases")

# Spider 1.0-Dev (declared FKs): 1,034 questions / 166 databases.
SPIDER1_ROOT = os.environ.get("GWS2_SPIDER1_ROOT", os.path.join(_ITS, "spider_data"))
SPIDER1_DEV_JSON = os.path.join(SPIDER1_ROOT, "dev.json")
SPIDER1_DEV_GOLD = os.path.join(SPIDER1_ROOT, "dev_gold.sql")
SPIDER1_DB_DIR = os.path.join(SPIDER1_ROOT, "database")
SPIDER1_TABLES = os.path.join(SPIDER1_ROOT, "tables.json")

# Spider 2.0-Lite (FK-sparse; local SQLite subset with gold SQL).
SPIDER2_ROOT = os.environ.get("GWS2_SPIDER2_ROOT", _p("ReFoRCE", "spider2-lite"))
SPIDER2_JSONL = os.path.join(SPIDER2_ROOT, "spider2-lite.jsonl")
SPIDER2_GOLD_SQL_DIR = os.path.join(SPIDER2_ROOT, "evaluation_suite", "gold", "sql")
SPIDER2_LOCALDB = os.path.join(SPIDER2_ROOT, "resource", "databases", "spider2-localdb")

# --------------------------------------------------------------------------- #
# Official evaluators
# --------------------------------------------------------------------------- #
BIRD_EVAL_SCRIPT = _p("论文复现", "Interactive-Text-to-SQL", "evaluation",
                      "bird_evaluation_raw.py")
SPIDER1_TESTSUITE = _p("论文复现", "Interactive-Text-to-SQL", "dataset", "_external",
                       "test-suite-sql-eval")
SPIDER2_EVAL_DIR = os.path.join(SPIDER2_ROOT, "evaluation_suite")

# --------------------------------------------------------------------------- #
# Default hyper-parameters (GraphWalker-SQL 2.0)
# --------------------------------------------------------------------------- #
DEFAULT_MODEL = os.environ.get("GWS2_MODEL", "deepseek-chat")
DEFAULT_BASE_URL = os.environ.get("GWS2_BASE_URL", "https://api.deepseek.com")
DEFAULT_TEMPERATURE = float(os.environ.get("GWS2_TEMPERATURE", "0.0"))
DEFAULT_SEED = int(os.environ.get("GWS2_SEED", "42"))

# Graph / belief thresholds.
EDGE_CONF_THRESHOLD = 0.30      # delta: minimum conf(edge) to enter the graph.
VALUE_OVERLAP_SAMPLE = 300      # rows sampled for data-level overlap.
VALUE_OVERLAP_THRESHOLD = 0.50  # containment ratio marking a "data-supported" edge.

# Explore phase.
TOPK_PATHS = 3                  # k in top-k shortest paths.
MAX_PATH_EDGES = 4              # path length cap.
PATH_ENTROPY_PROBE = 0.60       # trigger execution probe only above this entropy (bits).
PROBE_LIMIT = 1000              # LIMIT used inside lightweight join probes.
LAMBDA_COST = 0.15              # R = info_gain - lambda * call_cost (exploration gate).
MAX_EXPLORE_STEPS = 4           # hard cap on explore iterations.

# Column/value belief walk. These probes are local SQLite reads, not LLM calls.
COLUMN_ENTROPY_PROBE = 1.00     # trigger column probes above this column entropy.
COLUMN_PROBE_MAX_COLUMNS = 24   # bounded candidate columns per question.
COLUMN_PROBE_MAX_LITERALS = 4   # bounded literal hits per question.
COLUMN_PROBE_MAX_SQL = 48       # hard cap on local SQL probes per question.
COLUMN_PROBE_SAMPLE_VALUES = 5  # distinct sample values shown to the generator.
COLUMN_PROBE_TIMEOUT = 5.0      # timeout per cheap column probe.

# Commit phase.
MAX_REPAIRS = 1                 # at most one targeted repair (kept minimal by design).

# Execution.
EXEC_TIMEOUT = 30.0
EXEC_MAX_ROWS = 2000

# --------------------------------------------------------------------------- #
# Cloud execution (P1: remote bounded belief repair for Spider2-Lite online)
# --------------------------------------------------------------------------- #
# Path to Spider2 credential files (bigquery_credential.json / snowflake_credential.json).
SPIDER2_CRED_DIR = os.environ.get("GWS2_SPIDER2_CRED_DIR", _p("spider2凭证文件"))
# BigQuery dry-run cost guard: skip executing any query whose estimated scan
# exceeds this many GB, so a bad generated SQL cannot rack up cloud cost.
BQ_DRYRUN_MAX_GB = float(os.environ.get("GWS2_BQ_DRYRUN_MAX_GB", "5.0"))
CLOUD_EXEC_TIMEOUT = float(os.environ.get("GWS2_CLOUD_EXEC_TIMEOUT", "120"))
CLOUD_EXEC_MAX_ROWS = int(os.environ.get("GWS2_CLOUD_EXEC_MAX_ROWS", "50"))
CLOUD_MAX_REPAIRS = int(os.environ.get("GWS2_CLOUD_MAX_REPAIRS", "2"))

# P2: remote belief probes (cloud column/value walk). Bounded to control cost;
# every probe is dry-run-gated on BigQuery and LIMIT-capped on both backends.
CLOUD_PROBE_MAX_TABLES = int(os.environ.get("GWS2_CLOUD_PROBE_MAX_TABLES", "2"))
CLOUD_PROBE_MAX_COLUMNS = int(os.environ.get("GWS2_CLOUD_PROBE_MAX_COLUMNS", "6"))
CLOUD_PROBE_MAX_SQL = int(os.environ.get("GWS2_CLOUD_PROBE_MAX_SQL", "8"))
CLOUD_PROBE_SAMPLE_VALUES = int(os.environ.get("GWS2_CLOUD_PROBE_SAMPLE_VALUES", "5"))
CLOUD_PROBE_MAX_GB = float(os.environ.get("GWS2_CLOUD_PROBE_MAX_GB", "2.0"))

# P3: belief-gated selective consensus. Only low-confidence answers trigger extra
# candidates + a majority vote, so simple questions stay single-shot (cost-safe).
CLOUD_CONSENSUS_CANDIDATES = int(os.environ.get("GWS2_CLOUD_CONSENSUS_CANDIDATES", "2"))
CLOUD_CONSENSUS_TEMPERATURE = float(os.environ.get("GWS2_CLOUD_CONSENSUS_TEMPERATURE", "0.7"))
CLOUD_CONSENSUS_MIN_ROWS = int(os.environ.get("GWS2_CLOUD_CONSENSUS_MIN_ROWS", "2"))
