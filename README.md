<div align="center">

<h1>AUGO</h1>

<p><b>Asymmetric Undulatory Growth Optimizer / 非对称波动生长优化器</b></p>

<p><i>Normalized evaluation progress as the single scheduling clock, driving three coordinated mechanisms</i></p>

<p><img src="assets/badge-paradigm.svg" alt="Stage-Adaptive">&nbsp;<img src="assets/badge-benchmarks.svg" alt="CEC2017 benchmarks">&nbsp;<img src="assets/badge-matlab.svg" alt="MATLAB">&nbsp;<img src="assets/badge-status.svg" alt="Under Review">&nbsp;<img src="assets/badge-license.svg" alt="MIT License"></p>

</div>


> **Manuscript status.** This repository is the reference implementation and documentation for a companion manuscript. The manuscript is currently **under review** at a peer-reviewed journal. The journal name is withheld while the review is in progress. The code, figures, and documentation here describe the submitted version and may be revised once the review concludes.


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

Population-based metaheuristics attack continuous optimization problems that offer no usable gradient — problems that are nonlinear, nonconvex, multimodal, high-dimensional, or simply black-box. Their performance turns on a single tension that no algorithm escapes: maintaining enough diversity to survey the space, while intensifying the search around regions that have already proven promising. Since no optimizer wins across every problem class, the practical question is not which framework is best but how far an existing framework can be made to adapt.

The **Growth Optimizer (GO)** is the baseline this work builds on. GO frames continuous optimization as a cooperative *learning–reflection* process: individuals are stratified by fitness, the learning stage constructs knowledge increments from gap information among them, and the reflection stage adjusts selected dimensions to sharpen local exploitation. The framework is compact and carries few control parameters. But its reference selection, reflection regulation, and late-stage search are only weakly coupled to how far the search has actually progressed, which becomes restrictive on complex multimodal and high-dimensional landscapes.

Three specific limitations follow from that weak coupling:

**Fixed reference pools.** GO samples its superior and inferior reference individuals from ranking intervals that stay fixed for the entire run. Selection pressure therefore barely changes across stages — which can cost diversity early and leave the search direction insufficiently concentrated late.

**Undirected random resetting.** During reflection, selected dimensions may be reassigned values drawn uniformly from the whole search space. This restores diversity, but it discards everything the search has learned about promising regions. Late in the run such unguided resets spend evaluations without improving the solution, and they can disturb population structures that were already working.

**Insufficient local refinement.** GO has no dedicated procedure for refining elite regions or the neighbourhood of the current global-best solution. Once the population has settled into a promising basin, gap-based learning and dimension-wise reflection are too coarse-grained to extract further accuracy.

<p align="center">
  <img src="figures/fig1_limitation_mapping.png" alt="Mapping from GO limitations to AUGO mechanisms" width="100%">
</p>

<p align="center">
  <em><b>Figure 1.</b> Conceptual correspondence between the limitations of GO, the proposed AUGO mechanisms, and their intended search effects.</em>
</p>

AUGO addresses these three limitations without altering the basic learning–reflection structure of GO. Its search behaviour is regulated by a single quantity — normalized function-evaluation progress — so that reference selection, reflection and escape, and local refinement all shift together as the budget is consumed.

<p align="center">
  <img src="figures/fig2_go_principle.png" alt="Principle of the Growth Optimizer" width="94%">
</p>

<p align="center">
  <em><b>Figure 2.</b> The learning–reflection principle of the Growth Optimizer on which AUGO is built.</em>
</p>


## 2. Method overview

AUGO keeps the population initialization, boundary handling, greedy selection, and growth-update principles of GO intact. Three mechanisms are layered onto different parts of the original search process. All three are scheduled by the same normalized progress variable `τ(t) = t / T`, where `t` counts function evaluations already consumed (initialization included) and `T` is the evaluation budget.

**UADSAP** — the Undulatory Annealing Dynamic State-Aware Pool — regulates *where reference individuals are drawn from*. An undulatory annealing factor `α(t) = (cos(πτ(t)) + 1) / 2` decreases smoothly from near 1 toward 0, and drives the sampling bounds of both the superior and the inferior pool. Early in the run the pools are wide, so individuals learn from a broad cross-section of the population; as the run proceeds both pools contract toward the top-ranked and bottom-ranked individuals respectively, concentrating the guidance.

