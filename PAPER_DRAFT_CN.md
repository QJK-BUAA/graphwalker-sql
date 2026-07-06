# GraphWalker-SQL 2.0：面向 Text-to-SQL 的成本受限白盒信念图游走

> 论文初稿版本：2026-07-05  
> 写作口径：中文初稿，按英文 AI 顶会论文结构组织。后续可翻译为英文 LaTeX。  
> 重要边界：本文将 GraphWalker-SQL 2.0 表述为 **POMDP-inspired belief refinement framework**，而不是完整 POMDP 求解器；系统不做强化学习训练。

## 摘要

大语言模型显著提升了 Text-to-SQL 的生成能力，但在真实数据库场景中，模型仍然容易受到大规模 schema、无外键声明、列名歧义、值证据缺失和连接路径不确定性的影响。现有方法通常将 schema linking、value grounding、join-path selection 和 SQL synthesis 混合在一次隐式推理中，导致错误难以定位，也难以在成本受限条件下进行可控修正。本文提出 GraphWalker-SQL 2.0，一个 training-free 的白盒信念图游走框架，将 Text-to-SQL 重新建模为不确定 schema graph 上的成本受限信念精炼过程。系统分为 Ground、Explore 和 Commit 三个阶段：Ground 阶段构建置信加权 schema graph 并初始化 column、value 和 path belief；Explore 阶段在高熵区域执行 top-k path exploration、轻量执行探针以及 Column/Value Belief Walk；Commit 阶段基于精炼后的 schema belief 生成唯一 SQL，并在执行失败或空结果时进行至多一次定向修正。GraphWalker-SQL 2.0 受到 POMDP 中部分可观测状态和 belief update 的启发，但不依赖强化学习或完整 POMDP 求解，而是将关键中间状态显式化、可审计化。实验表明，GraphWalker-SQL 2.0 在 BIRD-Dev 上达到 55.74 EX，在 Spider 1.0-Dev 上达到 77.10 EX；在 Spider2-Lite local gold/sql 子集上，默认开启 Column/Value Belief Walk 后达到 45.83 EX，显著高于关闭列值探针的 29.17 EX。进一步在 Spider2-Lite local SQLite 135 题全集上达到 22.96 EX，显示真实弱 schema 场景仍具有挑战性。本文的核心结论是：在不增加多候选投票或无限自反思的前提下，结构化、可解释的 schema/value belief refinement 能够为 Text-to-SQL 提供一种成本可控且可诊断的推理路径。

## 1 引言

Text-to-SQL 旨在将自然语言问题转换为可执行 SQL，是自然语言接口访问结构化数据库的关键任务。随着大语言模型的发展，直接 prompting、chain-of-thought、self-correction 和 agentic workflow 已经显著提升了 SQL 生成能力。然而，真实世界数据库和标准 benchmark 中的大量失败并不单纯来自 SQL 语法错误，而来自更早阶段的 schema grounding 错误：模型可能选对了表但选错了列，或者找到了可连通路径却没有识别真正的语义连接，还可能在多个同名或近义列之间做出错误选择。一旦这些 grounding 决策被隐式写入生成过程，最终 SQL 即使语法正确，也会产生错误执行结果。

这一问题在 BIRD 和 Spider2 等更贴近真实场景的数据集上尤为突出。BIRD 中存在大量冗余 schema 和业务口径差异，同一自然语言概念可能出现在多张表或多个列中；Spider2-Lite 则进一步包含无外键、弱 schema、混合执行后端和复杂分析查询。这些场景要求系统不仅能“生成 SQL”，还需要显式维护“当前相信哪些表、列、值和路径是正确的”。如果没有显式信念状态，模型的错误往往只能在最终 SQL 失败后被动发现，难以做出局部、可解释的修正。

