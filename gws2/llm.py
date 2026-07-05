"""Thin OpenAI-compatible LLM wrapper with call/token accounting.

GraphWalker-SQL 2.0 is training-free: the LLM is used only for lightweight,
white-box decisions (joinability discovery, source/destination anchoring, path
selection, SQL generation). Any OpenAI-compatible endpoint works; this project
defaults to DeepSeek ``deepseek-chat`` at temperature 0 for determinism.
"""
from __future__ import annotations

import os
import threading
import time

from openai import OpenAI

from . import config


class LLM:
    def __init__(
        self,
        model: str = config.DEFAULT_MODEL,
        base_url: str = config.DEFAULT_BASE_URL,
        api_key_env: str = "DS_API_KEY",
        temperature: float = config.DEFAULT_TEMPERATURE,
        max_retries: int = 4,
        timeout: float = 90.0,
        seed: int | None = config.DEFAULT_SEED,
    ):
        api_key = (
            os.environ.get(api_key_env)
            or os.environ.get("DEEPSEEK_API_KEY")
            or os.environ.get("OPENAI_API_KEY")
        )
        if not api_key:
            raise RuntimeError(
                "No API key found. Set $DS_API_KEY / $DEEPSEEK_API_KEY "
                "(or $OPENAI_API_KEY for an OpenAI endpoint)."
            )
        self.client = OpenAI(base_url=base_url, api_key=api_key, timeout=timeout)
        self.model = model
        self.temperature = temperature
        self.max_retries = max_retries
        self.seed = seed
        self.num_calls = 0
        self.in_tokens = 0
        self.out_tokens = 0
        self._lock = threading.Lock()

    def complete(self, system: str, user: str, temperature: float | None = None) -> str:
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]
        last_err = None
        for attempt in range(self.max_retries):
            try:
                kwargs = dict(
                    model=self.model,
                    messages=messages,
                    temperature=self.temperature if temperature is None else temperature,
                )
                if self.seed is not None:
                    kwargs["seed"] = self.seed
                resp = self.client.chat.completions.create(**kwargs)
                with self._lock:
                    self.num_calls += 1
                    if resp.usage:
                        self.in_tokens += resp.usage.prompt_tokens or 0
                        self.out_tokens += resp.usage.completion_tokens or 0
                return (resp.choices[0].message.content or "").strip()
            except Exception as e:  # noqa: BLE001
                last_err = e
                time.sleep(1.5 * (attempt + 1))
        raise RuntimeError(f"LLM call failed after {self.max_retries} retries: {last_err}")

    def stats(self) -> dict:
        return {
            "num_calls": self.num_calls,
            "input_tokens": self.in_tokens,
            "output_tokens": self.out_tokens,
        }