**AT-CQ** — Asymmetric Time-varying Reflection and Cauchy Quantum Escape — regulates *how reflection behaves*. Instead of resetting a dimension to a uniformly sampled value, reflection moves it toward the corresponding coordinate of a superior reference individual, weighted by a time-varying factor whose expected magnitude shrinks as the run progresses. A separate escape event, activated with a probability that decays from `p_q^max` to 0.01, replaces the guided value — half the time with a uniform reset, half the time with a Cauchy-distributed heavy-tailed perturbation scaled by the distance to the current global best.

**UDGF** — the Unified Differential-Gaussian Field — supplies *late-stage local refinement* at two levels. The first subprocess perturbs elite individuals along population-difference vectors with dimension-wise Gaussian noise and a contracting factor `(1 − τ(t))`. The second performs a budget-constrained search around the current global-best solution, using partial-dimensional Gaussian/Cauchy perturbations on a mask that activates each coordinate with probability 0.25. The global-best neighbourhood search is switched off during the first 20% of the budget and draws on a bounded share of the remaining evaluations thereafter.

The design intent is that the three mechanisms do not compete for the same evaluations. UADSAP changes what the learning stage is told, AT-CQ changes how reflection corrects, and UDGF adds refinement the original framework never had — each operating on a different component, all reading the same progress clock.


## 3. Key contributions

**A progress-aware extension that preserves the original framework.** AUGO retains GO's learning–reflection structure and regulates its search behaviour through normalized function-evaluation progress. Rather than adding a learned decision policy, it uses budget consumption as the scheduling signal — so reference selection, reflection and escape, and local refinement all shift together, at no extra learning cost.

**Three mechanisms that map onto three identified limitations.** UADSAP contracts the fitness-ranked reference pools as the search advances, resolving GO's fixed-pool limitation. AT-CQ couples guided, time-varying reflection with a decaying heavy-tailed escape, resolving the undirected-resetting limitation. UDGF adds differential-Gaussian refinement of elite regions plus a budget-constrained global-best neighbourhood search, resolving the missing-refinement limitation. Together they establish a progressive search architecture.

**A large-scale comparative evaluation with ablation and sensitivity evidence.** AUGO is compared against 30 baseline algorithms — including the original GO — on the CEC2017 suite at 30, 50, and 100 dimensions under identical evaluation budgets, using convergence analysis, Wilcoxon and Friedman nonparametric tests, single-factor parameter sensitivity analysis, and leave-one-out ablation. The ablation isolates the contribution of each mechanism rather than treating the design as a monolith.

**Transfer to two structurally different application problems.** The same implementation is applied without task-specific redesign to Kapur-entropy multilevel image thresholding and to constrained three-dimensional UAV path planning — problems whose decision structures, feasibility conditions, and objective landscapes differ substantially from CEC benchmarks.


## 4. Framework and mechanisms

AUGO terminates on an evaluation budget rather than a fixed iteration count, so every schedule below is written as a function of `τ(t)`. The flowchart gives the control flow: UADSAP regulates dynamic sampling of the superior and inferior reference individuals, AT-CQ performs guided reflection and probabilistic escape, and UDGF then runs its two complementary refinement operations — with the global-best neighbourhood search activated only once `τ(t) > 0.2` and constrained by the remaining budget.

<p align="center">
  <img src="figures/fig4_flowchart.png" alt="AUGO algorithm flowchart" width="88%">
</p>

<p align="center">
  <em><b>Figure 3.</b> Overall workflow of AUGO and the interaction among UADSAP, AT-CQ, and UDGF.</em>
</p>

<p align="center">
  <img src="figures/fig3_mechanism_schedule.png" alt="Stage-wise schedules of the three AUGO mechanisms" width="88%">
</p>

