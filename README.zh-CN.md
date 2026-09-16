<div align="center">

<h1>AUGO</h1>

<p><b>非对称波动生长优化器 / Asymmetric Undulatory Growth Optimizer</b></p>

<p><i>以归一化评估进度为唯一调度时钟，驱动三个协同机制</i></p>

<p><img src="assets/badge-paradigm.svg" alt="Stage-Adaptive">&nbsp;<img src="assets/badge-benchmarks.svg" alt="CEC2017 benchmarks">&nbsp;<img src="assets/badge-matlab.svg" alt="MATLAB">&nbsp;<img src="assets/badge-status.svg" alt="Under Review">&nbsp;<img src="assets/badge-license.svg" alt="MIT License"></p>

</div>


> **论文状态说明。** 本仓库是配套论文的参考实现。该论文目前正在某同行评审期刊**投审稿阶段**，评审期间不公开期刊名称。本页面供期刊主编与审稿人在审稿阶段查阅，仅在宏观层面介绍方法与评估情况。公式推导、完整实验协议与全部结果表格均见论文正文，**此处有意不复现**。


| | |
|:--|:--|
| **论文题目** | AUGO: An Asymmetric Undulatory Growth Optimizer for Continuous Optimization |
| **作者** | **张庆科**\* |
| **单位** | 山东师范大学 计算机与人工智能学院，济南 250358 |
| **通讯作者** | [tsingke@sdnu.edu.cn](mailto:tsingke@sdnu.edu.cn) |
| **状态** | 投审稿中 —— 期刊名称暂不公开 |


**研究亮点**

- AUGO 为生长优化器提供了进度感知的扩展。
- 三个协同机制分别强化探索、逃逸与精炼能力。
- 在 31 个算法中，AUGO 于 CEC2017 的 30D、50D、100D 均排名第一。
- AUGO 在全部十幅测试图像上取得最高平均 Kapur 熵。
- 无人机实验进一步验证了其竞争力与鲁棒性。


## 目录