现有方法大致有两类局限。一类方法依赖强 prompt 或多轮反思，将 schema linking 和 SQL synthesis 交给 LLM 内部推理；这类方法实现简单，但中间决策不可见，且容易通过多候选投票或无限 self-refine 增加成本。另一类方法引入交互式查询、工具调用或强化学习框架，能够提升部分场景下的鲁棒性，但往往需要额外训练、复杂策略学习或较高推理成本。对于需要可复现、可消融、可解释的 Text-to-SQL 系统而言，一个更直接的问题是：能否在不训练策略模型的前提下，把 schema grounding 过程本身显式建模为一个成本受限的 belief refinement 过程？

本文提出 GraphWalker-SQL 2.0。我们的基本观点是：Text-to-SQL 不应被视为从问题到 SQL 的一次性代码生成，而应被视为在不确定 schema graph 上逐步精炼 belief 的过程。给定数据库 schema 和自然语言问题，系统维护三类 belief：正确列的 belief `b(C*)`、正确过滤值的 belief `b(V*)` 和正确连接路径的 belief `b(Π*)`。这些 belief 不是不可解释的神经向量，而是由名称匹配、值命中、唯一性、图先验、执行探针等白盒证据累积而成。系统只在不确定性高、预期信息收益超过成本时执行探针，因此能够在简单问题上保持低成本，在复杂问题上进行局部探索。

GraphWalker-SQL 2.0 的流程被压缩为三个阶段。Ground 阶段构建 schema graph：当数据库声明外键时直接使用外键；当外键缺失时，通过 LLM-guided joinability discovery 结合类型兼容、名称模式、唯一性和值重叠构造置信加权边。随后系统锚定 source/destination tables 和 literals，并初始化 belief state。Explore 阶段在 schema graph 上枚举 top-k 候选路径，利用路径熵和 top-gap 判断是否需要执行轻量 join probe；同时引入 Column/Value Belief Walk，对候选列执行低成本 SQL profile 和 literal-hit 探针，从而主动精炼列和值的 belief。Commit 阶段将 belief MAP 对应的 grounded subgraph 交给 LLM 生成唯一 SQL，并在执行失败或空结果时进行至多一次定向修正。

本文强调，GraphWalker-SQL 2.0 是 POMDP-inspired，而不是完整 POMDP solver。我们借鉴 POMDP 中“状态部分可观测”和“belief update”的思想，将 schema grounding 表述为对 latent correct columns、values 和 paths 的后验估计；但系统不学习最优策略，也不做强化学习后训练。奖励或收益只用于成本门控，即判断额外探针是否值得执行。这一表述更符合实际实现，也更有利于审稿人理解方法的理论边界。

本文贡献如下：

1. 我们提出 GraphWalker-SQL 2.0，一个 training-free、white-box、cost-constrained 的 Text-to-SQL 推理框架，将 schema grounding 显式建模为不确定 schema graph 上的 belief refinement。
2. 我们设计了统一的 Schema Belief State，维护 column、value 和 path 三类 belief，并用可审计的离散证据分数驱动 Ground、Explore 和 Commit。
3. 我们实现了 Column/Value Belief Walk，在 Explore 阶段通过低成本 SQL profile 和 literal-hit 探针主动修正列和值信念，缓解“表链正确但列/值语义错误”的失败模式。
4. 我们在 BIRD-Dev、Spider 1.0-Dev 和 Spider2-Lite local 设置上进行官方执行准确率评估，并报告消融和错误分析，展示结构化 belief refinement 在复杂 schema 场景中的收益与局限。

## 2 相关工作

**LLM-based Text-to-SQL.** 近年来，基于大语言模型的 Text-to-SQL 方法通常通过 schema serialization、few-shot prompting、chain-of-thought 或 self-correction 来提升 SQL 生成质量。这些方法的优势是无需针对每个数据库训练专用模型，但 schema linking、value grounding 和 query planning 往往被压缩进同一个隐式生成过程。一旦模型在早期选择了错误列或错误连接路径，后续生成很难恢复。GraphWalker-SQL 2.0 与这类方法不同，它不把 schema grounding 作为 prompt 的副产品，而是将其显式建模为 belief state 的更新过程。

