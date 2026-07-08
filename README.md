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
| `noconcept` | 关闭 Query-Centric Concept Alignment（默认开启，但受图门控） | 验证「以 query 为核心的 concept→列 消歧」的收益 |
| `noadaptive` | 关闭置信度自适应 schema 扩窗（默认开启，但受图门控） | 验证「不确定时给生成端更多候选表」的收益 |
| `hardstruct` | 恢复 skeleton 不匹配即强制 repair 的硬门（默认软提示，但受图门控） | 验证「软化结构约束、留试错空间」的收益 |
| `nogate` | 关闭「按图类型自适应门控」，把三项改进用到**所有库**（含声明外键） | 复现「在 BIRD 上也开三项」的行为 |

> **按图类型自适应门控（默认，`gate_by_graph`）**：上述三项改进只在**推断图（无外键 / 接地是瓶颈，Spider2 类）**上生效；
> 在**声明外键图（BIRD 类，接地已解决）**上自动关闭、退回紧约束 + 硬骨架。判据是可观测的**每题信号**（图是否为 inferred），
> 而非数据集名字。实测依据见 [CONCEPT_ADAPTIVE_EXPERIMENT_REPORT.md](CONCEPT_ADAPTIVE_EXPERIMENT_REPORT.md)：
> 三项在 Spider2-lite local **+8.3 EX**，在 BIRD **−2 EX**——门控后 BIRD 回到基线、Spider2 保留增益。

> **新增两项改进（针对错题分析中「表对列错 / 强约束不可恢复」两大瓶颈）：**
> 1. **Query-Centric Concept Alignment（`gws2/concept_align.py`，Point 1）**：Ground 阶段把问题分解为 concept，
>    对每个 concept 在候选列上做**白盒信念竞争**（词面 + 表锚定先验 + 类型契合 + **字面值命中** + 唯一性），
>    把 `concept→列` 绑定写回 belief 并作为生成提示。值命中是决定性证据——例如 `county=Fresno` 会被绑定到
>    `frpm.County Name` 而非 `schools.County`，直接对治「同概念多表选错」。每题 +1 次 LLM 调用（concept 抽取）+ 受上限约束的本地值探针。
> 2. **置信度自适应约束（`gws2/commit.py`，Point 2）**：信念**高置信**时保持紧约束（只暴露 MAP 子图）；
>    **低置信**（Propose 判缺表 / 锚点不连通 / 列或路径熵高）时把 1-hop 图邻居作为**可选候选表**注入生成上下文，
>    让模型有机会修正漏表；同时 skeleton 由「硬 repair 门」降级为「软提示」，只有执行失败/空结果才触发 repair。
>
> 对照实验（均需 n≥100 + 逐题 diff 验证净收益，并观察错误类型迁移）：
> ```bash
> python run_experiment.py --dataset bird --limit 100                 # full（含两项改进，默认）
> python run_experiment.py --dataset bird --limit 100 --ablation noconcept
> python run_experiment.py --dataset bird --limit 100 --ablation noadaptive
> python run_experiment.py --dataset bird --limit 100 --ablation hardstruct
> ```

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

### Structure-Aware Commit 初步验证（Spider1 n=100）

针对 Spider1 hard/extra 中集合操作、嵌套、GROUP/HAVING、ORDER/LIMIT、SELECT 形状等复杂 SQL 结构错误，Commit 阶段新增 query skeleton planning：先预测 `set_op / nested / group_by / order_by / limit / select_arity / aggregation`，再把 skeleton 注入 SQL 生成 prompt，并在结构不匹配时触发一次定向 repair。

| 数据集 | 旧 full/colwalk | +Structure-Aware Commit | ΔEX | 说明 |
|--------|-----------------|-------------------------|-----|------|
| Spider 1.0-Dev n=100 | 84.0 | **87.0** | **+3.0** | 同 seed=42 分层样本；5 题修复 / 2 题回退 |

主要修复来自 SELECT arity 和聚合输出形状，例如去掉多余辅助列、按 skeleton 保持单列输出。主要回退来自 skeleton 对 `EXCEPT` 或 nested 的偏好与官方执行等价口径不完全一致。该模块默认开启，并可用 `--ablation nostruct` 关闭。

