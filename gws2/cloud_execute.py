"""Cloud SQL execution with cost guards (P1: remote bounded belief repair).

The local Commit loop executes generated SQL against SQLite and repairs on
error/empty. For Spider2-Lite cloud backends we mirror that loop against
BigQuery / Snowflake, but with strict cost protection so a bad generated query
cannot run up cloud spend:

  * BigQuery: a *dry run* first estimates bytes scanned; if it exceeds
    ``BQ_DRYRUN_MAX_GB`` the query is refused (returned as an error the repair
    step can react to) instead of executed.
  * both backends: row cap + timeout, read-only single statement.

Credentials are loaded lazily from ``config.SPIDER2_CRED_DIR`` and never copied
into the repo. Connections are cached per-thread-safe lock by the caller.
"""
from __future__ import annotations

import json
import os
import threading
from dataclasses import dataclass, field
from pathlib import Path

from . import config


@dataclass
class CloudResult:
    ok: bool
    columns: list[str] = field(default_factory=list)
    rows: list = field(default_factory=list)
    n_shown: int = 0
    error: str = ""
    est_gb: float | None = None       # BigQuery dry-run estimate, if available
    skipped_cost: bool = False        # refused due to cost guard


def _cred(name: str) -> Path:
    return Path(config.SPIDER2_CRED_DIR) / name


# --------------------------------------------------------------------------- #
# BigQuery
# --------------------------------------------------------------------------- #
def _bq_client():
    from google.cloud import bigquery
    from google.oauth2 import service_account
    cred = service_account.Credentials.from_service_account_file(
        str(_cred("bigquery_credential.json")))
    return bigquery.Client(credentials=cred, project=cred.project_id)


def bigquery_dry_run_gb(sql: str) -> tuple[float | None, str]:
    """Return (estimated_gb, error). estimated_gb is None on failure."""
    try:
        from google.cloud import bigquery
        client = _bq_client()
        job = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True,
                                                                   use_query_cache=False))
        gb = job.total_bytes_processed / (1024 ** 3)
        return gb, ""
    except Exception as e:  # noqa: BLE001
        return None, str(e)


def run_bigquery(sql: str, max_rows: int = config.CLOUD_EXEC_MAX_ROWS,
                 max_gb: float = config.BQ_DRYRUN_MAX_GB,
                 timeout: float = config.CLOUD_EXEC_TIMEOUT) -> CloudResult:
    est_gb, dry_err = bigquery_dry_run_gb(sql)
    if est_gb is None:
        # dry run itself failed => query is invalid; surface as an error so the
        # repair loop can fix syntax/identifier problems without spending money.
        return CloudResult(ok=False, error=f"dry-run failed: {dry_err}")
    if est_gb > max_gb:
        return CloudResult(ok=False, est_gb=est_gb, skipped_cost=True,
                           error=(f"cost guard: query would scan {est_gb:.2f} GB "
                                  f"> limit {max_gb:.2f} GB; refused"))
    try:
        client = _bq_client()
        job = client.query(sql)
        it = job.result(timeout=timeout)
        cols = [f.name for f in it.schema]
        rows = []
        for i, row in enumerate(it):
            if i >= max_rows:
                break
            rows.append(tuple(row.values()))
        return CloudResult(ok=True, columns=cols, rows=rows, n_shown=len(rows),
                           est_gb=est_gb)
    except Exception as e:  # noqa: BLE001
        return CloudResult(ok=False, est_gb=est_gb, error=str(e))


# --------------------------------------------------------------------------- #
# Snowflake
# --------------------------------------------------------------------------- #
_SF_CONN = None
_SF_LOCK = threading.Lock()


def _sf_conn():
    global _SF_CONN
    if _SF_CONN is None:
        import snowflake.connector
        cfg = json.load(open(_cred("snowflake_credential.json")))
        _SF_CONN = snowflake.connector.connect(**cfg)
    return _SF_CONN


def run_snowflake(sql: str, database: str | None = None,
                  max_rows: int = config.CLOUD_EXEC_MAX_ROWS,
                  timeout: float = config.CLOUD_EXEC_TIMEOUT) -> CloudResult:
    # A single Snowflake connection/cursor is not safe for concurrent execute,
    # so serialize Snowflake queries across worker threads.
    try:
        with _SF_LOCK:
            conn = _sf_conn()
            cur = conn.cursor()
            try:
                cur.execute(f"ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = {int(timeout)}")
            except Exception:  # noqa: BLE001
                pass
            # The shared credential has no default database, so set it per query
            # (the Spider2-Lite instance db_id is the Snowflake database name).
            if database:
                try:
                    cur.execute(f'USE DATABASE "{database}"')
                except Exception as e:  # noqa: BLE001
                    return CloudResult(ok=False, error=f"USE DATABASE failed: {e}")
            try:
                cur.execute(sql)
                cols = [d[0] for d in cur.description] if cur.description else []
                rows = cur.fetchmany(max_rows)
                return CloudResult(ok=True, columns=cols,
                                   rows=[tuple(r) for r in rows], n_shown=len(rows))
            finally:
                cur.close()
    except Exception as e:  # noqa: BLE001
        return CloudResult(ok=False, error=str(e))


def run_cloud(backend: str, sql: str, database: str | None = None) -> CloudResult:
    if backend == "bigquery":
        return run_bigquery(sql)
    if backend == "snowflake":
        return run_snowflake(sql, database=database)
    return CloudResult(ok=False, error=f"unknown backend {backend}")


def close_cloud() -> None:
    global _SF_CONN
    if _SF_CONN is not None:
        try:
            _SF_CONN.close()
        except Exception:  # noqa: BLE001
            pass
        _SF_CONN = None
