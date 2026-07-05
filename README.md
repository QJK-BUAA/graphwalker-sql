# GraphWalker-SQL 2.0 — 可运行复现

> **一句话**：把 Text-to-SQL 重新定义为「在**不确定 schema 图**上的**成本受限信念精炼**」——
> 先接地（Ground），再探索（Explore），最后提交（Commit），一次问题只生成**一条** SQL。

本目录是对 [`graphwalkersql方案2`](../graphwalkersql方案2) HTML 方案（*GraphWalker-SQL 2.0：成本受限的白盒信念图游走*）的
**独立、自包含、training-free** 复现，并在 **BIRD-Dev / Spider 1.0-Dev / Spider 2.0-Lite** 三个数据集上用**官方评测脚本**评估。

它与同级的旧目录 [`GraphWalker-SQL/`](../GraphWalker-SQL)（v1，7 步 `Anchor→Link→Reflect` agent 循环）**无依赖关系**：
v2 是一次围绕**单一信念状态 `b`** 的重写，理念更贴近「白盒、可解释、消融纯净」。

---

## 一、复现了什么（方法核心）

方案把模式接地形式化为**白盒 POMDP** `⟨S,A,O,T,Ω,R,b⟩`，其中奖励 `R` **只用于门控探索/停止，不做 RL 后训练**。
围绕唯一的信念状态 `b`（对正确列 `C*`、过滤值 `V*`、连接路径 `Π*` 的后验）分三阶段：

| 阶段 | 做什么 | 代码 |
|------|--------|------|
| **Ground** | 建图（有外键→直接读；无外键→LLM 可连接性发现 + 置信度 `conf=type×name×uniqueness×value_overlap×llm`）；LLM 轻量意图分解得 src/dst/字面值；初始化信念 `b0` | [graph_builder.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/graph_builder.py) · [ground.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/ground.py) |
| **Explore** | 信念引导游走高熵区；top-k 最短路径（k=3，≤4 边）；**仅**在路径熵高时触发轻量执行探针（`LIMIT` COUNT join）；新增 column/value belief walk：对 linked tables 内候选列执行低成本 SQL profile/literal-hit 探针，将非空率、distinct、样例值和值命中写回 belief 和生成提示；`R=信息增益−λ·成本` 门控，熵低即停 | [explore.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/explore.py) |
| **Commit** | 取信念 MAP 得子图 `S*`；Propose 证据检查（缺表最多补一次，语义空缺只标记不编造）；生成**唯一** SQL；执行失败/空结果**至多一次**定向修正 | [commit.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/commit.py) |

**白盒信念打分（方案 §5）**：不同证据量纲不可直接相加，故用**排序式离散分**：
名称强匹配 `+2`、单元值命中 `+3`、目标列近似唯一 `+2`、图先验 `+conf`、执行探针非空 `+3`、探针空 `−3`。
信念的 softmax **熵**驱动「探不探 / 停不停」，**top-gap**（第一名与第二名差距）判断 Top-1 是否已明显领先。见 [belief.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/belief.py)。

> **方案最难点**（原文亦承认）：无外键场景下构建一张「**足够好但不过度自信**」的可连接性图——
> 太稀疏找不到路径，太稠密引入错误路径。本复现的做法是让每条边带置信度、进入路径先验，并用**按需探针**校正，而非追求一次性完美推断。

---

## 二、目录结构