进一步只在 Spider1 官方 hardness 为 `hard` / `extra` 的 340 条复杂样本上做压力测试：

| 子集 | 旧 full | +Structure-Aware Commit | ΔEX |
|------|---------|-------------------------|-----|
| Spider 1.0 hard+extra (n=340) | 61.76 | **67.40** | **+5.64** |
| hard (n=174) | 66.67 | **75.86** | **+9.19** |
| extra (n=166) | 56.63 | **59.04** | **+2.41** |

逐题 diff：47 题修复、27 题回退，净 +20。主要修复来自 `INTERSECT`、`NOT IN`、SELECT arity、聚合输出形状和 code-fence 清理；主要回退来自 skeleton 过度偏好 `EXCEPT` / nested，或将等价的 `ORDER BY ... LIMIT` 改写为 subquery 后在 test-suite 多数据库执行下不等价。

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
- **Spider2 完整后端**：当前主流水线仍以 SQLite 后端为主。已新增 `run_spider2lite_online.py` 作为 Spider2-Lite mixed-backend adapter：local 走 GraphWalker-SQL，BigQuery/GA/Snowflake 读取 Spider2 DDL 资源并生成对应方言 SQL，再交给官方 `evaluate.py --mode sql`。

  **P0 云端置信度图 Schema 压缩（借鉴 ReFoRCE database compression）**：新增 `gws2/online_schema.py`，对云端大 schema（BigQuery/Snowflake 单库常 140+ 表）用白盒置信度打分 `conf = 3·name + 2·column + 1·desc + 1.5·ek`（token 重叠，零 LLM 成本）排序取 Top-N，替代旧版盲取前 20 表 + 截断 24k 的做法。零成本消融证实其价值：143 表的 `nhtsa_traffic_fatalities` 上，旧截断把目标表 `accident_2015` 完全丢出前 36 表，新压缩将其排进 Top-8。
  - 线上 smoke（local/bq/ga/sf 各 1 条，旧版）：EX=25.0（1/4）。
  - P0 mixed n=20（local/bq/ga/sf 各 5 条）：EX=15.0（3/20，BigQuery 1/10、Snowflake 0/5、local 2/5）。剩余错误以 SQL 语义为主（如 `sf_bq029` 应按 filing_year 5 年分桶、输出列形状不符），属 P1 有界信念纠错 / P3 选择性共识 的改进范围，非 schema 接地问题。

  **P1 云端有界信念纠错（借鉴 ReFoRCE self-refinement，但保持有界）**：新增 `gws2/cloud_execute.py`，把本地 Commit 的 execute→feedback→repair 闭环接到 BigQuery/Snowflake，`generate_online_sql` 在生成后真实执行、失败/空/超成本则定向修复，**至多 2 次**且非退步才保留（`--no-repair` 可消融）。关键成本护栏：BigQuery 先 dry-run 估算扫描字节，超过 `BQ_DRYRUN_MAX_GB`（默认 5GB）直接拒绝执行（实测 11.26GB 的列扫描被拦截，零花费）；Snowflake 加 `USE DATABASE` + 会话超时 + 线程锁串行化。
  - 顺带修复 Snowflake 致命 bug：共享凭证无默认 database，导致所有 sf 查询报 `does not have a current database`；改为按 `db_id` 执行 `USE DATABASE` 后，`PATENTS.PUBLICATIONS` 等可正常查询。
  - P1 mixed n=20：**EX=25.0（5/20）**，较 P0 的 15.0 净 +10。递进：P0 15.0 → P1（含修复闭环）20.0 → P1+Snowflake 修复 25.0。触发 6 次云端修复，其中 `bq002`（dry-run 失败→修好）、`sf_bq099`（日期解析报错→修好出 2 行）为有效恢复。Snowflake 从 0/5 全废变为可执行（`sf_bq029` 出 13 行），剩余为语义不符（P2/P3 范围）。

  **P2 云端远程信念探针（借鉴 ReFoRCE column exploration）**：新增 `gws2/cloud_probe.py`，把本地 Column/Value Belief Walk 搬到云端——对 P0 选出的 Top 表，挑与问题/EK token 重叠（含单复数 stemming）的候选列，用 dry-run 卡成本的小样本查询采样列值 + 字面值命中，把"活取"证据注入生成 prompt。`gws2/online_schema.py` 增加 DDL→FQN/列解析。硬护栏：≤2 表、≤6 列、≤8 SQL/题、单探针 ≤2GB、`--no-probe` 可消融。
  - 关键教训（一次真实回退→修复）：首版探针**净负优化**（EX 20.0，`bq001` 被探针噪声带偏——它去采样 GA 的 `ga_sessions_YYYYMMDD` 分片表，flat 采样无法表达 `totals.*` 嵌套字段，反而让模型丢了 `totals.visits=1` 逻辑）。修复：**探针必须只给信号不给噪声**——跳过 `_YYYYMMDD` 日期分片表、只回灌列名与问题 token 重叠的列。改后 `bq001` 恢复且新增 `sf_ga004`。
  - P2 mixed n=20：**EX=30.0（6/20）**，较 P1 的 25.0 再 +5。递进：P0 15.0 → P1 25.0 → P2 30.0。BigQuery 逐阶段 1/10 → 4/10。探针 SQL 从噪声版 36 降到 14（跳分片）。Snowflake 仍 0/5（PATENTS 语义复杂，属 P3 共识范围）。

  **P3 信念门控选择性共识（借鉴 ReFoRCE majority vote，但按信念门控以保成本）**：新增 `gws2/cloud_consensus.py`：结果集签名比对（数值 1e-2 容差、忽略行序/列序，自包含不依赖 ReFoRCE utils）+ 多数票。只有**低信念**答案（未执行 / 空结果 / 触发过 repair）才追加候选并投票，高信念答案单发，守住成本自适应。默认关闭，`--consensus` 开启。
  - **诚实的负结果 + 关键方差发现**：n=20 上 `--consensus` 触发 15 次（松门控）或 9 次（紧门控），均**未提升 EX**，且成本翻倍（LLM 调用 52→81）。进一步用**同一份代码跑两次**（均无 consensus）得到 30.0 与 20.0——`bq002` 等题在 `temperature=0` 下仍因 deepseek-chat/云端**运行间不确定性**翻盘（rows 1→0）。即 **n=20 存在约 ±10 EX 的噪声带**，P3 的效应落在噪声带内，无法据此判定为增益。
  - 结论：P3 已实现且设计上成本自适应（共识只理论上帮"执行层"，实测 adopt 过 `sf_bq026/sf_bq033` 从不可执行变可执行），但在当前规模/模型下**效应不可与噪声区分**，故**默认关闭**，公平评估需更大样本 + 多 seed。P0→P1→P2 的递进（15→25→30）幅度大于噪声带，是可信信号；P3 不作为默认主方法。

  **扩规模复核（先 n=60 确认信号再上全量）**：n=20 结论方差过大，故按 bq/ga/sf/local 各 15 取 **mixed n=60**（样本固定、跨运行一致）做对照：
  - P2 默认跑两次：**16.67（10/60）与 21.67（13/60）** → n=60 噪声带收敛到约 **±2.5 EX**（远小于 n=20 的 ±10）。
  - P1（`--no-probe`）同样本：**20.0（12/60）**，落在 P2 噪声带内。
  - 逐题：**10 题在 P2 两跑中稳定正确**（bq002/bq210-213/bq247/ga001/ga004/ga017/local004），P2 额外独解 `bq001`，**P1 没有任何 P2 漏掉的独解**——即 P2 相对 P1 是"中性偏弱正、从不更差"，聚合差异被噪声淹没。
  - 系统性缺口在 **Snowflake（0 正确）**：n=60 的 15 条 sf 恰好全是 PATENTS/PATENTS_GOOGLE（重分析型），10/15 能执行但语义全错——这才是短板，而非 P2-vs-P1。
  - 决策：n=60 已跨过噪声、确认信号；全量 547 成本可控（约 1400 次 LLM 调用 / ~1 小时 / ~30GB），值得一次干净全量。

  **全量 547 headline（P2 默认配置）**：**EX=14.08%（77/547）**，98 分钟 / 1452 次 LLM 调用。分后端：BigQuery **33/205（16.1%）**、Snowflake **0/207（0%）**、local SQLite **28/135（20.7%）**。对比 ReFoRCE SOTA 36.56（o3 强模型 + 原生全后端）——差距主要来自 Snowflake 全废 + 模型代差（deepseek-chat vs o3）。执行成功但语义错是主要失败模式（BQ 139/205、SF 94/207 可执行），印证"接地已解决、语义组合是瓶颈"。

  **Snowflake 专项修复（0/207 根因定位与修复）**：诊断确认数据库可正常访问（连接 OK、`PATENTS.PUBLICATIONS` 51.6 万行可查、50 个库可见），0/207 不是权限/网络问题，而是**生成 SQL 的表名限定错误**：
  - 根因：`OnlineTable.fqn()` 对 Snowflake 用"目录名猜 schema"生成两段名 `"schema"."table"`，漏掉 database 前缀，且目录名 ≠ 真实 schema，导致大面积 `invalid identifier` / `schema does not exist`（如 `PATENTS_USPTO.PATENTS_USPTO` 实际 schema 是 `USPTO_OCE_*`；`GITHUB_REPOS.PUBLIC` 实际是 `GITHUB_REPOS.GITHUB_REPOS`）。
  - 修复：资源目录结构本身编码了真值（database=库目录名、schema=子目录名、table=表名），据此构建**三段名 `DATABASE.SCHEMA.TABLE`**（实测 `PATENTS_USPTO.USPTO_OCE_CANCER.MATCH` 等可执行）；压缩 context 为每张表显式标注 `USE THIS EXACT TABLE NAME IN SQL: <fqn>`；prompt 强制使用给定三段名、禁止猜 schema（常见误用 `PUBLIC`）、避免 Snowflake 不支持的关联子查询。
  - 结果：**Snowflake n=15 从 0 → EX 20.0（3/15）**，执行成功率 9/15（60%），且 `invalid identifier / schema not exist` 类错误**归零**（修复前是最大失败类之一）。剩余失败转为 unsupported subquery（方言）与语义类，属更深层问题。

  **Snowflake 方言 + 语义修正（unsupported subquery / FLATTEN / 日期哨兵）**：针对上一步暴露的方言坑，新增 `PROMPT_SNOWFLAKE_DIALECT` 速查表注入生成与修复 prompt，并让修复按 Snowflake 错误码给定向改写提示（`_snowflake_repair_hint`）。覆盖 5 类真实失败：
  - 相关标量子查询含 FLATTEN → Snowflake 报 `Unsupported subquery`；改写为 flatten+GROUP BY 的 CTE 再 JOIN 回主表。
  - `CROSS JOIN LATERAL FLATTEN` + OUTER JOIN → `Unsupported feature`；改逗号 lateral 或 `FLATTEN(..., OUTER => TRUE)`。
  - 整数日期哨兵 0 → `Can't parse '0' as date`；用 `TO_DATE(TO_VARCHAR(NULLIF(x,0)),'YYYYMMDD')` + `x>0` 守卫。
  - VARIANT 访问 `f.value:"k"::TYPE`、禁用 BigQuery-only 函数（SAFE_CAST/PARSE_DATE 等）。
  - 结果：**Snowflake n=15 从 20.0 → EX 26.67（4/15）**，执行成功率 **9/15→13/15（87%）**，`unsupported subquery` 与 `lateral/FLATTEN` 错误**全部归零**，修复触发次数 12→4（生成阶段一次写对，减少返工）。递进：Snowflake **0 → 20.0（三段名）→ 26.67（方言修正）**。

- **规模与方差**：默认冒烟 ~20 题/数据集，单题即可造成数个百分点波动；线上 mixed **n=20 同代码两跑可差约 ±10 EX，n=60 收敛到约 ±2.5 EX**（deepseek-chat 运行间不确定性）。下结论需更大样本 + 多 seed；小样本上的机制增益必须大于噪声带才可信。
- **值重叠误报**：zip/country/date 等公共列可能造成假阳性，故只作为**软因子**而非硬事实。