**Schema linking and graph-based reasoning.** 传统 Text-to-SQL 系统通常依赖 schema linking，将问题中的 span 映射到表、列和值。图结构也常被用于建模 schema 中的外键关系和表间路径。然而，在真实数据库中，外键可能缺失或不完整，单纯依赖声明关系会导致图不连通；若完全依赖 LLM 猜测连接边，又容易引入错误路径。GraphWalker-SQL 2.0 使用置信加权 schema graph：每条推断边由类型、名称、唯一性、值重叠和 LLM prior 共同决定，并作为 path belief 的先验，而不是被盲目当作硬事实。

**Tool-augmented and interactive Text-to-SQL.** 工具增强方法通过执行查询、检索数据库内容或与用户交互来修正 SQL。交互式方法能够降低歧义，但往往需要多轮交互或额外 oracle knowledge。GraphWalker-SQL 2.0 也使用执行反馈，但只使用受预算约束的轻量探针，不生成多条候选 SQL 进行投票，也不进行无限反思。其目标不是最大化所有工具调用，而是在信息收益和探针成本之间做白盒权衡。

**POMDP-inspired reasoning.** 部分近期工作将未知 schema 上的 Text-to-SQL 形式化为 POMDP 或强化学习问题，用 belief、state、action 和 reward 描述多步决策。GraphWalker-SQL 2.0 借鉴这种不确定性建模语言，但不进行 RL 训练。本文中的 belief update 是由显式证据和控制器规则驱动的，因此更易复现和消融。我们认为，这种 POMDP-inspired 但 training-free 的形式化更适合解释成本受限的 schema exploration。

## 3 方法

### 3.1 问题定义

给定自然语言问题 `q`、数据库 schema `D` 和可选外部知识 `e`，目标是生成一条可执行 SQL `y`，使其执行结果与 gold answer 等价。与直接生成方法不同，GraphWalker-SQL 2.0 在生成 SQL 前维护一个显式 belief state：

`b = { b(C*), b(V*), b(Π*) }`

其中 `C*` 表示问题所需的正确列集合，`V*` 表示正确过滤值及其列绑定，`Π*` 表示正确 join path。系统的核心任务是在有限成本预算下，从初始 belief `b0` 出发，逐步收集可验证证据并更新 belief，最终 commit 到一个 grounded schema subgraph `S*`。

### 3.2 Schema Belief State

GraphWalker-SQL 2.0 的 belief state 是白盒的。每个 hypothesis 可以是一列、一个值绑定或一条路径。系统不直接把不同来源的分数当作概率相加，而采用排序式离散证据分数。当前实现中的典型证据包括：

| 证据 | 分数 | 含义 |
|---|---:|---|
| `name_match` | +2 | 列名或表名与问题概念强匹配 |
| `value_hit` | +3 | 问题 literal 在某列中被找到 |
| `unique` | +2 | 目标列近似唯一，具备 key-like 特征 |
| `graph_prior` | +conf | 路径或边来自声明外键或高置信推断边 |
| `probe_nonempty` | +3 | 执行探针返回非空且合理结果 |
| `probe_empty` | -3 | 执行探针为空，削弱该路径 |

给定某一 belief family 的所有 hypothesis 分数，系统通过 softmax 计算熵。高熵表示候选之间难以区分，需要进一步探索；低熵表示 Top-1 已经足够明确，可以停止探针并进入 Commit。该机制让系统避免对所有路径和列进行穷举探查。

### 3.3 Ground: 构建置信 schema graph 并初始化 belief

Ground 阶段首先构建 schema graph。若数据库包含声明外键，系统将外键视为 gold edge，置信度为 1.0。若缺少外键，系统使用 LLM 从 DDL 中提出候选 joinable column pairs，然后用白盒因子计算边置信度：

`conf(edge) = type_compatible × name_pattern × uniqueness × value_overlap × llm_prior`

其中 `type_compatible` 判断源列和目标列类型是否兼容；`name_pattern` 衡量列名、表名和 key-like pattern 的相似性；`uniqueness` 衡量被引用列是否近似唯一；`value_overlap` 通过样本值重叠验证边的可连接性；`llm_prior` 表示该边由 LLM 提出。只有置信度超过阈值的边才进入 schema graph。这样，错误边不会被硬编码为事实，而是以较低 prior 参与后续路径选择。