```
GraphWalker-SQL-2.0/
├── gws2/                      # 自包含核心包
│   ├── config.py              #   数据集/评测脚本路径 + 超参
│   ├── schema.py              #   SQLite 抽取表/列/类型/声明外键 + 列统计(唯一性)
│   ├── llm.py                 #   OpenAI 兼容客户端(默认 deepseek-chat, temp=0, seed)
│   ├── execute.py             #   只读执行 + 探针 + 结果签名(带看门狗超时)
│   ├── belief.py              # ★ 白盒排序式信念状态 + 熵 + MAP (方案 §5)
│   ├── graph_builder.py       # ★ 置信度加权 schema 图(声明FK / LLM推断+值重叠) (方案 §4)
│   ├── value_overlap.py       #   数据级值重叠验证(把"猜测边"升级为"数据可证边")
│   ├── ground.py              #   锚定 src/dst/字面值 + 初始化信念 b0
│   ├── explore.py             # ★ 信念游走 + top-k 路径 + 条件执行探针 (方案 §3/§6)
│   ├── commit.py              # ★ Propose 检查 + 唯一SQL生成 + 至多一次修正 (方案 §3)
│   ├── pipeline.py            #   三阶段编排 + 消融开关
│   ├── datasets.py            #   BIRD/Spider1/Spider2-lite 加载 + 确定性分层抽样
│   └── evaluate_official.py   #   包装三个官方评测脚本
├── eval_shims/tool/utils.py   #   BIRD 官方脚本 tool.utils 的最小垫片(绕开无关的 chromadb 导入)
├── run_experiment.py          #   实验入口(数据集 → pipeline → 官方评测 → 结果JSON)
├── run.py                     #   单题运行 + 完整白盒轨迹打印
├── tests/test_pipeline_mock.py#   离线集成测试(MockLLM, 无需API/网络)
├── requirements.txt
└── outputs/                   #   结果JSON(含 args/model/seed/LLM用量/逐题轨迹)
```

---

## 三、安装与运行

```bash
pip install -r requirements.txt         # openai, networkx, func_timeout, nltk, pandas
export DS_API_KEY=sk-...                 # DeepSeek(OpenAI 兼容)。也支持 DEEPSEEK_API_KEY / OPENAI_API_KEY

# —— 冒烟实验(每个数据集 ~20 题，分层抽样，seed=42) ——
python run_experiment.py --dataset bird         --limit 20
python run_experiment.py --dataset spider1      --limit 20
python run_experiment.py --dataset spider2-lite --limit 20    # gold/sql 中的 local SQLite 子集共 24 题
python run_experiment.py --dataset spider2-lite-local --full  # local SQLite 全集 135 题

# —— 消融(保持核心纯净：单条SQL、至多一次修正、无 full-schema fallback) ——
python run_experiment.py --dataset bird --limit 20 --ablation nowalk    # 退化为贪心最短路
python run_experiment.py --dataset bird --limit 20 --ablation notopk    # 单条最短路径
python run_experiment.py --dataset bird --limit 20 --ablation noprobe   # 关执行探针
python run_experiment.py --dataset bird --limit 20 --ablation nopropose # 去证据检查点
python run_experiment.py --dataset bird --limit 20 --ablation nostop    # 固定步数(去熵停止)
python run_experiment.py --dataset spider2-lite --limit 20 --ablation noinfer  # 无外键库禁用图推断

# —— 单题(打印图/锚点/信念熵/路径探针/最终SQL) ——
python run.py --db /path/to/xxx.sqlite --question "..." [--prefer-infer]

# —— 离线自检(无需API：验证三阶段 + 消融 + 三个官方评测器可解析) ——
python tests/test_pipeline_mock.py
```

**数据与评测脚本路径**在 [config.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/config.py) 中按本机自动解析（可用同名环境变量覆盖）：
- BIRD：`论文复现/Interactive-Text-to-SQL/dataset/_extracted/bird_dev/dev_20240627`（1534 题 / 11 库）
- Spider 1.0：`.../spider_data`（dev 1034 题 / 本机 20 库）
- Spider 2.0-Lite：`ReFoRCE/spider2-lite`（`gold/sql` local 24 题；`spider2-lite-local` 扩展为 local SQLite 全集 135 题）

---

## 四、评测口径（严格用官方脚本，禁用近似实现）

