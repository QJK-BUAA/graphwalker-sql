"""Schema extraction from a SQLite database.

Produces a dialect-agnostic ``Schema`` holding tables, columns, types, declared
foreign keys and lightweight per-column statistics (distinct count, null count,
approximate uniqueness). The statistics feed the white-box belief scores in
``belief.py`` (uniqueness -> "looks like a key", value hits -> filter values).
"""
from __future__ import annotations

import sqlite3
from dataclasses import dataclass, field


@dataclass
class Column:
    name: str
    type: str
    pk: bool = False
    # Filled lazily by ``collect_column_stats``.
    n_distinct: int | None = None
    n_rows: int | None = None
    n_null: int | None = None

    @property
    def uniqueness(self) -> float:
        """Distinct / non-null rows in [0, 1]; ~1.0 means key-like."""
        if not self.n_rows:
            return 0.0
        denom = self.n_rows - (self.n_null or 0)
        if denom <= 0:
            return 0.0
        return min(1.0, (self.n_distinct or 0) / denom)


@dataclass
class ForeignKey:
    src_table: str
    src_column: str
    ref_table: str
    ref_column: str

    def undirected_key(self) -> tuple:
        return tuple(sorted([self.src_table, self.ref_table]))


@dataclass
class Schema:
    name: str
    tables: dict[str, list[Column]] = field(default_factory=dict)
    declared_fks: list[ForeignKey] = field(default_factory=list)
    raw_ddl: dict[str, str] = field(default_factory=dict)

    @property
    def has_declared_fks(self) -> bool:
        return len(self.declared_fks) > 0

    def table_names(self) -> list[str]:
        return list(self.tables.keys())

    def column(self, table: str, column: str) -> Column | None:
        for c in self.tables.get(table, []):
            if c.name.lower() == column.lower():
                return c
        return None

    def to_ddl_text(self, tables: list[str] | None = None) -> str:
        names = tables if tables is not None else self.table_names()
        chunks = []
        for t in names:
            if t not in self.tables:
                continue
            if self.raw_ddl.get(t):
                chunks.append(self.raw_ddl[t].strip().rstrip(";") + ";")
            else:
                cols = ",\n    ".join(f'"{c.name}" {c.type}' for c in self.tables[t])
                chunks.append(f'CREATE TABLE "{t}" (\n    {cols}\n);')
        return "\n\n".join(chunks)

    def compact_text(self, tables: list[str] | None = None) -> str:
        names = tables if tables is not None else self.table_names()
        lines = []
        for t in names:
            cols = ", ".join(f"{c.name}:{c.type}" for c in self.tables.get(t, []))
            lines.append(f"{t}({cols})")
        return "\n".join(lines)


def extract_schema(sqlite_path: str, name: str | None = None) -> Schema:
    con = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
    cur = con.cursor()
    schema = Schema(name=name or sqlite_path.split("/")[-1].replace(".sqlite", ""))

    rows = cur.execute(
        "SELECT name, sql FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%'"
    ).fetchall()
    for tname, tsql in rows:
        schema.raw_ddl[tname] = tsql or ""
        cols: list[Column] = []
        for _cid, cname, ctype, _nn, _dflt, pk in cur.execute(
            f'PRAGMA table_info("{tname}")'
        ):
            cols.append(Column(name=cname, type=(ctype or "TEXT").upper(), pk=bool(pk)))
        schema.tables[tname] = cols

        for fk in cur.execute(f'PRAGMA foreign_key_list("{tname}")'):
            ref_table, from_col, to_col = fk[2], fk[3], fk[4]
            if to_col is None:
                pkcols = [c.name for c in schema.tables.get(ref_table, []) if c.pk]
                to_col = pkcols[0] if pkcols else from_col
            schema.declared_fks.append(
                ForeignKey(src_table=tname, src_column=from_col,
                           ref_table=ref_table, ref_column=to_col)
            )
    con.close()
    return schema


def collect_column_stats(sqlite_path: str, schema: Schema,
                         max_tables: int = 60, timeout: float = 15.0) -> None:
    """Populate n_rows / n_distinct / n_null for each column (best-effort).

    Bounded so it stays cheap on large schemas; failures leave stats as None,
    in which case belief scoring falls back to name-only signals.
    """
    import threading
    con = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
    timer = threading.Timer(timeout, con.interrupt)
    timer.start()
    try:
        cur = con.cursor()
        for i, (tname, cols) in enumerate(schema.tables.items()):
            if i >= max_tables:
                break
            try:
                n_rows = cur.execute(f'SELECT COUNT(*) FROM "{tname}"').fetchone()[0]
            except Exception:  # noqa: BLE001
                continue
            for c in cols:
                c.n_rows = n_rows
                try:
                    c.n_distinct = cur.execute(
                        f'SELECT COUNT(DISTINCT "{c.name}") FROM "{tname}"'
                    ).fetchone()[0]
                    c.n_null = cur.execute(
                        f'SELECT COUNT(*) FROM "{tname}" WHERE "{c.name}" IS NULL'
                    ).fetchone()[0]
                except Exception:  # noqa: BLE001
                    c.n_distinct = c.n_null = None
    finally:
        timer.cancel()
        con.close()