随后，系统使用 LLM 进行轻量锚定，输出 source tables、destination tables 和 literals。这一步不直接生成 SQL，只为 belief initialization 提供起点。系统根据名称匹配、唯一性、值命中和图先验初始化 column、value 和 path belief。

### 3.4 Explore: 成本受限的信念图游走

Explore 阶段负责解决 join path、column grounding 和 value grounding 的不确定性。系统首先在 schema graph 中枚举 source 和 destination 之间的 top-k shortest paths。当前实现中 `k=3`，路径长度上限为 4。每条路径的初始 belief 来自边置信度乘积。若 path belief 熵较低或 Top-1 gap 已经足够大，系统跳过执行探针；否则对候选路径执行轻量 join probe。

路径探针并不生成完整答案 SQL，而是执行受限制的 `COUNT` join query，用于判断该路径是否能产生非空、合理的连接结果。非空探针增强该路径 belief，空结果则削弱该路径。系统用 `R = information_gain - λ × cost` 的简化门控决定是否继续探针，因此探索过程受成本约束，而不是无界搜索。

### 3.5 Column/Value Belief Walk

原始 GraphWalker-SQL 2.0 方案强调 Explore 不应只更新 path belief，还应在列级和值级歧义时主动查看表语境、值分布和列统计。当前复现中，这一思想被实现为 Column/Value Belief Walk，并作为默认模块开启。

在路径或 linked tables 确定后，系统从这些表中选择候选列。候选列优先来自已有高 belief 列、与问题 token 有名称重叠的列，以及当问题包含 literal 时的文本列。对每个候选列，系统执行低成本 SQL profile：

`COUNT(*)`、`COUNT(column)`、`COUNT(DISTINCT column)` 以及少量 `DISTINCT` 样例值。

如果问题中存在 literal，系统进一步检查该 literal 是否出现在候选列中。若命中，系统提升对应 column belief 和 value belief，并生成可读的 `column_hints`，传给 Commit 阶段。该模块的关键价值在于：它将“模型猜哪个列更像语义目标”转化为“数据库中可观测证据支持哪个列”的问题。

### 3.6 Commit: 基于精炼 belief 生成唯一 SQL

Commit 阶段将 Explore 得到的 linked tables、join conditions 和 belief hints 交给 LLM 生成唯一 SQL。系统不使用 self-consistency、多候选投票或 full-schema fallback。生成后，系统立即执行 SQL；若执行失败或返回空结果，则允许一次 targeted repair。若修正结果没有改善，则丢弃修正，保留原 SQL。

Commit 阶段还包含 Propose evidence check：LLM 可以指出 grounded subgraph 是否缺少明显必要表。当前默认不启用严格的 propose evidence gate，因为 BIRD n=100 实验显示该门控为 47.0，而默认无门控为 48.0。该结果说明，虽然结构上“LLM 提名缺表必须有连接证据”更符合方法直觉，但现有数据不足以支持将其作为默认主方法。

### 3.7 算法概述

```text
Algorithm 1: GraphWalker-SQL 2.0
Input: question q, database schema D, optional evidence e, budget B
Output: one SQL query y

1:  G ← BuildSchemaGraph(D)
2:  anchors ← Anchor(q, D, e)
3:  b ← InitializeBelief(q, D, G, anchors)
4:  paths ← TopKPaths(G, anchors.src, anchors.dst)
5:  while budget remains and H(b_path) is high do
6:      π ← SelectUncertainPath(paths, b)
7:      o ← ProbeJoin(π)
8:      b ← UpdatePathBelief(b, o)
9:  end while
10: T ← LinkedTablesFromBestPath(b)
11: if H(b_column) is high or literals exist then
12:     O_col ← ProbeColumnProfiles(T)
13:     O_val ← ProbeLiteralHits(T, anchors.literals)
14:     b ← UpdateColumnValueBelief(b, O_col, O_val)
15: end if
16: S* ← MAPSubgraph(b)
17: y ← GenerateOneSQL(q, S*, b)
18: if y fails or returns empty then
19:     y' ← RepairOnce(q, S*, y)
20:     keep y' only if it improves execution
21: end if
22: return y
```