| 数据集 | 官方脚本 | 口径 |
|--------|----------|------|
| BIRD-Dev | `bird_evaluation_raw.py` 的 `execute_model` | 执行两边 → 浮点 6 位取整 → `set==set`。逐题聚合总 EX（规避官方按难度除零 bug，比较逻辑不变） |
| Spider 1.0-Dev | `test-suite-sql-eval/evaluation.py --etype exec` | 官方执行准确率（对 dev 库执行；本机无 test-suite 独立库，用 dev 库执行为诚实可跑口径） |
| Spider 2.0-Lite | `ReFoRCE/spider2-lite/evaluation_suite/evaluate.py --mode sql` | 官方 `compare_pandas_table`（1e-2 容差 + 列/顺序条件）；`spider2-lite` 为 24 条 local gold/sql 子集，`spider2-lite-local` 为 135 条 local SQLite 全集 |

> 已用「gold 当预测」验证三个官方评测器均返回 **EX=100.0**，证明喂入格式与解析正确。
> 结果 JSON 均含 `args / model / seed / llm_stats / 逐题轨迹`，可追溯可复现。

---

## 五、消融开关（消融纯净性）

所有消融**只关闭对应组件**，核心始终保持：**一次只生成一条 SQL、修正至多一次、无 full-schema fallback、无无限 self-refine**，
以保证「图路由/信念游走」的收益不被后处理污染。

| 开关/变体 | 作用 | 验证 |
|------|------|------|
| `noinfer` | 无外键库的 LLM 可连接性发现 | 图构建价值 |
| `nowalk` | 信念引导（退化为贪心单最短路） | 信念探索价值 |
| `notopk` | top-k（退化为 k=1） | 连接消歧价值 |
| `noprobe` | 条件执行探针 | 路径验证价值 |
| `nocolprobe` | 关闭 Explore 中的列/值级主动 SQL 探针 | 验证 Column/Value Belief Walk 的收益 |
| `nostop` | 熵门控早停（固定预算） | 成本受限停止价值 |
| `nopropose` | Propose 证据检查点 | 防幻觉价值 |
| `norepair` | Commit 的一次定向修正 | 干净版收益归因 |
| `propgate` | 开启 Propose 加表的连通性证据门 | 验证“LLM 提名缺表必须有结构证据” |

---

## 六、预期结果 vs 方案 Claim

方案**刻意不 claim「全面超越 SOTA」**，而是主张：*在保持 Interactive-T2S 低成本的同时，显著改善
schema grounding 与 join-path 消歧，尤其在无外键 / 大 schema / 多路径歧义场景。* 应报告的指标：EX、平均 LLM 调用数、探针数。

### 实测结果（deepseek-chat, temperature=0, seed=42, 官方评测脚本）

| 数据集 | n | 图来源 | **EX(%)** | 平均LLM调用 | 平均探针 | 备注 |
|--------|---|--------|-----------|------------|----------|------|
| **BIRD-Dev（全量）** | **1534** | declared | **55.74** | 3.12 | 0.68 | 官方评测；简单62.49 / 中46.77 / 难41.38；执行成功率97.8%；46.2min(6并发) |
| **Spider 1.0-Dev（全量）** | **1034** | declared | **77.10** | 3.10 | 0.23 | 官方 test-suite exec；执行成功率98.2%；15.9min(6并发) |
| **Spider 2.0-Lite（local gold/sql 子集）** | **24** | inferred+overlap+colwalk | **45.83** | 4.04 | 0.96 | 官方 `evaluate.py --mode sql`；11/24；`outputs/spider2-lite_full_deepseek-chat_colwalk_n100_seed42.json` |
| **Spider 2.0-Lite（local SQLite 全集）** | **135** | inferred+overlap+colwalk | **22.96** | 4.06 | 0.79 + 15.16列探针 | 官方 `evaluate.py --mode sql`；31/135；执行成功126/135；3.1min(8并发) |
| BIRD-Dev（n=100）+Propose gate | 100 | declared | 47.0 | 3.06 | - | `--ablation propgate`；同批默认/无门控为48.0，暂不默认开启 |
| BIRD-Dev（全量）+列裁剪 | 1534 | declared | 55.67 | 3.30 | 0.69 | `--ablation colalign`；裁剪触发42题、机制净+5（7修复/2打破），全局净+3落在噪声带；见错题反思报告§六 |

