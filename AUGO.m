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

if isMinimize
    gbestfitness = inf;
else
    gbestfitness = -inf;
end
gbestPosition = zeros(1, dimension);
gbestX = outputBest(gbestPosition);

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

while FEs < MaxFEs
    progress = FEs / MaxFEs;
    alpha = (cos(pi * progress) + 1) / 2;

    ind = sortedIndex(fitness, isMinimize);
    Best_X = x(ind(1), :);

    max_better = max(5, round(0.5 * popsize));
    ub_better = round(5 + (max_better - 5) * alpha);
    ub_better = min(popsize, max(2, ub_better));

    min_worst = min(popsize - 4, round(0.5 * popsize));
    lb_worst = round((popsize - 4) - ((popsize - 4) - min_worst) * alpha);
    lb_worst = min(popsize, max(1, lb_worst));

    if isMinimize
        max_fit = max(fitness);
        if abs(max_fit) < eps
            max_fit = sign(max_fit + eps) * eps;
        end
    else
        min_fit = min(fitness);
    end

    % Stage 1: original dynamic-pool vector growth.
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

    ind = sortedIndex(fitness, isMinimize);
    Best_X = x(ind(1), :);

    % Stage 2: original asymmetric reflection and Cauchy quantum escape.
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

    % Stage 3: original UDGF elite differential-Gaussian refinement.
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

    % Conservative generic add-on: a tiny best-neighborhood refinement.
    % It is continuous, late-stage, and budget-limited, so it is not tied
    % to threshold segmentation and has low impact on the original dynamics.
    if FEs < MaxFEs && progress > 0.2
        refineBudget = min(max(8, ceil(0.20 * popsize)), MaxFEs - FEs);
        [gbestPosition, gbestfitness, FEs, gbesthistory] = refineBest(gbestPosition, gbestfitness, FEs, gbesthistory, refineBudget, progress);
        gbestX = outputBest(gbestPosition);
    end
end

if FEs < MaxFEs
    gbesthistory(FEs+1:MaxFEs) = gbestfitness;
elseif FEs > MaxFEs
    gbesthistory(MaxFEs+1:end) = [];
end

    function printProgress()
        if mod(FEs, printStep) == 0 && FEs <= MaxFEs
            fprintf("AUGO %d FEs, best fitness = %e\n", FEs, gbestfitness);
        end
    end

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

function ind = sortedIndex(fitness, isMinimize)
if isMinimize
    [~, ind] = sort(fitness);
else
    [~, ind] = sort(fitness, 'descend');
end
end

function ok = isBetter(candidateFitness, referenceFitness, isMinimize)
if isMinimize
    ok = candidateFitness < referenceFitness;
else
    ok = candidateFitness > referenceFitness;
end
end

function y = clampBounds(y, xmin, xmax)
y = max(y, xmin);
y = min(y, xmax);
end

function r = selectID(popsize, i, count)
lists = randperm(popsize);
r = lists(1:count+1);
r(r == i) = [];
r = r(1:count);
end