<p align="center">
  <em><b>Figure 4.</b> Stage-wise schedules of the three mechanisms, under N = 40, ρ<sub>p</sub> = 0.5, p<sub>q</sub><sup>max</sup> = 0.10, η<sub>B</sub> = 0.20, MaxFEs = 300,000. (a) Dynamic superior and inferior reference pools. (b) Expected AT-CQ reflection weight with its 10th–90th percentile interval. (c) Conditional escape probability p<sub>q</sub>(t) and the effective per-dimension probability P<sub>3</sub>p<sub>q</sub>(t). (d) Coarse-to-fine UDGF perturbation scales and activation of the global-best neighbourhood refinement.</em>
</p>

The four panels above are the clearest single view of the design: every schedule moves in the same direction — from broad to focused — and every one is indexed by the same progress variable.

**UADSAP: contracting reference pools.** The undulatory annealing factor `α(t) = (cos(πτ(t)) + 1) / 2` decays smoothly from near 1 to 0. It sets the dynamic upper bound of the superior pool,

```
u_b(t) = round( 5 + (u_max − 5)·α(t) ),   u_max = max(5, round(ρ_p·N))
```

and the dynamic lower bound of the inferior pool,

```
l_w(t) = round( (N − 4) − [ (N − 4) − l_min ]·α(t) ),   l_min = min(N − 4, round(ρ_p·N))
```

with `ρ_p` the reference-pool rank-boundary ratio, fixed at 0.5 unless stated otherwise. The superior reference is then sampled uniformly from ranks `2 … u_b(t)` — starting at rank 2 because rank 1 is the current best, which would otherwise serve as both the best solution and its own reference. The inferior reference is sampled from ranks `l_w(t) … N`. Early on, both pools are wide and the learning stage draws on a broad cross-section of the population. As `α(t)` falls, `u_b(t)` approaches 5 and `l_w(t)` approaches `N − 4`, so both pools concentrate on the extreme ranks and the gap-based guidance sharpens.

**AT-CQ: guided reflection with decaying escape.** When reflection fires on dimension `j` of individual `i`, the coordinate moves toward a superior reference rather than jumping to a random value:

```
x_{i,j}^{t+1} = x_{i,j}^t + ( x_{R,j}^t − x_{i,j}^t )·ω(t),   ω(t) = r^{1 + 0.5τ(t)},  r ~ U(0,1)
```

Since the exponent `1 + 0.5τ(t)` grows with progress, the expected weight `E[ω(t)] = 1 / (2 + 0.5τ(t))` and every quantile `Q_p[ω(t)] = p^{1 + 0.5τ(t)}` shrink monotonically — reflection becomes conservative late in the run. Conditional on entering the reflection branch, an escape event fires with probability

```
p_q(t) = 0.01 + ( p_q^max − 0.01 )·( 1 − τ(t) )
```

decaying from `p_q^max = 0.10` to 0.01. Once triggered, the escape resolves with equal probability into either a uniform random reset, `x_{i,j}^{t+1} = lb_j + (ub_j − lb_j)·r`, or a Cauchy heavy-tailed perturbation around the current global best,

```
x_{i,j}^{t+1} = x_{best,j}^t + tan[ π(r − 0.5) ]·| x_{best,j}^t − x_{i,j}^t |
```

whose magnitude is scaled by the distance to the global best. The two escape branches are mutually exclusive and overwrite the guided value. Since the reflection branch itself fires with probability `P_3`, the effective per-dimension rates of leaving a coordinate unchanged, keeping the guided update, resetting uniformly, and applying Cauchy perturbation are `1 − P_3`, `P_3[1 − p_q(t)]`, `0.5·P_3·p_q(t)`, and `0.5·P_3·p_q(t)`.

**UDGF: two levels of local refinement.** The elite-region subprocess builds a differential vector `v^t = x_{r1}^t − x_{r2}^t` from two distinct population members and perturbs an elite base individual along it:

```
u^t = x_base^t + ε^t ⊙ v^t·( 1 − τ(t) ),   ε^t ~ N(0, I)
```

so the perturbation scale in each dimension stays tied to observed population differences rather than to an independent random displacement, and contracts as `(1 − τ(t))` falls. Greedy selection replaces the base individual only on strict improvement.

The global-best neighbourhood subprocess draws on a bounded budget,

```
B(t) = 0                                          if τ(t) ≤ 0.2
     = min( max(8, ceil(η_B·N)), T − t )          if τ(t) > 0.2
```