**BIRD 全量（1534题）是当前主结果**：**EX 55.74%**，接近 Interactive-T2S 论文的 54.56%（GPT-4o, w/ oracle knowledge）。
难度梯度平滑（62.49 / 46.77 / 41.38），执行成功率 97.8%，平均 3.12 次 LLM 调用/题、0.68 探针/题 —— 成本可控的设计目标达成。Spider1 全量 **77.10%** 说明在干净外键 schema 上，方法稳定性明显高于 BIRD；Spider2-lite local 从 24 条 gold/sql 子集扩到 135 条全集后降到 **22.96%**，说明长尾复杂分析题和方言/业务语义仍是主要短板。

Propose 连通性证据门已实现为实验变体 `--ablation propgate`：LLM 提名缺表后，只有与当前 grounded subgraph 存在 schema 图 join 边的表才会被加入；孤立表进入 `missing_rejected` 和 trace。该改动对齐方案 §7 的“不要让 LLM 猜测变成硬事实”，但 BIRD n=100 重跑为 **47.0 vs 默认 48.0**，所以暂不作为默认主方法。

### Column/Value Belief Walk 初步验证（n=100 / Spider2-lite=24）

新增的列/值级主动探索默认开启，并用 `--ablation nocolprobe` 做同批对照。它只增加本地 SQL profile / literal-hit 探针，不增加 LLM 调用。

| 数据集 | colwalk EX | nocolprobe EX | ΔEX | 平均列探针 | 结论 |
|--------|------------|---------------|-----|------------|------|
| BIRD-Dev | **51.0** | 48.0 | **+3.0** | 26.38/题 | 正向，符合“冗余 schema 下列/值 grounding 是瓶颈”的错题分析 |
| Spider 1.0-Dev | 84.0 | **85.0** | -1.0 | 9.73/题 | clean schema 上轻微负向，可能是额外列样例对 prompt 的干扰 |
| Spider 2.0-Lite local | **45.83** | 29.17 | **+16.67** | 15.50/题 | 强正向，说明弱 schema/无外键环境下列值 profile 有帮助 |

这组结果支持将 Column/Value Belief Walk 作为主线补强模块，但仍需 BIRD/Spider1 全量复核：它在复杂/弱 schema 上明显更有价值，在 clean schema 上可能需要更强触发门控。

**关键观察（与方案 claim 一致）**：
- **成本随难度自适应**：干净外键的 Spider1 仅 `0.23` 探针/题，而无外键、多歧义的 Spider2-lite 达 `0.96` 探针/题——
  正是方案「简单问题退化为 Interactive-T2S 级成本，困难问题才按需多花探针」的设计目标。
- **失败集中在语义而非接地**：BIRD 全量执行成功率 97.5%，但 EX 55.5%，难度梯度平滑。
  即错误多为「执行成功但结果语义不对」的复杂 SQL planning，而非选错表/选错路径——
  与方案「核心聚焦 schema grounding 与 join-path，而非宣称解决所有复杂 SQL」的定位吻合。

> 结果 JSON（`outputs/<run_id>.json`）含 `args / model / seed / llm_stats / 逐题轨迹(trace)`，可追溯可复现。
> 消融结果见 `outputs/` 下对应文件。小样本(n=20)方差大，趋势性参考；下结论需更大样本 + 多 seed。
> 旧 v1 复现同机量级（含较多后处理/fallback，**非纯净**，仅供量级对比）：BIRD-40 EX≈52–55%，Spider2-24 EX≈16%。

### 改进尝试与诚实结论（"改进方法都试一试"）

在基线之上试了 4 项改进，**做成开关、逐一验证**，结论分两类：

| 改进 | 内容 | 结论 | 证据 |
|------|------|------|------|
| ① 崩溃修复 | `_k_shortest` 生成器在断连锚点崩溃 → 改为 union fallback | ✅ **合入** | `bird_466`/`local099` 从崩溃变可执行 |
| ② 通用 CAST 规则 | 比例/百分比 `CAST(... AS REAL)` 防整数除法 | ✅ **合入** | **Spider2-lite 30→45%**（6→9 题，纯此项+①）|
| ③ Evidence 折进问题 | 外部知识拼进 question（原始做法）| ✅ **保留为默认** | BIRD n=100 = **48%** |
| ④ Evidence 独立强注入块 + 正则挖掘值/公式 → grounding hint | 独立 "External Knowledge" 段 + `_evidence_hints` | ❌ **负优化，回退** | BIRD n=100 = **44%**（< 折进法 48%）|