1. [研究背景与动机](#1-研究背景与动机)
2. [方法概述](#2-方法概述)
3. [主要贡献](#3-主要贡献)
4. [框架与机制](#4-框架与机制)
5. [基准测试评估](#5-基准测试评估)
6. [应用案例研究](#6-应用案例研究)
7. [参考实现](#7-参考实现)
8. [致谢](#8-致谢)


## 1. 研究背景与动机

基于种群的元启发式算法所处理的连续优化问题往往无法提供可用的梯度。这类算法的性能取决于一个任何算法都无法回避的矛盾：既要保持足够的多样性以勘察整个空间，又要在已经证明有希望的区域附近加强搜索。由于不存在能在所有问题类别上取胜的优化器，实践中的问题不是哪个框架最好，而是**一个已有框架能被改造到何种自适应程度**。

**生长优化器（Growth Optimizer, GO）** 是本文工作的 baseline。GO 将连续优化刻画为一个协同的*学习—反思*过程：个体按适应度分层，学习阶段依据个体间的差距信息构造知识增量，反思阶段则调整被选中的维度。该框架结构紧凑、控制参数少，但它的参考个体选择、反思调节与后期搜索，都只与搜索的实际推进程度**弱耦合**。由此带来三个缺陷：

- **参考池固定。** 参考个体从整个运行期间保持不变的排序区间中抽取，选择压力在不同阶段几乎不变。
- **无向随机重置。** 反思可能将被选维度重新赋为在整个搜索空间上均匀抽取的值，从而丢弃搜索已获得的信息。
- **局部精炼不足。** 缺少专门用于精炼精英区域或当前全局最优解邻域的过程。

<p align="center">
  <img src="figures/fig1_limitation_mapping.png" alt="GO 局限与 AUGO 机制的映射关系" width="100%">
</p>

<p align="center">
  <em><b>图 1.</b> GO 的局限、所提出的 AUGO 机制及其预期搜索效果之间的概念对应关系。</em>
</p>

AUGO 在不改变基本学习—反思结构的前提下应对上述三个缺陷。它的搜索行为由**单一量**调节——归一化函数评估进度——从而使参考选择、反思与逃逸、局部精炼三者随预算消耗同步变化。


## 2. 方法概述

AUGO 完整保留了 GO 的种群初始化、边界处理、贪婪选择与生长更新原理，仅在原搜索过程的不同环节上叠加了三个机制，且三者由同一个归一化进度变量调度。

**UADSAP**——波动退火动态状态感知池（Undulatory Annealing Dynamic State-Aware Pool）——调节*参考个体从何处抽取*。其采样边界由一个随运行平滑衰减的波动退火因子驱动：运行早期两个池都很宽，个体从种群的广泛横截面中学习；随着运行推进，两个池向极端排名收缩，使引导信息更加集中。

**AT-CQ**——非对称时变反思与柯西量子逃逸（Asymmetric Time-varying Reflection and Cauchy Quantum Escape）——调节*反思如何行为*。它不再把某个维度重置为均匀采样值，而是将该坐标朝某个优解参考个体的对应坐标移动，并以一个期望幅度随时间递减的时变因子加权。另有独立的逃逸事件，其激活概率随运行衰减，偶尔取代原引导值——有时为均匀重置，有时为以到当前全局最优解的距离为尺度的重尾扰动。

**UDGF**——统一差分—高斯场（Unified Differential-Gaussian Field）——在两个层面上提供*后期局部精炼*。第一个子过程沿种群差分向量、叠加收缩的高斯噪声扰动精英个体；第二个子过程在当前全局最优解周围执行预算受限的搜索，且仅作用于随机激活的部分坐标。全局最优邻域搜索在预算前 20% 内关闭。

设计的着眼点在于三个机制**不争夺同一批评估次数**：UADSAP 改变学习阶段接收到的信息，AT-CQ 改变反思的修正方式，UDGF 补上原框架从未具备的精炼能力。

<p align="center">
  <img src="figures/fig2_mechanism_schedule.png" alt="AUGO 三个机制的阶段式调度" width="100%">
</p>

<p align="center">
  <em><b>图 2.</b> 三个机制的阶段式调度，参数为 N = 40、ρ<sub>p</sub> = 0.5、p<sub>q</sub><sup>max</sup> = 0.10、η<sub>B</sub> = 0.20、MaxFEs = 300,000。每条调度曲线都朝同一方向变化——由宽到窄、由粗到细——且都以同一个进度变量为索引。</em>
</p>


## 3. 主要贡献

- **一个保留原框架的进度感知扩展。** AUGO 保留 GO 的学习—反思结构，以预算消耗而非学习型决策策略作为调度信号，且不带来额外的学习开销。
- **三个机制，对应三个已识别的缺陷。** UADSAP 解决固定池缺陷，AT-CQ 解决无向重置缺陷，UDGF 解决缺失精炼的缺陷。三者共同构成一套渐进式搜索架构，而非若干彼此独立的附加项。
- **一次包含消融与敏感性证据的大规模对比评估。** AUGO 在相同评估预算下，于 CEC2017 测试集的三个维度上与 30 个基线算法（含原始 GO）对比，并通过留一法消融单独分离出每个机制的贡献。
- **向两个结构迥异的应用问题迁移。** 同一份实现未经任务特定的重新设计，即被应用于 Kapur 熵多阈值图像分割与带约束的三维无人机路径规划。


## 4. 框架与机制

AUGO 以评估预算而非固定迭代次数作为终止条件，这正是方法中每一条调度都能写为进度函数的前提。UADSAP 调节参考采样，AT-CQ 执行带引导的反思与逃逸，随后 UDGF 执行两个互补的精炼操作——其中全局最优邻域搜索仅在预算消耗 20% 之后激活。

<p align="center">
  <img src="figures/fig3_flowchart.png" alt="AUGO 算法流程图" width="100%">
</p>

<p align="center">
  <em><b>图 3.</b> AUGO 的整体流程及 UADSAP、AT-CQ、UDGF 三者的交互关系。</em>
</p>

关于这一组合方式，有两点值得在架构层面说明，形式化处理留待论文正文。

**三个机制作用于互不重叠的组件。** 没有任何两个机制修改同一个更新规则，因此这一组合是**可加而非纠缠**的——每个机制都能被干净地消融，论文中的消融实验也确认了三者均有贡献。

**该扩展不提升渐近代价。** 每周期新增的工作仅为常数因子级，因此整体时间复杂度与原版 GO 处于同一渐近阶，核心存储需求不变——这套机制以不提升增长阶的方式换来了自适应性。


## 5. 基准测试评估

| | |
|:--|:--|
| 测试集 | CEC2017 单目标测试集 F1–F30（单峰、简单多峰、混合、复合四类），搜索范围 [−100, 100] |
| 维度 | 30、50、100 |
| 对比集合 | 31 个算法——AUGO 加 30 个基线，涵盖进化计算、群体智能、物理与数学启发、人类行为启发等类别，其中包含原始 GO |
| 协议 | 各维度下评估预算相同，均匀随机初始化，每种算法每个函数独立运行 20 次 |
| 统计分析 | 双侧 Wilcoxon 秩和检验做两两显著性分析，Friedman 秩检验做整体排名，α = 0.05 |
| 主要结果 | AUGO 在**三个维度上均排名第一**（Friedman 平均秩 4.557）；各维度下最接近的竞争者都是原始 GO |

面对原始 GO，AUGO 的表现随维度升高而改善，优势最明显的是简单多峰组。但**提升并非普适**：GO 在少数函数上仍保有显著优势。论文正文完整报告了逐函数对比、消融实验与单因素参数敏感性分析；消融与敏感性结果均支持该设计——没有任何机制冗余，且算法在测试范围内并不需要高度特定的参数设置。


## 6. 应用案例研究

基准测试衡量的是固定协议下的解质量，它并不检验一个优化器能否被直接投入到一个决策结构、可行性条件与目标地形都由**他人**设定的问题中去。因此，AUGO 在不对搜索内核做任何任务特定重新设计的前提下，被应用于两个此类问题。

### Kapur 熵多阈值图像分割

每个候选解是一组有序的灰度阈值，由阈值所诱导的各区域上的 Kapur 熵之和评分。该目标为最大化，难度随阈值数增大。实验使用十幅灰度图像——五幅经典基准图与五幅应用导向图像——阈值数从 2 到 20，每幅图像每个设置独立运行 20 次，并与另外五个算法对比。所报告的保真度指标刻画的是**重建保真度，而非语义分割精度**。

自阈值数达到 8 起，AUGO 在每个测试的阈值数下、于全部十幅图像上取得最高平均最终熵；在最低的阈值数下，领先算法的最终熵几乎一致——当目标地形相对平滑时，这本就是预期之中的现象。因此其优势**随问题变难而显现**。此外，由于保真度指标是由最大化 Kapur 熵的阈值向量计算而来，它们不必同时最优——证据支持的是 AUGO 在实际被优化的那个目标上具备强竞争力，而非在每一项指标上全面领先。

<p align="center">
  <img src="figures/fig4_segmentations.png" alt="AUGO 在 20 阈值下的分割结果" width="100%">
</p>

<p align="center">
  <em><b>图 4.</b> AUGO 在测试集上以 20 阈值生成的 Kapur 重建结果。</em>
</p>

### 带约束的三维无人机路径规划

十个中间航点构成 30 维决策向量。一条共享的解码链把任意候选解映射为可飞行轨迹——航点按投影进度排序，以分段三次 Hermite 插值连接，按弧长均匀重采样，并进行确定性修复以满足对地 clearance 要求。所有对比算法共用同一套解码链，因此对比隔离出的正是**搜索能力**本身。代价综合了路径长度、对地高度、平滑度、障碍与威胁惩罚、转弯与爬升可行性以及高度变化，并在任一违反计数非零时附加一个很大的惩罚项。

实验使用四个约束复杂度递增的确定性场景，每个场景独立运行 30 次，且各算法间采用配对的随机种子。优化过程中目标以较少的弧长采样点评估，随后对每个入选解以**远为密集**的采样点做确定性复核；**仅当所有违反计数均为零时，该路径才计为成功。** 显著性以精确配对 McNemar 检验（成功率）与精确配对符号检验（代价与长度）评估，并在各检验族内做 Holm 校正。

AUGO 取得六个对比算法中最高的汇总成功率与最低的平均配对秩，并且在最难、最开放的问题上表现最强——它是在受限最严重的场景中仅有的两个能产出通过密集复核的路径的算法之一。这些优势**并不均匀**，论文正文也如实报告了其不成立之处：AUGO 未达到完全可行，在特定场景与个别指标（如代价中位数）上被其他竞争者超越，且某一竞争者在其中一个场景中的代价经校正后显著低于 AUGO。该实验所支持的是：AUGO 在确定性密集复核下具备有竞争力的、鲁棒的表现——而**不是**它在每项指标上都占优。

<p align="center">
  <img src="figures/fig5_uav_paths.png" alt="四个场景下的代表性无人机路径" width="100%">
</p>

<p align="center">
  <em><b>图 5.</b> 四个场景下的代表性可行路径，用于展示典型路径几何形态。</em>
</p>


## 7. 参考实现

参考实现是单个自包含的 MATLAB 函数，除调用方提供的目标函数外无任何外部依赖。它支持两种参数布局并自动识别：11 参数的基准测试接口与 8 参数的分割接口。

```matlab
% --- 基准测试接口（CEC / PlatECO）--------------------------------------
% AUGO(mainHandle, popsize, dimension, xmax, xmin, vmax, vmin, ...
%      maxiter, Func, FuncId, VisualSwitch)
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    [], 40, 30, 100, -100, [], [], 7500, @myObjective, 1, false);

% --- 分割接口 ----------------------------------------------------------
% AUGO(popsize, dimension, maxiter, xmax, xmin, probR, Func, Class)
% 目标函数在内部按最大化处理，故 Func 返回 Kapur 熵。
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    40, D, 150, 255, 0, probR, @kapurObjective, imageClass);
```

完整带注释源码位于仓库根目录的 [`AUGO.m`](AUGO.m)——576 行，其中 43% 为注释，按算法模块组织（输入解析、初始化、主循环四个阶段与辅助函数），全文复现于下方。基准测试协议使用初始种群规模 `N = 40`；全部默认参数均已在文件头中说明。

<details>
<summary><b>点击展开 <code>AUGO.m</code> 完整源码（576 行，含模块化注释）</b></summary>

```matlab
function [gbestX, gbestfitness, gbesthistory] = AUGO(varargin)
% =========================================================================
%  AUGO -- Asymmetric Undulatory Growth Optimizer
%
%  Reference implementation of the algorithm described in the manuscript:
%    "AUGO: An Asymmetric Undulatory Growth Optimizer for Continuous
%     Optimization"
%
%  The manuscript is currently UNDER REVIEW at a peer-reviewed journal.
%  The journal name is withheld for the duration of the review process.
%  This citation record will be updated once the review concludes.
%
%  Copyright (c) 2026  Qingke Zhang
%  School of Computer Science and Artificial Intelligence
%  Shandong Normal University, Jinan 250358, China
%
%  Released under the MIT License. See the LICENSE file in the repository
%  root for the full text. If you use this code in academic work, please
%  cite the manuscript above (see also CITATION.cff).
%
%  Version : V1.0
%  Updated : 2026-09-17
%
% -------------------------------------------------------------------------
%  Interface
%    AUGO is called through varargin and accepts two argument layouts,
%    detected automatically by parseInputs:
%
%      Benchmark (CEC / PlatECO):
%        AUGO(mainHandle, popsize, dimension, xmax, xmin, vmax, vmin, ...
%             maxiter, Func, FuncId, VisualSwitch)
%
%      Image segmentation:
%        AUGO(popsize, dimension, maxiter, xmax, xmin, probR, Func, Class)
%
%  Design notes
%    AUGO retains the learning--reflection framework of the Growth Optimizer
%    (GO) and adds three mechanisms: UADSAP (Undulatory Annealing Dynamic
%    State-Aware Pool), AT-CQ (Asymmetric Time-varying Reflection and Cauchy
%    Quantum Escape), and UDGF (Unified Differential-Gaussian Field).
%
%    MaxFEs is computed as popsize * maxiter rather than hard-coded, so the
%    benchmark configuration (N = 40, a 10000*D function-evaluation budget)
%    is reproduced by passing maxiter = 250*D. For the segmentation setting,
%    popsize = 40 with maxiter = 150 reproduces the 6000-evaluation budget.
%
%    Default parameters: rho_p = 0.5, p_q^max = 0.10, eta_B = 0.20, K = 5.
%
%    Note: this file releases a snapshot of the implementation that
%    accompanies the submitted manuscript. Any code or results released
%    after the review process concludes should be treated as authoritative.
%
% -------------------------------------------------------------------------
%  Module map
%    Module 1  Input parsing and run configuration
%    Module 2  State initialization
%    Module 3  Initial population evaluation
%    Module 4  Main loop
%                4.0  Progress clock and annealing factor
%                4.1  UADSAP -- dynamic reference-pool bounds
%                4.2  Stage 1 -- learning (vector growth)
%                4.3  Stage 2 -- AT-CQ reflection and Cauchy escape
%                4.4  Stage 3 -- UDGF elite differential-Gaussian refinement
%                4.5  Stage 3b -- UDGF best-neighbourhood refinement
%    Module 5  Convergence-history bookkeeping
%    Local functions      printProgress, refineBest
%    External functions   parseInputs, sortedIndex, isBetter, clampBounds,
%                         selectID
%
%    All three mechanisms are driven by the same normalized evaluation
%    progress, which is why FEs is threaded through every stage below.
% =========================================================================

% =========================================================================
%  Module 1 -- Input parsing and run configuration
% =========================================================================
%  parseInputs resolves the two supported call signatures and returns a
%  uniform set of run parameters together with a Fitness handle, the
%  optimization sense (isMinimize) and the output mapping (outputBest).
%
%  The evaluation budget is derived rather than hard-coded:
%      MaxFEs = popsize * maxiter
%  so the benchmark protocol (N = 40, 10000*D evaluations) is obtained with
%  maxiter = 250*D, and the segmentation protocol (6000 evaluations) with
%  popsize = 40 and maxiter = 150.
% =========================================================================
[popsize, dimension, maxiter, xmax, xmin, Fitness, isMinimize, outputBest] = parseInputs(varargin{:});

% =========================================================================
%  Module 2 -- State initialization
% =========================================================================
%  FEs is the single progress counter: it drives the annealing schedules of
%  every stage below and terminates the main loop. gbesthistory records the
%  incumbent after each evaluation, so a convergence curve can be rebuilt
%  from one run.
% =========================================================================
FEs = 0;
MaxFEs = popsize * maxiter;
printStep = max(1, floor(MaxFEs / 10));

x = xmin + (xmax - xmin) .* rand(popsize, dimension);
fitness = zeros(popsize, 1);
gbesthistory = nan(1, MaxFEs);

% The incumbent is initialized to the identity of the optimization sense, so
% the first evaluated individual always replaces it.
if isMinimize
    gbestfitness = inf;
else
    gbestfitness = -inf;
end
gbestPosition = zeros(1, dimension);
gbestX = outputBest(gbestPosition);

% =========================================================================
%  Module 3 -- Initial population evaluation
% =========================================================================
%  Initialization is charged to the budget: each of the N initial individuals
%  consumes one evaluation and is immediately eligible to become the
%  incumbent. This is what makes progress = FEs / MaxFEs well defined from
%  the very first cycle.
% =========================================================================
for i = 1:popsize
    fitness(i) = Fitness(x(i,:));
    FEs = FEs + 1;

    if isBetter(fitness(i), gbestfitness, isMinimize)
        gbestfitness = fitness(i);
        gbestPosition = x(i,:);
        gbestX = outputBest(gbestPosition);
    end

    gbesthistory(FEs) = gbestfitness;
    printProgress();
end

% =========================================================================
%  Module 4 -- Main loop
% =========================================================================
%  One cycle runs the learning stage, the reflection stage and the two
%  refinement stages in a fixed order, and consumes at least 2N + K
%  evaluations. Each stage re-reads the ranking and the incumbent, so the
%  greedy selections made in one stage propagate to the next.
% =========================================================================
while FEs < MaxFEs
    % ---------------------------------------------------------------------
    %  Module 4.0 -- Progress clock and undulatory annealing factor
    % ---------------------------------------------------------------------
    %  progress is the normalized evaluation progress in [0, 1]. alpha is the
    %  undulatory annealing factor: it decays smoothly from ~1 to 0 across the
    %  run and is the common driver of the UADSAP pool bounds and of the UDGF
    %  perturbation scales.
    % ---------------------------------------------------------------------
    progress = FEs / MaxFEs;
    alpha = (cos(pi * progress) + 1) / 2;

    % ---------------------------------------------------------------------
    %  Module 4.1 -- UADSAP dynamic reference-pool bounds
    % ---------------------------------------------------------------------
    %  The ranking is recomputed from the current fitness before the pools are
    %  sampled. The superior pool spans ranks 2 .. ub_better and the inferior
    %  pool spans ranks lb_worst .. N. Both bounds contract as alpha decays,
    %  so the learning stage draws on a broad cross-section of the population
    %  early and concentrates on the extreme ranks late. Rank 1 is excluded
    %  from the superior pool because it is the incumbent itself.
    %  rho_p = 0.5 is the reference-pool rank-boundary ratio.
    % ---------------------------------------------------------------------
    ind = sortedIndex(fitness, isMinimize);
    Best_X = x(ind(1), :);

    max_better = max(5, round(0.5 * popsize));
    ub_better = round(5 + (max_better - 5) * alpha);
    ub_better = min(popsize, max(2, ub_better));

    min_worst = min(popsize - 4, round(0.5 * popsize));
    lb_worst = round((popsize - 4) - ((popsize - 4) - min_worst) * alpha);
    lb_worst = min(popsize, max(1, lb_worst));

    % Scaling-factor denominator. The guards keep the ratio finite when the
    % population extreme approaches zero under minimization, or when an
    % individual fitness is zero under maximization.
    if isMinimize
        max_fit = max(fitness);
        if abs(max_fit) < eps
            max_fit = sign(max_fit + eps) * eps;
        end
    else
        min_fit = min(fitness);
    end

    % ---------------------------------------------------------------------
    %  Module 4.2 -- Stage 1: learning (vector growth with UADSAP pools)
    % ---------------------------------------------------------------------
    %  Four difference vectors are formed from the incumbent, one dynamic
    %  superior reference, one dynamic inferior reference and two distinct
    %  randomly selected individuals. Each vector is weighted by its relative
    %  length (LF) and by the scaling factor SF; their weighted sum is the
    %  knowledge increment. A rare random acceptance (p = 0.001) admits
    %  non-improving moves in order to preserve diversity; otherwise the
    %  update is greedy. The stage stops as soon as the budget is exhausted.
    % ---------------------------------------------------------------------
    for i = 1:popsize
        better_idx = ind(randi([2, ub_better]));
        Better_X = x(better_idx, :);

        worst_idx = ind(randi([lb_worst, popsize]));
        Worst_X = x(worst_idx, :);

        random = selectID(popsize, i, 2);
        L1 = random(1);
        L2 = random(2);

        D_value1 = Best_X - Better_X;
        D_value2 = Best_X - Worst_X;
        D_value3 = Better_X - Worst_X;
        D_value4 = x(L1,:) - x(L2,:);

        Distance1 = norm(D_value1);
        Distance2 = norm(D_value2);
        Distance3 = norm(D_value3);
        Distance4 = norm(D_value4);

        rate = Distance1 + Distance2 + Distance3 + Distance4;
        if rate == 0
            rate = 1e-10;
        end

        LF1 = Distance1 / rate;
        LF2 = Distance2 / rate;
        LF3 = Distance3 / rate;
        LF4 = Distance4 / rate;

        if isMinimize
            SF = fitness(i) / max_fit;
        else
            if abs(fitness(i)) < eps
                SF = 1;
            else
                SF = min_fit / fitness(i);
            end
        end

        rate1 = LF1 * SF;
        rate2 = LF2 * SF;
        rate3 = LF3 * SF;
        rate4 = LF4 * SF;
        newx_i = x(i,:) + (rate1 * D_value1 + rate2 * D_value2 + rate3 * D_value3 + rate4 * D_value4);
        newx_i = clampBounds(newx_i, xmin, xmax);

        newfitness = Fitness(newx_i);
        FEs = FEs + 1;

        if isBetter(newfitness, fitness(i), isMinimize) || (rand < 0.001 && ind(i) ~= ind(1))
            fitness(i) = newfitness;
            x(i,:) = newx_i;
        end

        if isBetter(fitness(i), gbestfitness, isMinimize)
            gbestfitness = fitness(i);
            gbestPosition = x(i,:);
            gbestX = outputBest(gbestPosition);
        end

        gbesthistory(FEs) = gbestfitness;
        printProgress();
        if FEs >= MaxFEs
            break;
        end
    end
    if FEs >= MaxFEs
        break;
    end

    % The ranking is refreshed so that Stage 2 samples from a current order.
    ind = sortedIndex(fitness, isMinimize);
    Best_X = x(ind(1), :);

    % ---------------------------------------------------------------------
    %  Module 4.3 -- Stage 2: AT-CQ reflection and Cauchy quantum escape
    % ---------------------------------------------------------------------
    %  Each dimension is visited in turn. With probability 0.3 the reflection
    %  branch fires and moves the coordinate toward a superior reference with
    %  a time-varying weight rand^(1 + 0.5*progress). Because the exponent
    %  grows with progress, the expected weight shrinks monotonically, so
    %  reflection becomes conservative late in the run.
    %
    %  Conditional on entering the branch, an escape event fires with
    %  probability 0.01 + 0.09*(1 - progress), decaying from p_q^max = 0.10 to
    %  0.01. It resolves with equal probability into either a uniform reset
    %  over the search range or a Cauchy heavy-tailed jump whose magnitude is
    %  scaled by the distance to the incumbent. Either branch overwrites the
    %  guided value.
    % ---------------------------------------------------------------------
    for i = 1:popsize
        newx_i = x(i,:);
        j = 1;

        while j <= dimension
            if rand < 0.3
                R_idx = ind(randi(max(2, ub_better)));
                R = x(R_idx, :);

                weight = rand ^ (1 + 0.5 * progress);
                newx_i(j) = x(i,j) + (R(j) - x(i,j)) * weight;

                if rand < (0.01 + 0.09 * (1 - progress))
                    if rand < 0.5
                        newx_i(j) = xmin + (xmax - xmin) * rand;
                    else
                        newx_i(j) = Best_X(j) + tan(pi * (rand - 0.5)) * abs(Best_X(j) - x(i,j));
                    end
                end
            end
            j = j + 1;
        end

        newx_i = clampBounds(newx_i, xmin, xmax);
        newfitness = Fitness(newx_i);
        FEs = FEs + 1;

        if isBetter(newfitness, fitness(i), isMinimize) || (rand < 0.001 && ind(i) ~= ind(1))
            fitness(i) = newfitness;
            x(i,:) = newx_i;
        end

        if isBetter(fitness(i), gbestfitness, isMinimize)
            gbestfitness = fitness(i);
            gbestPosition = x(i,:);
            gbestX = outputBest(gbestPosition);
        end

        gbesthistory(FEs) = gbestfitness;
        printProgress();
        if FEs >= MaxFEs
            break;
        end
    end
    if FEs >= MaxFEs
        break;
    end

    ind = sortedIndex(fitness, isMinimize);

    % ---------------------------------------------------------------------
    %  Module 4.4 -- Stage 3: UDGF elite differential-Gaussian refinement
    % ---------------------------------------------------------------------
    %  A fixed number of trials (K = 5) are spent refining the elite region.
    %  The base individual is drawn from the top 5% of the ranking and is
    %  perturbed along a differential vector formed by two distinct random
    %  individuals, with per-dimension Gaussian noise and a scale that
    %  contracts as (1 - progress). Selection is strictly greedy, so the
    %  elite individual never degrades.
    % ---------------------------------------------------------------------
    if FEs < MaxFEs
        for k_elite = 1:5
            if FEs >= MaxFEs
                break;
            end

            elite_pool_size = max(1, round(0.05 * popsize));
            base_idx = ind(randi(elite_pool_size));
            base_X = x(base_idx, :);

            r = randperm(popsize, 2);
            diff_vector = x(r(1), :) - x(r(2), :);

            shrink_factor = 1 - progress;
            step = randn(1, dimension) .* diff_vector * shrink_factor;

            trial = base_X + step;
            trial = clampBounds(trial, xmin, xmax);

            fit_trial = Fitness(trial);
            FEs = FEs + 1;

            if isBetter(fit_trial, fitness(base_idx), isMinimize)
                fitness(base_idx) = fit_trial;
                x(base_idx, :) = trial;

                if isBetter(fit_trial, gbestfitness, isMinimize)
                    gbestfitness = fit_trial;
                    gbestPosition = trial;
                    gbestX = outputBest(gbestPosition);
                end
            end

            gbesthistory(FEs) = gbestfitness;
            printProgress();
        end
    end

    % ---------------------------------------------------------------------
    %  Module 4.5 -- Stage 3b: UDGF best-neighbourhood refinement
    % ---------------------------------------------------------------------
    %  The second UDGF subprocess searches the neighbourhood of the incumbent
    %  with a Gaussian/Cauchy mixture restricted to a Bernoulli(0.25) mask of
    %  coordinates. It is deliberately conservative:
    %    * continuous and threshold-agnostic, so the same code serves both
    %      interfaces and neither is favoured;
    %    * late-stage only, activated once progress > 0.2;
    %    * budget limited to B = min(max(8, ceil(eta_B * N)), MaxFEs - FEs)
    %      with eta_B = 0.20, so it cannot overshoot the evaluation budget.
    %  Selection is greedy, so the incumbent never degrades.
    % ---------------------------------------------------------------------
    if FEs < MaxFEs && progress > 0.2
        refineBudget = min(max(8, ceil(0.20 * popsize)), MaxFEs - FEs);
        [gbestPosition, gbestfitness, FEs, gbesthistory] = refineBest(gbestPosition, gbestfitness, FEs, gbesthistory, refineBudget, progress);
        gbestX = outputBest(gbestPosition);
    end
end

% =========================================================================
%  Module 5 -- Convergence-history bookkeeping
% =========================================================================
%  A stage can overshoot MaxFEs by its last evaluation, so the history is
%  padded or truncated to exactly MaxFEs entries before it is returned.
% =========================================================================
if FEs < MaxFEs
    gbesthistory(FEs+1:MaxFEs) = gbestfitness;
elseif FEs > MaxFEs
    gbesthistory(MaxFEs+1:end) = [];
end

    % =====================================================================
    %  Local function -- progress reporting
    % =====================================================================
    %  Prints the incumbent at roughly ten evenly spaced points across the
    %  budget. It shares the workspace of the main function, so FEs,
    %  MaxFEs, printStep and gbestfitness are read directly.
    % =====================================================================
    function printProgress()
        if mod(FEs, printStep) == 0 && FEs <= MaxFEs
            fprintf("AUGO %d FEs, best fitness = %e\n", FEs, gbestfitness);
        end
    end

    % =====================================================================
    %  Local function -- refineBest (Module 4.5 inner loop)
    % =====================================================================
    %  Inputs : bestPos, bestFit   current incumbent
    %           evals, history     evaluation counter and convergence record
    %           budget             maximum evaluations this call may spend
    %           progressNow        normalized progress at entry
    %  Outputs: updated incumbent, counter and history
    %
    %  A Bernoulli(0.25) mask selects the coordinates to perturb, with at
    %  least one coordinate forced active. The perturbation is Gaussian with
    %  probability 0.75 and Cauchy with probability 0.25; the heavy tail is
    %  retained so that occasional larger deviations remain possible inside an
    %  otherwise local search. The scale sigma contracts with progress,
    %  giving coarse-to-fine behaviour. Selection is greedy.
    % =====================================================================
    function [bestPos, bestFit, evals, history] = refineBest(bestPos, bestFit, evals, history, budget, progressNow)
        used = 0;
        sigma = (xmax - xmin) * (0.06 * (1 - progressNow) + 0.004);

        while evals < MaxFEs && used < budget
            mask = rand(1, dimension) < 0.25;
            if ~any(mask)
                mask(randi(dimension)) = true;
            end

            trial = bestPos;
            if rand < 0.75
                trial(mask) = trial(mask) + randn(1, sum(mask)) * sigma;
            else
                trial(mask) = trial(mask) + tan(pi * (rand(1, sum(mask)) - 0.5)) * sigma * 0.5;
            end
            trial = clampBounds(trial, xmin, xmax);

            fitTrial = Fitness(trial);
            evals = evals + 1;
            used = used + 1;

            if isBetter(fitTrial, bestFit, isMinimize)
                bestFit = fitTrial;
                bestPos = trial;
            end

            history(evals) = bestFit;
        end
    end
end

% =========================================================================
%  External function -- parseInputs
% =========================================================================
%  Resolves the two supported call signatures. The argument positions differ
%  between them, so both layouts are mapped onto the same set of outputs:
%  the 11-argument benchmark layout is always a minimization problem and
%  returns the raw decision vector, while the 8-argument segmentation layout
%  is always a maximization problem and returns integer thresholds via fix().
% =========================================================================
function [popsize, dimension, maxiter, xmax, xmin, Fitness, isMinimize, outputBest] = parseInputs(varargin)
if nargin == 11
    popsize = varargin{2};
    dimension = varargin{3};
    xmax = varargin{4};
    xmin = varargin{5};
    maxiter = varargin{8};
    Func = varargin{9};
    FuncId = varargin{10};
    Fitness = @(candidate) Func(candidate', FuncId);
    isMinimize = true;
    outputBest = @(candidate) candidate;
elseif nargin == 8
    popsize = varargin{1};
    dimension = varargin{2};
    maxiter = varargin{3};
    xmax = varargin{4};
    xmin = varargin{5};
    probR = varargin{6};
    Func = varargin{7};
    Class = varargin{8};
    Fitness = @(candidate) Func(fix(candidate), dimension, probR, Class);
    isMinimize = false;
    outputBest = @(candidate) fix(candidate);
else
    error('AUGO:InvalidInput', 'AUGO expects either 11 PlatECO parameters or 8 segmentation parameters.');
end
end

% =========================================================================
%  External function -- sortedIndex
% =========================================================================
%  Ranking helper. Sorting direction follows the optimization sense, so
%  ind(1) is always the best individual and ind(end) the worst. The UADSAP
%  pool bounds are expressed directly in these rank positions.
% =========================================================================
function ind = sortedIndex(fitness, isMinimize)
if isMinimize
    [~, ind] = sort(fitness);
else
    [~, ind] = sort(fitness, 'descend');
end
end

% =========================================================================
%  External function -- isBetter
% =========================================================================
%  Single comparison primitive, sense-aware. Every greedy decision in the
%  algorithm routes through this function, which is what allows the same
%  search core to serve both a minimization and a maximization interface.
% =========================================================================
function ok = isBetter(candidateFitness, referenceFitness, isMinimize)
if isMinimize
    ok = candidateFitness < referenceFitness;
else
    ok = candidateFitness > referenceFitness;
end
end

% =========================================================================
%  External function -- clampBounds
% =========================================================================
%  Box-constraint projection. Applied to every trial solution before it is
%  evaluated, so no infeasible point ever reaches the objective.
% =========================================================================
function y = clampBounds(y, xmin, xmax)
y = max(y, xmin);
y = min(y, xmax);
end

% =========================================================================
%  External function -- selectID
% =========================================================================
%  Draws `count` distinct indices from 1..popsize, excluding the caller's own
%  index i. Used by the learning stage to form the differential vector
%  x(L1,:) - x(L2,:) from two other individuals.
% =========================================================================
function r = selectID(popsize, i, count)
lists = randperm(popsize);
r = lists(1:count+1);
r(r == i) = [];
r = r(1:count);
end
```

</details>


## 8. 致谢

作者感谢编辑与匿名审稿人付出的时间与详细意见，这些意见改进了本文。基金信息将在评审结束后依照论文实际情况补充于此。


## 版权所有

Copyright (c) 2026 Qingke Zhang. All rights reserved.

源代码 `AUGO.m` 以 [MIT 许可证](LICENSE) 发布。本仓库中的论文、图表与文档归作者所有，未经许可不得转载。配套论文目前正在投审稿阶段；在引用信息更新之前，请按「投审稿中的稿件」引用本工作。详见 [NOTICE.md](NOTICE.md)。


<div align="center">
<sub>山东师范大学 计算机与人工智能学院</sub>
</div>