with `η_B = 0.20`; the `T − t` term keeps refinement from overshooting the evaluation budget. Its perturbation scale is `σ(t) = (ub − lb)·[0.06(1 − τ(t)) + 0.004]`, applied only to coordinates activated by a Bernoulli(0.25) mask, and the perturbation is Gaussian with probability 0.75 and Cauchy with probability 0.25 — the heavy tail retained so that occasional larger deviations remain possible inside an otherwise local search:

```
ε_j(t) = N(0, σ²(t))                        with probability 0.75
       = 0.5·σ(t)·tan[ π(r − 0.5) ]         with probability 0.25
u_j = x_{best,j}^t + m_j·ε_j(t)
```

Greedy selection again applies, so the global-best solution never degrades.

**Computational complexity.** With `N` the population size, `D` the dimension, `T` the evaluation budget, and `C_f(D)` the cost of one objective evaluation, the population is sorted at most three times per cycle. UADSAP's own overhead is scalar reference-pool regulation and index sampling, and is negligible. The learning and AT-CQ stages each process `N` candidates for `O(ND)`, the elite-region subprocess generates a fixed `K = 5` trials for `O(KD)`, and the neighbourhood subprocess `B_i` candidates for `O(B_i·D)`. Excluding objective evaluations, one complete cycle therefore costs

```
O( N log N + (2N + K + B_i)·D )
```

Each cycle consumes at least `2N + K` evaluations, bounding the number of completed cycles by `I_AUGO = O(T / N)`, so cumulative sorting is `O(T log N)`. The overall time complexity is

```
C_AUGO = O( T·C_f(D) + T·D + T·log N ) = O( T·( C_f(D) + D + log N ) )
```

which is **the same asymptotic order as the original GO** — the three mechanisms add constant-factor work, not a higher growth rate. Ignoring objective evaluations, the internal cost is `O(T(D + log N))`. Core storage is `O(ND + N + D) = O(ND)`; the experimental implementation carries an additional `O(T)` to record convergence curves, giving `O(ND + T)`.


## 5. Benchmark evaluation

AUGO is evaluated on the CEC2017 single-objective suite — functions F1–F30, spanning unimodal (F1–F3), simple multimodal (F4–F10), hybrid (F11–F20), and composition (F21–F30) groups, all on the search range [−100, 100] with fitness error measured against the known optimum.

**Setup.** Dimensions 30, 50, and 100; population size `N = 40` at every dimension; evaluation budget `MaxFEs = 10000·D` (300,000 / 500,000 / 1,000,000); uniform random initialization; 20 independent runs per algorithm per function. Comparisons use the two-sided Wilcoxon rank-sum test for pairwise significance and the Friedman rank test for overall ranking, both at `α = 0.05`. AUGO is compared with **30 baseline algorithms** — 31 algorithms in total — spanning evolutionary computation, swarm intelligence, physics- and mathematics-inspired methods, human-behaviour-inspired methods, and biological/biochemical-inspired methods, with proposal years from 1975 to 2025. The baseline set includes the original Growth Optimizer.

### Overall ranking

| Setting | AUGO Friedman mean rank | Placement |
|:--|:--:|:--:|
| CEC2017 @ 30D | 4.940 | 1st |
| CEC2017 @ 50D | 4.070 | 1st |
| CEC2017 @ 100D | 4.660 | 1st |
| **Mean over three dimensions** | **4.557** | **1st of 31** |

AUGO attains the best Friedman average rank at every one of the three dimensional settings, and the best overall mean rank of 4.557 across all 31 algorithms. The closest competitor at each dimension is the original GO, at a mean rank of 5.133; the next closest are JADE (7.277), GSK (7.900), and CEO (10.463). The margin is not uniform across the field — the gap to GO is real but modest, while a large tail of baselines ranks far behind.

### Pairwise comparison against the original GO

| Dimension | Win / Tie / Loss vs GO |
|:--|:--:|
| 30D | 10 / 13 / 7 |
| 50D | 10 / 15 / 5 |
| 100D | 15 / 13 / 2 |
| **All 90 function–dimension cases** | **35 / 41 / 14** |