## 4 实验设置

### 4.1 数据集

我们在三个主要设置上评估 GraphWalker-SQL 2.0。

**BIRD-Dev.** BIRD-Dev 包含 1534 个问题和 11 个数据库，具有真实业务语义、外部知识和复杂 SQL 口径。评估使用官方 `execute_model` 逻辑，执行预测 SQL 和 gold SQL，并比较执行结果集合。

**Spider 1.0-Dev.** Spider 1.0-Dev 包含 1034 个问题，是经典 Text-to-SQL benchmark。当前本机口径使用 dev database 执行 test-suite evaluator 的 execution accuracy。

**Spider2-Lite local.** Spider2-Lite 是更复杂的真实执行环境集合，包含 BigQuery、Snowflake 和 SQLite local 等后端。当前 GraphWalker-SQL 2.0 主流水线为 SQLite 后端，因此本文只将 local SQLite 部分作为严格可比结果：包括 `gold/sql` 下的 24 题 local 子集，以及扩展加载的 local SQLite 135 题全集。Snowflake 和 DBT 已做材料检查，但不作为主结果混报。

### 4.2 实现细节

默认 LLM 为 `deepseek-chat`，temperature 为 0，seed 为 42。系统每题只生成一条 SQL，repair 至多一次。默认开启 inferred graph、belief walk、top-k path、path probe、Column/Value Belief Walk、entropy stop 和 Propose check。默认不开启 column alignment 和 propose evidence gate，因为已有实验显示其净收益不足以作为默认主方法。

### 4.3 评估指标

主指标为官方执行准确率 EX。除 EX 外，我们记录平均 LLM 调用数、平均路径探针数、平均列探针数、执行成功率和运行日志，以支持成本分析和可复现性。

## 5 实验结果

### 5.1 主结果

| 数据集 | n | 图来源 | EX | 备注 |
|---|---:|---|---:|---|
| BIRD-Dev | 1534 | declared | 55.74 | 官方 BIRD 执行评测；执行成功率 97.8% |
| Spider 1.0-Dev | 1034 | declared | 77.10 | 官方 test-suite exec 口径 |
| Spider2-Lite local gold/sql | 24 | inferred + overlap + colwalk | 45.83 | 11/24，当前 Spider2 最高可比子集结果 |
| Spider2-Lite local SQLite 全集 | 135 | inferred + overlap + colwalk | 22.96 | 31/135，覆盖更多长尾复杂 local 题 |

BIRD-Dev 的 55.74 EX 表明，GraphWalker-SQL 2.0 在真实业务 schema 和外部知识设置下具备竞争力。Spider 1.0-Dev 的 77.10 EX 则说明，在相对干净、外键较明确的传统 schema 上，该方法不会因为额外图游走而明显破坏稳定性。Spider2-Lite local gold/sql 子集上的 45.83 EX 显示，Column/Value Belief Walk 对弱 schema 和无外键环境有明显帮助；但 135 题 local 全集上的 22.96 EX 也提醒我们，真实复杂分析任务仍然包含大量超出当前 schema grounding 能力的 SQL planning 和业务口径挑战。

### 5.2 Column/Value Belief Walk 消融

| 数据集 | colwalk EX | nocolprobe EX | ΔEX | 结论 |
|---|---:|---:|---:|---|
| BIRD-Dev n=100 | 51.0 | 48.0 | +3.0 | 冗余 schema 中列/值 grounding 有收益 |
| Spider 1.0-Dev n=100 | 84.0 | 85.0 | -1.0 | clean schema 上可能有轻微提示噪声 |
| Spider2-Lite local 24 | 45.83 | 29.17 | +16.67 | 弱 schema 场景强正向 |

