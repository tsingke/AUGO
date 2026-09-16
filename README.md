<div align="center">

<h1>AUGO</h1>

<p><b>Asymmetric Undulatory Growth Optimizer / 非对称波动生长优化器</b></p>

<p><i>Normalized evaluation progress as the single scheduling clock, driving three coordinated mechanisms</i></p>

<p><img src="assets/badge-paradigm.svg" alt="Stage-Adaptive">&nbsp;<img src="assets/badge-benchmarks.svg" alt="CEC2017 benchmarks">&nbsp;<img src="assets/badge-matlab.svg" alt="MATLAB">&nbsp;<img src="assets/badge-status.svg" alt="Under Review">&nbsp;<img src="assets/badge-license.svg" alt="MIT License"></p>

</div>


> **Manuscript status.** This repository is the reference implementation companion to a manuscript **under review** at a peer-reviewed journal; the journal name is withheld while the review is in progress. This page is provided for the editor and reviewers, and gives a high-level account of the method and its evaluation — the derivations, the full experimental protocols and the complete result tables are given in the manuscript itself and are **deliberately not reproduced here**.


| | |
|:--|:--|
| **Manuscript** | AUGO: An Asymmetric Undulatory Growth Optimizer for Continuous Optimization |
| **Author** | **Qingke Zhang**\* |
| **Affiliation** | School of Computer Science and Artificial Intelligence, Shandong Normal University, Jinan 250358 |
| **Corresponding author** | [tsingke@sdnu.edu.cn](mailto:tsingke@sdnu.edu.cn) |
| **Status** | Under review — journal name withheld |


**Highlights**

- AUGO provides a progress-aware extension of the Growth Optimizer.
- Three coordinated mechanisms enhance exploration, escape, and refinement.
- AUGO ranks first on CEC2017 at 30D, 50D, and 100D among 31 algorithms.
- AUGO achieves the highest mean Kapur entropy on all ten test images.
- UAV experiments further demonstrate competitive feasibility and robustness.


## Contents