Against GO the picture improves with dimensionality: at 100D, AUGO wins on 15 functions, ties on 13, and loses on only 2. The most pronounced advantage is on the simple multimodal group, where AUGO significantly outperforms GO on six of the seven functions. GO does retain significantly better performance on F14 and F22 — the gains are not universal, which is consistent with a mechanism set that changes how the search is scheduled rather than what the search can represent.

<p align="center">
  <img src="figures/fig5_convergence_30d_f20.png" alt="Convergence on F20 at 30D" width="72%">
</p>

<p align="center">
  <em><b>Figure 5.</b> Mean convergence on CEC2017 F20 (hybrid) at 30D across 20 independent runs. AUGO achieves the best final mean error on F20 and F30 among all 31 algorithms at this dimension.</em>
</p>

<p align="center">
  <img src="figures/fig6_convergence_30d_f30.png" alt="Convergence on F30 at 30D" width="72%">
</p>

<p align="center">
  <em><b>Figure 6.</b> Mean convergence on CEC2017 F30 (composition) at 30D. Composition functions are the group on which late-stage refinement mechanisms are expected to matter most.</em>
</p>

<p align="center">
  <img src="figures/fig7_convergence_100d_f30.png" alt="Convergence on F30 at 100D" width="72%">
</p>

<p align="center">
  <em><b>Figure 7.</b> Mean convergence on CEC2017 F30 at 100D, where AUGO wins on 15 functions, ties on 13, and loses on only 2 against GO.</em>
</p>

<p align="center">
  <img src="figures/fig8_boxplot_30d_f20.png" alt="Boxplot on F20 at 30D" width="72%">
</p>

<p align="center">
  <em><b>Figure 8.</b> Distribution of final errors on CEC2017 F20 at 30D over 20 runs. Boxplots show run-to-run spread rather than mean behaviour alone.</em>
</p>

### Ablation study

Three leave-one-out variants were run under the same CEC2017 30D protocol. The win/tie/loss counts are stated with respect to the complete AUGO — that is, they count the functions on which AUGO is significantly better than, indistinguishable from, or significantly worse than the variant.

| Variant | Best mean count | +/≈/− vs AUGO | Friedman mean rank |
|:--|:--:|:--:|:--:|
| **AUGO (complete)** | **9** | — | **2.31** |
| AUGO w/o UDGF | 9 | 4 / 25 / 1 | 2.40 |
| AUGO w/o UADSAP | 8 | 10 / 14 / 6 | 2.57 |
| AUGO w/o AT-CQ | 4 | 11 / 15 / 4 | 2.73 |

The ablation separates the three mechanisms cleanly. **AT-CQ carries the largest load**: removing it produces the largest deterioration in Friedman average rank (2.73), the worst of the three variants. UADSAP is the next most consequential (2.57). UDGF's contribution at 30D is comparatively moderate (2.40) but still favourable — the pattern one would expect from a mechanism whose global-best neighbourhood search only activates after 20% of the budget and which matters most once the population has already concentrated. The complete algorithm ranks first among all variants, so no mechanism is redundant.

### Parameter sensitivity

Single-factor sensitivity analysis varied three parameters over F1 (unimodal), F10 (simple multimodal), F20 (hybrid), and F30 (composition) at all three dimensions.

| Parameter | Tested range | Default | Observed sensitivity |
|:--|:--|:--:|:--|
| `ρ_p` (reference-pool rank-boundary ratio) | 0.3 – 0.7 | 0.5 | Relatively stable; no single value consistently best |
| `p_q^max` (maximum escape probability) | 0.05 – 0.15 | 0.10 | Most noticeable influence on convergence behaviour |
| `η_B` (neighbourhood refinement budget ratio) | 0.10 – 0.30 | 0.20 | Limited sensitivity; differences moderate |

The most sensitive parameter is the escape probability ceiling `p_q^max` — raising it too far introduces disruptive perturbations and costs convergence accuracy, which matches the mechanism's purpose. The refinement budget ratio `η_B` shows limited sensitivity, and `ρ_p` is relatively stable across its range. Overall, AUGO does not require highly specific parameter settings to stay competitive within the tested ranges.