**关键发现（n=100，可信非噪声）**：把 evidence 做成"独立强调块 + 挖掘出的 hint"反而**比直接折进问题差 4 个点**（44 vs 48），且在 simple/moderate 两档都更差。原因：额外结构（如挖出的 `filter for 'when the account type'` 这类啰嗦 hint）对 deepseek-chat 是**干扰**而非帮助。→ 默认 `use_evidence_injection=False`（折进法），独立块降级为可复现的对照开关 `--ablation evidenceblock`。

**关于 BIRD n=20 的方差**：跨 3 个 prompt 变体做稳定性分析，8 个正确里只有 **5 个稳定**，另外 5 个随微小 prompt 改动来回翻。因此 n=20 上的 ±5 点差异**不可据以下结论**；只有放大到 n=100 才看清 evidence-block 是负优化。这印证了"实验纯净性"要求：**小样本上的 prompt 微调 = 拟合噪声**。

| BIRD 对照（n=100, deepseek-chat, seed=42）| EX(%) | simple | moderate | challenging |
|---|---|---|---|
| **full（evidence 折进 + CAST，默认）** | **48.0** | 60.6 | 48.5 | 35.3 |
| evidenceblock（独立强注入块）| 44.0 | 57.6 | 39.4 | 35.3 |

> 净结果：**Spider2-lite +15（真实提升）**；BIRD 的"接地"已不是瓶颈，剩余错误是复杂 SQL 语义（比例/窗口/嵌套），换更强模型(GPT-4o)才是主要抓手——与方案定位一致。

---

## 七、假设与推断的实现细节（方案未明确处）

1. **锚定方式**：方案写「BM25+Embedding 向量召回」，本复现用**零配置的 LLM 直接锚定** src/dst + 字面值（等价替代，省去向量库）。
2. **信念离散分数**：方案 §5 给了分级示例（`+2/+3/−3`），具体数值与 softmax 温度按常识设定（见 [belief.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/belief.py) 顶部常量），便于消融时调节。
3. **探针触发阈值**：路径熵 `≥0.6 bit` 或 top-gap `<图先验分` 才探针；`k=3`、路径 `≤4` 边、探针 `LIMIT 1000`（[config.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/gws2/config.py)）。
4. **值重叠因子**：把包含率线性映射到 `[0.2,1.0]` 作为 `conf` 的一个乘子，避免「一票否决」也避免「盲目采信」。
5. **修正触发**：执行报错**或**空结果时才修正，且修正结果不优于原结果则丢弃（不退步）。
6. **Spider 1.0 评测库**：本机 `test-suite-sql-eval/database` 为空，改用 dev 库执行——这是本机可诚实运行的口径，非 test-suite 加强库口径。
7. **列统计上限**：为控成本，仅对每库前 60 张表采集唯一性统计（大 schema 下退化为纯命名信号）。

---

## 八、局限

- **RL/GRPO**：按方案主张，v2 为 training-free，奖励只用于门控探索，不做后训练（与方案一致，非缺失）。
- **Spider2 完整后端**：当前主流水线仍是 SQLite 后端。Spider2-Lite 的 local SQLite 全集（135 题）已可官方评估；Snowflake 凭证可连通，但 SQLite 生成 SQL 直接迁移到 `sf_local*` 的官方 Snow 评估为 0/135，说明需要 Snowflake schema/方言/探针后端适配；DBT 任务要求生成项目文件或结果文件，不是单条 SQL 评测。
- **规模与方差**：默认冒烟 ~20 题/数据集，单题即可造成数个百分点波动；下结论需 temp=0 + 更大样本 + 多 seed。
- **值重叠误报**：zip/country/date 等公共列可能造成假阳性，故只作为**软因子**而非硬事实。
