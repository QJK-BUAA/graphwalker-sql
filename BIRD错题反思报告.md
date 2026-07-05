# BIRD-Dev 全量错题反思报告（1534 题）

> 运行：GraphWalker-SQL 2.0, deepseek-chat, temperature=0, seed=42, 官方 BIRD 评测器
> 结果：EX **55.48%**（851 对 / **683 错**）。执行成功率 97.5%。
> 数据来源：[bird_full_deepseek-chat_FULL_seed42.json](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/outputs/bird_full_deepseek-chat_FULL_seed42.json)
> 分析脚本：[analyze_errors.py](file:///Users/bytedance/Desktop/研二下/GraphWalker-SQL-2.0/analyze_errors.py)

---

## 一、一句话结论

**683 道错题里，约 69%（473 题）pipeline 链接的表 ⊇ gold 表——即"接地（表级）是对的，错在 SQL 语义"。**
真正的表级漏链只有约 120 题（17.6%），硬执行失败仅 38 题（5.6%）。
**瓶颈不在"选哪些表/走哪条路"（方案的核心创新），而在选定表之后的"列级语义 + SQL 口径"。**

---

## 二、错误类型分布（自动归因，683 题）

| 类别 | 数量 | 占比 | 本质 |
|------|------|------|------|
| 同概念换表（single-table 替换 / 冗余 schema 选错表）| ~79 | 11.6% | **BIRD 特有陷阱**：概念散落多表 |
| value_semantics（表/形状都对，值/列语义错）| 158 | 23.1% | 列级接地 + 值口径 |
| wrong_select_shape（SELECT 列数/内容不符）| 141 | 20.6% | 多选列 / 少选列 / 选错列 |
| 真·漏 join 表 | ~120 | 17.6% | 表级接地失败 |
| extra_table 过度 join | 65 | 9.5% | 过度连接 |
| agg/group 不匹配 | 50 | 7.3% | 聚合粒度 |
| exec_fail 执行失败 | 38 | 5.6% | 语法/列名/超时 |
| wrong_rowcount（过滤/DISTINCT）| 35 | 5.1% | 条件/去重语义 |
| order/limit 不匹配 | 15 | 2.2% | top-k 语义 |
| ratio_cast 缺失 | 2 | 0.3% | （CAST 提示已基本解决）|

> 交叉统计（更能说明本质）：**DISTINCT 有无不一致 188 题（27%）**；**pred 比 gold 多选列 88 题（13%）**；gold 有 `IS NOT NULL` 过滤而 pred 没有 20 题。
> 错题难度分布：simple 343 / moderate 253 / challenging 87——**simple 占一半**，说明错误不是"题太难"，而是系统性口径问题。

---

## 三、五大根因（逐条精读得出）

### 根因 1｜冗余 Schema 的"同概念多表"陷阱（BIRD 特有，最隐蔽）
BIRD 的 `california_schools` 库里，`frpm` 和 `schools` **都含** District/School/County/Charter 等列。
- `bird_2`：gold 用 `frpm JOIN schools` 取 Zip；pred 只查 `schools`（它也有 Zip、District）。pred **执行成功、逻辑自洽**，但 `frpm.District Name`（"Fresno County Office of Education"）与 `schools.District` 的**取值口径不同**，结果不一致。
- **为什么会错**：方案的图路由只保证"表可连通"，但当**同一概念存在于多张表**时，它没有机制判断 gold 究竟用哪张表的哪一列。我们的信念图对"表级可连接性"建模充分，对"列级语义归属"建模不足。
- **这类正是我 memory 里记的**：值重叠/列对齐才是关键，而非最短路径。

### 根因 2｜列级接地分歧：选对表、选错列（value_semantics 23%）
- `bird_42`：问"数学最高分学校提供的教育类型"，gold 取 `schools.EdOpsName`，pred 取 `schools.FundingType`——**两个都是"类型"列，模型选错了语义列**。
- `bird_40`：gold 用 `schools.District='Fresno Unified'`，pred 用 `satscores.dname='Fresno Unified'`——**同名概念在两表都有，值口径不同**。
- **为什么会错**：pipeline 的 grounding hint 只给"高置信列"，但没有区分"语义最贴切的那一列"。deepseek-chat 在多个近义列间靠猜。

### 根因 3｜SELECT 形状不符：多选/少选列（wrong_select_shape 21%，多选列 13%）
- `bird_80`/`bird_50`：gold 只 SELECT 1-2 列，pred 自作主张多加了 `School`、`CDSCode`、别名列。BIRD 官方 EX 是**严格列集合比对**，多一列即判错。
- **为什么会错**：prompt 虽写了"只返回问题所需列"，但模型倾向于"多给信息更保险"，与 BIRD 严格口径冲突。

### 根因 4｜DISTINCT / NULL 过滤口径（隐形高频，DISTINCT 不一致 27%）
- `bird_16`：gold `COUNT(CDSCode)`，pred `COUNT(DISTINCT CDSCode)`——**加了不该加的 DISTINCT**，计数不同。
- gold 常在 `ORDER BY ... LIMIT` 前加 `WHERE col IS NOT NULL`，pred 漏掉 → top-1 取到 NULL 行。
- **为什么会错**：这些是 BIRD 数据集的**隐性约定**，不在 schema 里、也不总在 evidence 里，纯靠模型经验。

### 根因 5｜聚合粒度与 GROUP BY（agg/group 7.3%）
- `bird_30`：问"grade 1-12 入学人数最低的 5 个城市"，gold 按 `City` 分组 `SUM(Enrollment)` 再排序；pred 未聚合到城市粒度，直接取行。
- **为什么会错**：从自然语言推断"按什么粒度聚合"需要较强的多步推理，deepseek-chat 在 moderate/challenging 上不稳。

---

## 四、和方案 claim 的对照（诚实）

| 方案主张 | 全量数据是否支持 |
|----------|------------------|
| 核心解决 schema grounding 与 join-path 消歧 | **部分成立**：表级接地/连通做得好（69% 错题表都链对了、97.5% 可执行、仅 38 题崩溃）|
| 白盒信念图能定位"该用哪些列/值/路径" | **列级不足**：根因 1、2 显示"选对表选错列"是最大真实错误源，信念图对**列级语义归属**建模不够 |
| 不解决复杂 SQL planning | **诚实兑现**：根因 3/4/5（形状、DISTINCT、聚合口径）确属生成端，方案本就没 claim 覆盖 |

**结论**：方案在"接地/连通"这层是**有效且干净**的（这也是它宣称的核心）；剩余 683 错题的大头（根因 1+2 ≈ 35%）指向一个**方案没充分解决的真问题——冗余 schema 下的列级语义归属**，其余（根因 3/4/5 ≈ 40%）是通用 SQL 生成口径，需更强模型或更强 grounding，而非图路由。

---

## 五、可落地的改进方向（按性价比排序，均需更大样本验证）

1. **列级值重叠归属**（针对根因 1、2，预计收益最大）：当一个概念（如 District）在多表出现时，用**值重叠 + 该列在问题字面值上的命中率**决定归属，把结果写进 belief 的列信念——这正是我 memory 里"值重叠是最稳健创新"的延伸，从"验证边"扩展到"列级消歧"。
2. **严格列口径对齐**（针对根因 3）：生成后做一次"SELECT 列数/语义 = 问题所需"的轻量校验，多选即裁剪。低成本。**（已实现并全量验证，见下节六）**
3. **DISTINCT/NULL 口径规则**（针对根因 4）：对 `COUNT`、`ORDER BY...LIMIT` 注入 BIRD 风格默认（谨慎——上轮教训：通用规则易过拟合噪声，须 n≥100 验证）。
4. **换更强模型**（针对根因 5 及整体）：challenging 档 40% 的天花板主要是推理能力，deepseek-chat → GPT-4o/deepseek-v4 才是主抓手。

> ⚠️ 纪律：上一轮已证明"n=20 上调 prompt = 拟合噪声"。以上任何改动**必须在 n≥100（最好全量）+ 逐题 diff** 下验证净收益，避免"修 2 道错 2 道"。

---

## 六、列裁剪（路A）全量实测：+5 真实修复，但 LLM 会双向判错

针对根因 3（SELECT 多选列），实现了生成端列裁剪 `use_column_align`（`gws2/commit.py` step 4 + `PROMPT_COLUMN_ALIGN`）：SQL 生成后，用一次 LLM 调用只重写 SELECT 列表为"问题所需列"，其余（FROM/JOIN/WHERE/GROUP/ORDER/LIMIT）保持字节不变。安全网：仅当裁剪后**仍可执行、行数不变、列数严格减少、且每个存活列的取值多重集都能在原结果中找到**（`_cols_are_subset`，保证只删列不改写表达式）才接受。

**全量 BIRD（1534）对照（seed=42, deepseek-chat）：**

| 运行 | EX | 正确数 | LLM/题 | 耗时 |
|------|-----|--------|--------|------|
| 基线 | 55.48% | 851 | 3.12 | 15.7 min |
| +列裁剪 | **55.67%** | 854 | 3.30 | 18.8 min |

**把机制效应和噪声拆开（逐题 diff）：**
- 裁剪**实际触发** 42 题（另有 127 题被安全网拒绝）：这 42 题 base 2 对 → colalign 7 对，**机制净 +5（7 修复 / 2 打破）**。
- 其余 1492 题未被触碰：base 849 对 → 847 对，纯 run-to-run 噪声 **−2**。
- 合计净 **+3**（落在噪声带内，但 +5 的机制信号是真实的）。

**7 个真实修复**（典型）：`bird_1474`"哪些客户…"——base 多给了 `SUM(Consumption)` 辅助列，裁剪后只剩 `CustomerID`，与 gold 完全一致。

**2 个回退**（`bird_216`、`bird_1236`）暴露了方法的根本局限——**LLM 会把本该 2 列的答案裁成 1 列**（`bird_216` gold 需 `atom_id, atom_id2`，被裁到只剩 `atom_id2`；`bird_1236` gold 需 `ID, Admission`，被裁到只剩 `Admission`）。安全网救不了：1 列结果天然是 2 列结果的子集，`_cols_are_subset` 只能挡住"改写表达式"，挡不住"列数判错"。且**没有句法判别器**——`bird_1533`（修复）和 `bird_216`（打破）都在删一个普通 id 列，唯一区别是自然语言到底要 1 个还是 2 个输出，这与原任务一样难。

**结论（诚实）**：列裁剪把根因 3 的一部分变成了真实收益（机制 +5），但它把"多选列"错误的一部分转成了"少选列"错误——是**用一类判错换另一类判错**，净收益被自身引入的回退吃掉大半。它是干净、单调性*接近*但不*保证*的改进（默认关闭，`--ablation colalign` 开启）。要真正解决 SELECT 形状，需要的是更强的"问题→输出列数/语义"对齐能力，而非事后裁剪；这仍指向根因 1/2 的列级接地和更强模型。

---

## 七、Propose 加表的连通性证据门：小改动但更符合原方案

在继续分析门控前基线时，发现一个和原方案高度相关的偏差：**Propose 检查点本应是防幻觉证据门，但当前实现会无条件采纳 LLM 提名的任何有效表名**。这会让“LLM 猜测的缺表”直接变成生成阶段的硬约束。

全量 BIRD 基线诊断：
- Propose 加表 590 题，EX **46.8%**；不加表 944 题，EX **60.9%**。
- 在这些加表中，约 53% 的新增表并不在 gold SQL 中。
- 更强的结构信号：**88% 的非 gold 新增表既不是 anchor，也不在已选 join path 上**，通常会带来过度连接或 cross-join 风险。

因此实现了 `use_propose_evidence_gate` 变体：LLM 仍可在 Propose 阶段提出缺表，但只有当该表与当前 grounded subgraph 存在 schema 图 join 边（declared 或 inferred+verified）时才加入；否则写入 `missing_rejected` 和 trace。这个改动不引入额外 LLM 调用，也不改变 Ground/Explore 主流程，属于原方案 §7 “不要让 LLM 的猜测变成硬事实 / 弱边必须有验证”的直接落地。可用 `--ablation propgate` 开启，作为论文消融项。

重跑结果（BIRD n=100, seed=42）：`propgate` **47.0**，默认/无门控 **48.0**。逐题 diff：gate 拒绝 11 题的表，直接负向影响 1 题（`bird_1526`），没有直接正向修复；其余 gain/loss 主要是 LLM run-to-run 波动。因此该想法**保留为可消融变体，不作为默认主方法**。

> 注意：这不是对所有列级语义错误的修复，而是修正 Propose 的过度加表风险。当前证据不足以支持默认开启；历史 55.48% 仍是主基线。