## 6. Application case studies

Benchmarks measure solution quality under a fixed protocol. They do not test whether an optimizer can be dropped into a problem whose decision structure, feasibility conditions, and objective landscape are set by someone else. AUGO is therefore applied — with no task-specific redesign of the search core — to two such problems.

### Kapur-entropy multilevel image thresholding

Each candidate solution is an ordered set of `D` gray-level thresholds, mapped deterministically to a feasible vector, and scored by Kapur entropy summed over the `(D + 1)` regions the thresholds induce. The objective is maximized, difficulty grows with `D`, and reconstruction is by lower-bound gray-level quantization — yielding a `(D + 1)`-level reconstruction rather than a binary foreground mask. Reported fidelity measures (MSE, PSNR, MaxAE, SSIM, FSIM) therefore quantify **reconstruction fidelity, not semantic segmentation accuracy** — an important distinction when reading the numbers below.

**Setup.** Ten grayscale test images: five classical benchmarks (Airplane, Peppers, Sailboat, Monkey, Tank) and five application-oriented ones (Steel Defect, Brain MRI, Chest X-ray, Crack, Remote Sensing). Threshold counts `D ∈ {2, 4, 6, 8, 10, 15, 20}`, giving 3 to 21 regions. Population 40, 150 iterations — a 6000-evaluation budget — and 20 independent runs per image per `D`. Six algorithms are compared: AUGO, GO, JADE, GSK, CEO, and DE/rand/1.

<p align="center">
  <img src="figures/fig10_test_images.png" alt="Test images and their histograms" width="70%">
</p>

<p align="center">
  <em><b>Figure 9.</b> The ten test images and their gray-level histograms. The set spans classical benchmarks and application-oriented images with substantially different gray-level distributions and structural characteristics.</em>
</p>

**Results.** AUGO obtains the highest mean final entropy on **7 of the 10 images at D = 4** and on **6 images at D = 6** — at low threshold counts the leading algorithms converge to nearly identical final entropy, as expected when the objective landscape is comparatively smooth. **From D = 8 onward, AUGO achieves the highest mean final entropy on all ten images at every tested threshold count.** Its average reconstruction measures improve monotonically with `D`:

| Threshold count | Mean PSNR (dB) | Mean MSE | Mean MaxAE | Mean SSIM | Mean FSIM | Mean time (s) |
|:--|:--:|:--:|:--:|:--:|:--:|:--:|
| D = 2 | 14.976 | 2125.827 | 102.5 | 0.5530 | 0.6923 | 0.433 |
| D = 20 | 31.253 | 50.419 | 19.0 | 0.9375 | 0.9716 | 1.151 |

Runtime stays modest and grows sub-linearly in practice: AUGO remains faster than GO and GSK, and is of the same order as JADE, CEO, and DE/rand/1.

<p align="center">
  <img src="figures/fig11_segmentations.png" alt="AUGO segmentations with 20 thresholds" width="62%">
</p>

<p align="center">
  <em><b>Figure 10.</b> Twenty-threshold Kapur reconstructions produced by AUGO across the test set.</em>
</p>

The claim here is deliberately bounded. AUGO's advantage in final Kapur entropy **emerges as `D` increases**; on low-dimensional thresholding problems it is *comparable* to the alternatives rather than dominant. And because the fidelity measures are computed from the threshold vector that maximizes Kapur entropy, they need not be jointly optimal — a solution with the highest entropy can be marginally behind on PSNR or SSIM for a given image. The evidence supports strong competitiveness on the objective that is actually being optimized, not across-the-board superiority on every fidelity metric.

### Constrained three-dimensional UAV path planning

Ten intermediate waypoints give a 30-dimensional decision vector, with all coordinates constrained to [0, 100]. A shared decoding chain maps any candidate to a flyable trajectory: waypoints are ordered by projected progress from start to end, joined by **piecewise cubic Hermite interpolation**, resampled uniformly by arc length, and deterministically repaired — any waypoint or interpolated sample violating the minimum terrain clearance is raised by a 2-unit margin. Every compared algorithm uses this same decoder, ordering, interpolation, resampling, and repair, so the comparison isolates the search.