1. [Background and motivation](#1-background-and-motivation)
2. [Method overview](#2-method-overview)
3. [Key contributions](#3-key-contributions)
4. [Framework and mechanisms](#4-framework-and-mechanisms)
5. [Benchmark evaluation](#5-benchmark-evaluation)
6. [Application case studies](#6-application-case-studies)
7. [Reference implementation](#7-reference-implementation)
8. [Acknowledgments](#8-acknowledgments)


## 1. Background and motivation

Population-based metaheuristics attack continuous optimization problems that offer no usable gradient. Their performance turns on one tension no algorithm escapes: enough diversity to survey the space, yet enough intensification around regions that already look promising. Since no optimizer wins across every problem class, the practical question is not which framework is best, but **how far an existing framework can be made to adapt**.

The **Growth Optimizer (GO)** is the baseline here. GO frames continuous optimization as a cooperative *learning–reflection* process — individuals stratified by fitness, a learning stage that builds knowledge increments from gap information, and a reflection stage that adjusts selected dimensions. The framework is compact and carries few control parameters, but its reference selection, reflection regulation and late-stage search are only **weakly coupled to how far the search has progressed**. Three limitations follow:

- **Fixed reference pools.** Ranking intervals stay fixed for the whole run, so selection pressure barely changes across stages.
- **Undirected random resetting.** Reflection may reassign a dimension a value drawn uniformly from the whole search space, discarding what the search has learned.
- **Insufficient local refinement.** No dedicated procedure refines elite regions or the global-best neighbourhood.

<p align="center">
  <img src="figures/fig1_limitation_mapping.png" alt="Mapping from GO limitations to AUGO mechanisms" width="100%">
</p>

<p align="center">
  <em><b>Figure 1.</b> Conceptual correspondence between the limitations of GO, the proposed AUGO mechanisms, and their intended search effects.</em>
</p>

AUGO addresses these three limitations without altering the basic learning–reflection structure. Its search behaviour is regulated by a single quantity — normalized function-evaluation progress — so reference selection, reflection and escape, and local refinement all shift together as the budget is consumed.


## 2. Method overview

AUGO keeps the initialization, boundary handling, greedy selection and growth-update principles of GO intact. Three mechanisms are layered onto different parts of the search, all scheduled by the same normalized progress variable.

**UADSAP** — Undulatory Annealing Dynamic State-Aware Pool — regulates *where reference individuals come from*. Sampling bounds are driven by an undulatory annealing factor that decays smoothly across the run: the pools are wide early, so individuals learn from a broad cross-section of the population, and contract toward the extreme ranks late, concentrating the guidance.

**AT-CQ** — Asymmetric Time-varying Reflection and Cauchy Quantum Escape — regulates *how reflection behaves*. Instead of resetting a dimension to a uniformly sampled value, reflection moves it toward a superior reference, weighted by a factor whose expected magnitude shrinks as the run proceeds. A separate escape event with decaying activation probability occasionally overwrites the guided value, either with a uniform reset or with a heavy-tailed jump scaled by the distance to the incumbent.

**UDGF** — Unified Differential-Gaussian Field — supplies *late-stage refinement* at two levels: elite individuals are perturbed along population-difference vectors with contracting Gaussian noise, and a budget-constrained search explores the incumbent's neighbourhood over a randomly activated subset of coordinates. The neighbourhood search stays off during the first 20% of the budget.

The three mechanisms **do not compete for the same evaluations** — UADSAP changes what the learning stage is told, AT-CQ changes how reflection corrects, and UDGF adds refinement the original framework never had.

<p align="center">
  <img src="figures/fig2_mechanism_schedule.png" alt="Stage-wise schedules of the three AUGO mechanisms" width="100%">
</p>

<p align="center">
  <em><b>Figure 2.</b> Stage-wise schedules of the three mechanisms, under N = 40, ρ<sub>p</sub> = 0.5, p<sub>q</sub><sup>max</sup> = 0.10, η<sub>B</sub> = 0.20, MaxFEs = 300,000. Every schedule moves in the same direction — from broad to focused — and every one is indexed by the same progress variable.</em>
</p>


## 3. Key contributions

- **A progress-aware extension that preserves the original framework.** GO's learning–reflection structure is retained; budget consumption, not a learned policy, is the scheduling signal, at no extra learning cost.
- **Three mechanisms mapped onto three identified limitations.** UADSAP, AT-CQ and UDGF resolve the fixed-pool, undirected-resetting and missing-refinement limitations respectively, forming a progressive search architecture rather than independent add-ons.
- **A large-scale evaluation with ablation and sensitivity evidence.** Against 30 baselines including the original GO, on CEC2017 at three dimensions under identical budgets, with leave-one-out ablation isolating each mechanism.
- **Transfer to two structurally different applications.** Without task-specific redesign, the same implementation is applied to Kapur-entropy multilevel thresholding and constrained 3-D UAV path planning.


## 4. Framework and mechanisms

AUGO terminates on an evaluation budget rather than a fixed iteration count, which is what lets every schedule be written as a function of progress. UADSAP regulates reference sampling, AT-CQ performs guided reflection and escape, and UDGF then runs its two refinement operations, with the neighbourhood search activated only after 20% of the budget.

<p align="center">
  <img src="figures/fig3_flowchart.png" alt="AUGO algorithm flowchart" width="100%">
</p>

<p align="center">
  <em><b>Figure 3.</b> Overall workflow of AUGO and the interaction among UADSAP, AT-CQ, and UDGF.</em>
</p>

Two architectural properties are worth stating, with the formal treatment left to the manuscript.

**The mechanisms act on disjoint components.** No two modify the same update rule, so the composition is additive rather than entangled: each can be ablated cleanly, and the ablation study confirms that all three contribute.

**The extension does not raise the asymptotic cost.** The added work per cycle is constant-factor only, so the overall time complexity remains the same asymptotic order as the original GO and the core storage requirement is unchanged — the mechanism set buys adaptivity without buying a higher growth rate.


## 5. Benchmark evaluation

| | |
|:--|:--|
| Benchmark | CEC2017 single-objective suite, F1–F30 (unimodal, simple multimodal, hybrid, composition), search range [−100, 100] |
| Dimensions | 30, 50, 100 |
| Comparison set | 31 algorithms — AUGO plus 30 baselines across evolutionary, swarm, physics-, mathematics- and human-behaviour-inspired families, including the original GO |
| Protocol | Identical evaluation budget per dimension, uniform random initialization, 20 independent runs per algorithm per function |
| Statistics | Two-sided Wilcoxon rank-sum test for pairwise significance, Friedman rank test for overall ranking, α = 0.05 |
| Headline result | AUGO ranked **first at all three dimensions** (mean Friedman rank 4.557); the closest competitor at every dimension is the original GO |

Against the original GO the picture improves with dimensionality, with the most pronounced advantage on the simple multimodal group — though the gains are **not universal**, and GO retains a significant advantage on a small number of functions. The manuscript reports the per-function comparisons, the ablation study and the parameter sensitivity analysis in full; both support the design, since no mechanism is redundant and the algorithm does not require highly specific parameter settings within the tested ranges.


## 6. Application case studies

Benchmarks measure solution quality under a fixed protocol; they do not test whether an optimizer can be dropped into a problem whose decision structure, feasibility conditions and objective landscape are set by someone else. AUGO is therefore applied — with no task-specific redesign of the search core — to two such problems.

### Kapur-entropy multilevel image thresholding

Each candidate is an ordered set of gray-level thresholds, scored by the Kapur entropy summed over the regions they induce; the objective is maximized and difficulty grows with the threshold count. Ten grayscale images — five classical benchmarks, five application-oriented — are tested across threshold counts from 2 to 20, with 20 independent runs each against five other algorithms. The fidelity measures reported quantify **reconstruction fidelity, not semantic segmentation accuracy**.

AUGO attains the highest mean final entropy on all ten images at every tested threshold count from 8 onward; at the lowest counts the leading algorithms converge to nearly identical entropy, as expected when the landscape is comparatively smooth. The advantage therefore **emerges as the problem becomes harder**. Because the fidelity measures derive from the threshold vector that maximizes Kapur entropy, they need not be jointly optimal — the evidence supports competitiveness on the objective actually being optimized, not across-the-board superiority.

<p align="center">
  <img src="figures/fig4_segmentations.png" alt="AUGO segmentations with 20 thresholds" width="100%">
</p>

<p align="center">
  <em><b>Figure 4.</b> Twenty-threshold Kapur reconstructions produced by AUGO across the test set.</em>
</p>

### Constrained three-dimensional UAV path planning

Ten intermediate waypoints give a 30-dimensional decision vector. A shared decoding chain maps any candidate to a flyable trajectory — waypoints ordered by projected progress, joined by piecewise cubic Hermite interpolation, resampled by arc length, and deterministically repaired to satisfy terrain clearance. Every compared algorithm uses the same decoder, so the comparison isolates the search itself. Cost combines path length, clearance, smoothness, obstacle and threat penalties, turn and climb feasibility, and altitude variation, with a large penalty applied when any violation count is non-zero.

Four deterministic scenarios of increasing constraint complexity are used, 30 independent runs each with seeds matched across algorithms. Solutions are re-validated with a far denser sample set than the optimization objective uses, and a path counts as successful only when all violation counts are zero. Significance is assessed with exact paired tests — McNemar for success rates, sign test for cost and length — with Holm correction within each test family.

AUGO produces the highest pooled success rate and the lowest mean paired rank of the six algorithms, and is strongest where the problem is hardest and most open — it is one of only two algorithms to produce paths surviving dense validation in the most restricted scenario. These advantages are **not uniform**, and the manuscript reports where they do not hold: AUGO does not reach full feasibility, it is outperformed on specific scenarios and on individual metrics such as median cost, and one competitor achieves a significantly lower cost in one scenario after correction. The experiment supports competitive, robust performance under dense deterministic validation — not dominance on every metric.

<p align="center">
  <img src="figures/fig5_uav_paths.png" alt="Representative UAV paths across the four scenarios" width="100%">
</p>

<p align="center">
  <em><b>Figure 5.</b> Representative feasible paths across the four scenarios, illustrating typical path geometry.</em>
</p>


## 7. Reference implementation

The reference implementation is a single self-contained MATLAB function with no external dependencies beyond the caller-supplied objective. It detects two argument layouts automatically: an 11-argument benchmark interface and an 8-argument segmentation interface.

```matlab
% --- Benchmark interface (CEC / PlatECO) -------------------------------
% AUGO(mainHandle, popsize, dimension, xmax, xmin, vmax, vmin, ...
%      maxiter, Func, FuncId, VisualSwitch)
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    [], 40, 30, 100, -100, [], [], 7500, @myObjective, 1, false);

% --- Segmentation interface -------------------------------------------
% AUGO(popsize, dimension, maxiter, xmax, xmin, probR, Func, Class)
% The objective is maximized internally, so Func returns the Kapur entropy.
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    40, D, 150, 255, 0, probR, @kapurObjective, imageClass);
```

The full annotated source is [`AUGO.m`](AUGO.m) at the repository root — 576 lines, 43% of them comments, organized by algorithm module (input parsing, initialization, the four main-loop stages, and the helper functions). It is reproduced in full below. The benchmark protocol uses an initial population size of `N = 40`; all default parameters are documented in the file header.

<details>
<summary><b>Click to expand the full <code>AUGO.m</code> source (576 lines, modular comments)</b></summary>

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


## 8. Acknowledgments

The author thanks the editor and the anonymous reviewers for their time and their detailed comments, which have improved the manuscript. Funding information will be recorded here in accordance with the manuscript once the review process concludes.


## Copyright

Copyright (c) 2026 Qingke Zhang. All rights reserved.

The source code `AUGO.m` is released under the [MIT License](LICENSE). The manuscript, figures and documentation in this repository remain the property of the author and may not be redistributed without permission. The companion manuscript is currently under review; until the citation record is updated, please cite this work as a manuscript under review. See [NOTICE.md](NOTICE.md) for details.


<div align="center">
<sub>School of Computer Science and Artificial Intelligence, Shandong Normal University</sub>
</div>
