# GraphWalker-AutoLink v3 改进说明

## 之前是否改进过

是。此前已经实现过一版简化 AutoLink：

- BGE-small 列向量检索；
- local top-50 / cloud top-40 初始 schema；
- 5–6 轮 ReAct schema agent；
- value examples；
- LinkAlign irrelevant-column isolation；
- 3 候选执行投票；
- 最多 2–3 轮 repair/refine。

这套组合将 Spider2 local135 从 27.41% 提升到 40.00%，但 full547 cloud 仍
主要使用旧 online adapter，因此 full547 只有 17.73%。

## v3 新增能力

### 高召回 schema

当前 benchmark runner 可直接读取官方 AutoLink 发布的 547 份 linked schema
prompt。这些 prompt 来自：

- BGE-large；
- top-100 初检；
- ID/name/code 自动扩展；
- 最多 10 轮 schema exploration；
- BigQuery nested columns；
- similar partition tables；
- sample values 与 external knowledge。

官方 prompt 平均约 155 列；此前 GraphWalker cloud 平均约 53 列。

### 官方级 SQL 栈

新增 `gws2/autolink_v3.py`：

- 5 个独立 DeepSeek Reasoner 候选；
- seed=None，保留候选多样性；
- 每个执行失败/空候选最多 5 轮多轮 revision；
- Snowflake 自动引用 fallback；
- BigQuery dry-run 5GB 成本护栏；
- 结果列向量等价聚类；
- 最大一致性 cluster；
- cluster 平局时 Reasoner 两两裁决；
- API 网络重试有上限，不会像官方代码无限卡住。

### 可恢复评测

新增 `run_graphwalker_autolink_v3.py`：

- ID / prefix / sample 选择；
- 逐题 checkpoint；
- `--resume` 仅重试失败或缺失题；
- BigQuery/Snowflake credential override；
- 官方 Spider2 evaluator；
- 完整候选、revision、selection 和 token 元数据。

### 基础设施

- `LLM.complete_messages()` 支持多轮 revision；
- cloud credential 支持环境变量覆盖；
- evaluator 使用当前运行指定的凭证。

## 验证结果

### Smoke

| 样本 | 结果 | 行为 |
|---|---:|---|
| local004 | 1/1 | 5候选全部一致，无 revision |
| sf_bq213 | 1/1 | 3候选触发修复，共4轮，最终5候选一致 |

### 固定 cloud12 A/B

| 方法 | 正确数 | EX |
|---|---:|---:|
| 旧 GraphWalker cloud | 3/12 | 25.00% |
| GraphWalker-AutoLink v3 | 5/12 | 41.67% |
| 官方仓库脚本复现 | 6/12 | 50.00% |

v3 相比旧管线提升 16.67 个百分点；与官方脚本相差 1 题，属于小样本与模型
采样波动范围。

本轮 v3 cloud12：

- 60 个候选中 53 个最终可执行；
- 26 个候选进入 revision；
- 总 revision 轮次 83；
- Snowflake quote fallback 触发 13 次；
- 146 次 LLM 调用；
- 约 240 万输入+输出 token；
- 总耗时约 65 分钟。

## 当前限制

1. v3 默认使用 AutoLink 发布的 Spider2 linked prompts，属于 benchmark adapter；
   新数据库仍需运行动态 BGE-large + schema-agent 链。
2. 5 候选和 5 轮 revision 成本很高，不适合作为所有业务查询的默认路径。
3. 结果聚类最多读取 1000 行，超大结果集可能产生近似误差。
4. 当前 cloud12 样本较小；尚未在新的 GraphWalker runner 上重跑 cloud50。
5. 官方榜单 52.28% 对应配置未公开，v3 对齐的是论文/公开代码 34.92% 路径。

## 使用方式

```bash
python3 -u run_graphwalker_autolink_v3.py \
  --ids bq076,bq009,sf_bq033,sf_bq341 \
  --workers 2 \
  --candidates 5 \
  --revisions 5 \
  --tag example \
  --bq-credential /path/to/bigquery.json \
  --sf-credential /path/to/snowflake.json
```

中断后追加 `--resume` 即可续跑。

## 后续建议

1. 以固定 cloud50 做正式回归，而不是立即跑 full547；
2. 将动态 BGE-large/top100/add_id/nested expansion 迁回 GraphWalker；
3. 增加 belief gate：简单题减少候选，复杂题保留完整 5-candidate stack；
4. 对 selection 漏选正确候选的问题训练或设计更可靠的结构化 judge；
5. 保留 GraphWalker 的成本护栏、bounded retry 和 checkpoint，不照搬官方工程缺陷。