The nominal cost combines seven terms — path length, terrain clearance (height), smoothness, spherical-obstacle penalty, threat-zone penalty, turn/climb-angle feasibility, and altitude variation — with weights `(λ_h, λ_s, λ_o) = (250, 8, 5000)` and `(λ_t, λ_a, λ_z) = (2500, 800, 1.2)`. A feasibility penalty `P_fea` is added when any violation count is non-zero, with `B = 10⁷` and coefficients `ρ_c = 2×10⁵`, `ρ_v = 5×10⁴`, `ρ_t = 10⁵`, `ρ_q = 10³`, `ρ_n = 10⁻³`. Hard limits include a minimum terrain clearance of 8, a maximum turn angle of 80°, and a maximum climb angle of 35°, over a 121×121 terrain grid.

**Setup.** Four deterministic scenarios with increasing constraint complexity: S1 (3 spherical obstacles, 2 threat zones), S2 (8 obstacles, 5 threats), S3 (a single restricted gap, 8 obstacles, 2 threats), and S4 (multiple alternative corridors, 8 obstacles, 4 threats). Population 60, a 60,000-evaluation budget, and 30 independent runs per scenario — 120 validation runs per algorithm. Objectives are evaluated with 200 arc-length samples during optimization, and every selected solution is then re-validated deterministically with **2000 samples**; turn and climb angles are checked on a fixed 200-sample grid. A path counts as **successful only when all violation counts are zero**. Seed-matched pairing is used (base seed 20260604), with an exact paired McNemar test for success rates, an exact paired sign test for cost and length, Holm correction within each test family, and `α = 0.05`. Environment: MATLAB R2024b.

| Algorithm | Feasible | Success (%) | Wilson 95% CI | Median cost | Median length | Mean violations | Mean runtime (s) | Mean paired rank |
|:--|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **AUGO** | **76/120** | **63.33** | [54.42, 71.42] | 186.39 | 164.40 | 5.24 | 123.49 | **2.53** |
| GO | 68/120 | 56.67 | [47.73, 65.19] | 219.09 | 179.18 | 16.13 | 131.62 | 3.36 |
| JADE | 63/120 | 52.50 | [43.63, 61.22] | 243.08 | 191.15 | **4.37** | 130.37 | 3.61 |
| GSK | 53/120 | 44.17 | [35.60, 53.10] | **173.12** | **157.84** | 24.08 | 127.39 | 3.63 |
| DE/rand/1 | 62/120 | 51.67 | [42.81, 60.42] | 187.69 | 164.90 | 27.19 | **116.45** | 3.63 |
| CEO | 42/120 | 35.00 | [27.05, 43.88] | 244.76 | 192.75 | 26.42 | 128.21 | 4.23 |

AUGO produces the highest pooled success rate and the lowest mean paired rank of the six. At the scenario level it is strongest where the problem is hardest and most open: in S4, which offers multiple alternative corridors, it reaches the highest observed success rate at 60.00%, and in the severely restricted S3 it is one of only two algorithms (with JADE, both at 16.67%) to produce paths that survive dense validation at all — GSK and DE/rand/1 produced none. Under Holm-corrected paired tests, AUGO's success-rate advantage is significant in S2 against CEO (+63.33 percentage points, `p = 4.20×10⁻⁴`) and in S4 against GSK (+53.33 points, `p = 7.65×10⁻³`); in S1 its feasible-path cost is significantly lower than GO (`Δ = −28.32`, `p = 3.12×10⁻²`), JADE (`Δ = −35.08`, `p = 4.66×10⁻³`), and CEO (`Δ = −61.99`, `p = 1.20×10⁻²`), and its paths are significantly shorter than GO's (`Δ = −22.68`, `p = 7.32×10⁻³`).

Those advantages are not uniform, and the table shows why. **AUGO does not reach full feasibility**, and in S1 JADE succeeds on 29 of 30 runs against AUGO's 28; in S2 both GSK and DE/rand/1 reach 86.67% against AUGO's 83.33%. Pooled across scenarios GSK attains the lowest median cost and median length, and JADE the fewest mean violations. In a Holm-corrected reverse result, GSK's feasible-path cost in S1 is significantly *lower* than AUGO's (`Δ = +20.91`, `p = 1.20×10⁻²`). What the experiment supports is that AUGO delivers competitive, robust performance under dense deterministic validation and is particularly effective in the harder, more open scenarios — not that it dominates every scenario on every metric.

