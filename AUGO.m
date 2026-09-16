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