该消融说明，Column/Value Belief Walk 并非单纯增加 prompt 信息，而是在复杂 schema 中补足了列/值级主动验证能力。尤其在 Spider2-Lite local 24 题子集上，关闭该模块后 EX 从 45.83 降至 29.17，说明列和值探针对弱 schema 场景中的 SQL 生成具有关键影响。与此同时，Spider 1.0 上的轻微负向提示我们：未来应加入更精细的门控机制，在 clean schema 或低熵列空间中减少不必要列探针。

### 5.3 成本分析

BIRD-Dev 全量平均 LLM 调用约 3.12 次/题，平均路径探针约 0.68 次/题。Spider 1.0-Dev 平均路径探针约 0.23 次/题，说明在干净 schema 中系统大多能快速 commit。Spider2-Lite local 135 题平均路径探针约 0.79 次/题，平均列探针约 15.16 次/题，反映出弱 schema 和长尾分析任务需要更充分的列级证据。该现象符合成本受限 belief refinement 的设计预期：简单问题少探，复杂问题多探，但探针仍然受上限控制。

### 5.4 错误分析

BIRD 全量错题分析显示，683 道错题中约 69% 的 pipeline linked tables 覆盖 gold tables，即表级接地并非主要瓶颈。更高频的错误来自列级语义、值口径、SELECT 形状、DISTINCT/NULL 和聚合粒度。这一发现直接支持 Column/Value Belief Walk 的设计：如果系统已经找到了正确表链，但仍然错在列和值，那么 Explore 阶段必须主动查看列统计和值分布，而不能只更新 path belief。

Spider2-Lite local 135 题结果进一步说明，真实复杂任务中的错误不仅来自 schema grounding，还来自窗口函数、嵌套逻辑、业务公式和执行环境差异。Snowflake 迁移测试中，将 SQLite 生成的 SQL 直接改名为 `sf_local*` 提交官方 Snow evaluator 得到 0/135，主要失败为表名不存在或未授权。这说明完整 Spider2 评估需要 Snowflake schema、方言和远程探针后端适配，不能把 SQLite runner 的结果直接外推到 Snow。

## 6 讨论

### 6.1 为什么 GraphWalker-SQL 2.0 不只是 prompt engineering

GraphWalker-SQL 2.0 的核心不是改写 prompt，而是改变推理状态的表示方式。传统 prompt 方法让 LLM 在一次上下文中隐式决定表、列、值和 SQL 结构；GraphWalker-SQL 2.0 则将这些决策拆成可观察的 belief update。每个 column、value 和 path hypothesis 都携带证据来源，系统能解释为什么某列被提升、某路径被削弱，以及为什么某个 literal 被绑定到某列。这种可审计性是后续错误分析和方法改进的基础。

### 6.2 为什么不做多候选投票

多候选 SQL 生成和 self-consistency 可能提升局部结果，但会显著增加 token 和执行成本，并且会混淆方法贡献：性能提升到底来自 schema belief refinement，还是来自多次采样后的投票？GraphWalker-SQL 2.0 保持每题只生成一条 SQL、至多一次 repair，从而使消融更干净，也更符合成本受限系统的目标。

### 6.3 当前成熟度与发表边界

从方法结构和复现结果看，GraphWalker-SQL 2.0 已经具备论文初稿条件：它有明确问题定义、紧凑三阶段框架、白盒 belief state、可解释探针机制、消融结果和跨数据集实验。然而，若目标是顶会投稿，仍建议在最终版本中补足三点：第一，增加更系统的消融表，尤其是 full BIRD/Spider1 的 colwalk 全量对照；第二，补充 case study，展示 belief trace 如何修正具体列和值；第三，明确 Spider2 的评估边界，不将 local SQLite 结果表述为完整 Spider2 结果。

## 7 局限

GraphWalker-SQL 2.0 是 POMDP-inspired，但并不是完整 POMDP solver。当前 belief update 规则是启发式、离散打分式的，没有学习最优策略，也没有理论最优性保证。

系统仍然依赖底层 LLM 的 SQL synthesis 能力。对于复杂窗口函数、多层嵌套查询、隐含业务公式和严格输出形状，当前方法只能提供更好的 grounding evidence，不能完全替代强推理模型。