<p align="center">
  <img src="figures/fig12_uav_paths.png" alt="Representative UAV paths across the four scenarios" width="100%">
</p>

<p align="center">
  <em><b>Figure 11.</b> Representative feasible paths across the four scenarios. These are solutions from selected runs, intended to illustrate typical path geometry rather than the run-to-run distribution.</em>
</p>

<p align="center">
  <img src="figures/fig13_uav_convergence.png" alt="UAV convergence behaviour" width="86%">
</p>

<p align="center">
  <em><b>Figure 12.</b> Convergence behaviour under the shared decoding chain. The curves provide qualitative evidence of search behaviour rather than statistical evidence of convergence superiority.</em>
</p>


## 7. Reference implementation

The reference implementation is a single self-contained MATLAB function with no external dependencies beyond the caller-supplied objective. It accepts two argument layouts, detected automatically: an 11-argument benchmark interface and an 8-argument segmentation interface.

```matlab
% --- Benchmark interface (CEC / PlatECO) -------------------------------
% AUGO(mainHandle, popsize, dimension, xmax, xmin, vmax, vmin, ...
%      maxiter, Func, FuncId, VisualSwitch)
%
% MaxFEs is set inside the file to popsize * maxiter, so N = 40 with
% maxiter = 7500 reproduces the 10000*D evaluation budget at D = 30.
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    [], 40, 30, 100, -100, [], [], 7500, @myObjective, 1, false);

% --- Segmentation interface -------------------------------------------
% AUGO(popsize, dimension, maxiter, xmax, xmin, probR, Func, Class)
%
% The objective is maximized internally, so Func returns the Kapur
% entropy. popsize = 40 with maxiter = 150 gives 6000 evaluations.
[gbestX, gbestfitness, gbesthistory] = AUGO( ...
    40, D, 150, 255, 0, probR, @kapurObjective, imageClass);
```

<details>
<summary><b>Click to expand the full <code>AUGO.m</code> source (with inline documentation)</b></summary>


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
% =========================================================================
% AUGO: Asymmetric Undulatory Growth Optimizer.
% Supports both interfaces:
%   PlatECO/CEC: AUGO(mainHandle,popsize,dimension,xmax,xmin,vmax,vmin,maxiter,Func,FuncId,VisualSwitch)
%   Segmentation: AUGO(popsize,dimension,maxiter,xmax,xmin,probR,Func,Class)
%
% The search core keeps the original AUGO stages. The only added mechanism
% is a small generic best-neighborhood refinement, which is not
% threshold-specific and can also work for CEC functions.

[popsize, dimension, maxiter, xmax, xmin, Fitness, isMinimize, outputBest] = parseInputs(varargin{:});

FEs = 0;
MaxFEs = popsize * maxiter;
printStep = max(1, floor(MaxFEs / 10));

x = xmin + (xmax - xmin) .* rand(popsize, dimension);
fitness = zeros(popsize, 1);
gbesthistory = nan(1, MaxFEs);
```

</details>

The complete source is `AUGO.m` at the repository root. Default parameters are `ρ_p = 0.5`, `p_q^max = 0.10`, `η_B = 0.20`, and `K = 5`; the benchmark protocol uses an initial population size of `N = 40`.


## 8. Acknowledgments

The author thanks the editor and the anonymous reviewers for their time and their detailed comments, which have improved the manuscript. Funding information will be recorded here in accordance with the manuscript once the review process concludes.


## Copyright

Copyright (c) 2026 Qingke Zhang. All rights reserved.

The source code `AUGO.m` is released under the [MIT License](LICENSE). The manuscript, figures, and documentation in this repository remain the property of the author and may not be redistributed without permission. The companion manuscript is currently under review; until the citation record is updated, please cite this work as a manuscript under review. See [NOTICE.md](NOTICE.md) for details.


<div align="center">
<sub>School of Computer Science and Artificial Intelligence, Shandong Normal University</sub>
</div>