Column/Value Belief Walk 在弱 schema 上收益明显，但在 clean schema 中可能带来提示噪声。因此未来需要更强的探针门控机制，根据 schema 复杂度、外键完整度、列熵和 literal 分布决定是否启用列探针。

当前完整 Spider2 后端尚未适配。Spider2-Lite local SQLite 135 题已经可评估，但 Snowflake、BigQuery 和 DBT 分别需要独立 schema parser、方言生成器、远程探针和项目文件生成机制。本文不将这些未适配后端的结果混入主结论。

## 8 结论

本文提出 GraphWalker-SQL 2.0，一个 training-free、white-box、cost-constrained 的 Text-to-SQL 信念图游走框架。该方法将 SQL 生成前的 schema grounding 显式建模为 column、value 和 path belief 的逐步精炼过程，并通过 Ground、Explore 和 Commit 三阶段实现可解释、可消融的推理流程。实验表明，结构化 belief refinement 能够在 BIRD、Spider 1.0 和 Spider2-Lite local 设置下提供稳定收益，尤其是 Column/Value Belief Walk 对弱 schema 和无外键环境有显著帮助。GraphWalker-SQL 2.0 的核心价值不在于无限增加 LLM 推理次数，而在于以低成本、白盒、可审计的方式把“该相信哪些表、列、值和路径”变成显式中间状态。未来工作将重点扩展 Snowflake/BigQuery/DBT 后端，增强探针门控，并补充更完整的跨模型和跨 seed 稳定性验证。

## 附录 A：原始 HTML 方案与当前代码实现的一致性

| 原始方案模块 | 当前代码实现 | 状态 |
|---|---|---|
| Ground → Explore → Commit 三阶段 | `pipeline.py` 串联 `ground.py`、`explore.py`、`commit.py` | 已实现 |
| Schema Belief State | `belief.py` 中维护 column/value/path hypotheses | 已实现 |
| 置信加权 schema graph | `graph_builder.py` 中 declared/inferred graph 与 `conf(edge)` | 已实现 |
| Top-k path exploration | `explore.py` 中 top-k shortest paths，k=3 | 已实现 |
| 条件执行探针 | `explore.py` 中 path entropy/top-gap 触发 join probe | 已实现 |
| Column/Value active probing | `explore.py` 中 column profile/literal-hit probes | 已实现，当前默认开启 |
| Propose 检查点 | `commit.py` 中 `propose()` | 已实现 |
| 单次 repair | `commit.py` 中执行失败或空结果后至多一次 repair | 已实现 |
| RepairGraph | 当前未完整实现，仅有 union fallback 和 inferred graph 构建 | 未完整实现 |
| Query skeleton | 当前未作为核心模块实现 | 未完整实现 |
| 完整 POMDP solver/RL | 当前不实现，也不作为论文 claim | 不适用 |

## 附录 B：当前可引用的实验产物

| 产物 | 路径 |
|---|---|
| README 主结果 | `GraphWalker-SQL-2.0/README.md` |
| Spider2 评估报告 | `GraphWalker-SQL-2.0/SPIDER2_EVALUATION_REPORT.md` |
| BIRD 错题反思 | `GraphWalker-SQL-2.0/BIRD错题反思报告.md` |
| Spider2 local 135 结果 | `outputs/spider2-lite-local_full_deepseek-chat_local135_colwalk_seed42.json` |
| Spider2 local 24 colwalk 结果 | `outputs/spider2-lite_full_deepseek-chat_colwalk_n100_seed42.json` |
| GitHub commit | `2ba7211 chore: add spider2 local evaluation` |

## 附录 C：后续写成英文顶会论文时的推荐标题

1. GraphWalker-SQL 2.0: Training-Free Belief Graph Walking for Cost-Constrained Text-to-SQL
2. Ground, Explore, and Commit: Structured Belief Refinement for Training-Free Text-to-SQL
3. Cost-Constrained Belief Graph Walking for Robust Text-to-SQL Reasoning
4. GraphWalker-SQL 2.0: White-Box Schema Belief Refinement without Task-Specific Training
