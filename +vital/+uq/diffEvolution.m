function [xBest, fBest, info] = diffEvolution(fcn, lo, hi, opts)
%DIFFEVOLUTION  Seeded differential evolution, DE/rand/1/bin, inside a box (M8
%   amendment R4-4: the global stage of the hybrid search; VITAL's own
%   implementation because the Global Optimization Toolbox is not installed).
%   [x, f, info] = vital.uq.diffEvolution(fcn, lo, hi)
%   [x, f, info] = vital.uq.diffEvolution(fcn, lo, hi, 'Population', 20,
%        'Generations', 20, 'F', 0.7, 'CR', 0.9, 'Seed', 2027, 'Init', X0,
%        'InitF', F0, 'TolFun', 1e-6, 'TolX', 1e-6)
%
%   fcn       f = fcn(x), x 1 x d inside [lo, hi]; f is MINIMIZED. NaN (a point
%             that cannot be evaluated) ranks below every number in the
%             selection (treated as +Inf) but is kept in the history.
%   lo, hi    1 x d bounds (lo <= hi; lo = hi fixes a dimension)
%   Algorithm (Storn and Price 1997, "Differential Evolution - A Simple and
%   Efficient Heuristic for Global Optimization over Continuous Spaces"):
%     initial population of Population members: the rows of Init (with their
%     values InitF, NOT re-evaluated; evaluated here if InitF is empty; the
%     first Population rows if there are more) filled up with seeded uniform
%     points in the box; then Generations
%     generations, each with one trial per member:
%       mutation  v = x_r1 + F (x_r2 - x_r3), r1, r2, r3 distinct and ~= i
%       crossover u_j = v_j with probability CR (and always for one random j),
%                 else x_i,j
%       bounds    a component outside [lo, hi] is reflected at the bound it
%                 crossed; if it is still outside it is drawn uniformly in
%                 [lo, hi]: every evaluated point lies in the box
%       selection u replaces x_i if f(u) <= f(x_i)
%   The budget is fixed: Population x Generations trial evaluations (plus the
%   members of the initial population that were not given). There is no early
%   stop; convergence is REPORTED: info.converged is true when, after the last
%   generation, the population's values spread by at most TolFun (1 +
%   |best|) and its points by at most TolX (hi - lo) in every dimension.
%   Random numbers: RandStream('mt19937ar', 'Seed', Seed) only (the global
%   random state is not used).
%   info fields: X (every evaluated point, nEval x d, in evaluation order),
%     F (their values), nEval (evaluations made here), generations, converged,
%     spreadF, spreadX (1 x d), history (best value after each generation),
%     population, populationF, seed, weightF (the option F), CR.
%   Errors: vital:badInput (bounds, Population < 4 or not an integer,
%   Generations < 0, F outside (0, 2], CR outside [0, 1], Init / InitF sizes).
arguments
    fcn function_handle
    lo (1,:) double
    hi (1,:) double
    opts.Population (1,1) double = 20
    opts.Generations (1,1) double = 20
    opts.F (1,1) double = 0.7
    opts.CR (1,1) double = 0.9
    opts.Seed (1,1) double = 2027
    opts.Init (:,:) double = zeros(0, 0)
    opts.InitF (:,1) double = zeros(0, 1)
    opts.TolFun (1,1) double = 1e-6
    opts.TolX (1,1) double = 1e-6
end
d = numel(lo);
if d == 0 || numel(hi) ~= d || ~all(isfinite([lo hi])) || any(lo > hi)
    error('vital:badInput', 'lo and hi must be finite 1 x d vectors with lo <= hi.');
end
NP = opts.Population; G = opts.Generations;
if ~(isfinite(NP) && NP >= 4 && NP == round(NP))
    error('vital:badInput', 'Population must be an integer >= 4 (DE/rand/1 needs three other members).');
end
if ~(isfinite(G) && G >= 0 && G == round(G))
    error('vital:badInput', 'Generations must be a non-negative integer.');
end
if ~(opts.F > 0 && opts.F <= 2)
    error('vital:badInput', 'F must lie in (0, 2].');
end
if ~(opts.CR >= 0 && opts.CR <= 1)
    error('vital:badInput', 'CR must lie in [0, 1].');
end
X0 = opts.Init; F0 = opts.InitF;
if isempty(X0), X0 = zeros(0, d); end
if size(X0, 2) ~= d || (~isempty(F0) && numel(F0) ~= size(X0, 1))
    error('vital:badInput', 'Init must be n x d and InitF n x 1.');
end
rs = RandStream('mt19937ar', 'Seed', opts.Seed);
w = hi - lo;
Xall = zeros(0, d); Fall = zeros(0, 1);
X = zeros(NP, d); Fv = NaN(NP, 1);
nI = min(size(X0, 1), NP);
for i = 1:nI
    X(i, :) = min(max(X0(i, :), lo), hi);
    if isempty(F0)
        Fv(i) = evaluate(X(i, :));
    else
        Fv(i) = F0(i);
    end
end
for i = nI + 1:NP
    X(i, :) = min(max(lo + w .* rand(rs, 1, d), lo), hi);
    Fv(i) = evaluate(X(i, :));
end
hist = zeros(G, 1);
for g = 1:G
    for i = 1:NP
        others = [1:i - 1, i + 1:NP];
        r = others(randperm(rs, NP - 1, 3));
        v = X(r(1), :) + opts.F * (X(r(2), :) - X(r(3), :));
        mask = rand(rs, 1, d) <= opts.CR;
        mask(randi(rs, d)) = true;
        u = X(i, :);
        u(mask) = v(mask);
        u = reflectInto(u, lo, hi, w, rs);
        fu = evaluate(u);
        if key(fu) <= key(Fv(i))
            X(i, :) = u; Fv(i) = fu;
        end
    end
    hist(g) = min(arrayfun(@key, Fv));
end
[~, k] = min(arrayfun(@key, Fv));
xBest = X(k, :); fBest = Fv(k);
fin = Fv(isfinite(Fv));
info.X = Xall;
info.F = Fall;
info.nEval = size(Xall, 1);
info.generations = G;
if isempty(fin) || numel(fin) < NP
    info.spreadF = Inf;
else
    info.spreadF = max(fin) - min(fin);
end
info.spreadX = max(X, [], 1) - min(X, [], 1);
info.converged = isfinite(info.spreadF) && info.spreadF <= opts.TolFun * (1 + abs(fBest)) && ...
    all(info.spreadX <= opts.TolX * max(w, eps));
info.history = hist;
info.population = X;
info.populationF = Fv;
info.seed = opts.Seed;
info.weightF = opts.F;
info.CR = opts.CR;

    function f = evaluate(x)
        f = fcn(x);
        Xall(end+1, :) = x;
        Fall(end+1, 1) = f;
    end
end

function r = key(f)
% NaN ranks below every number (selection only)
if isnan(f), r = Inf; else, r = f; end
end

function u = reflectInto(u, lo, hi, w, rs)
% bound handling of a trial vector: reflect a component at the bound it
% crossed; if it is still outside, draw it uniformly in [lo, hi]
b = u < lo; u(b) = lo(b) + (lo(b) - u(b));
a = u > hi; u(a) = hi(a) - (u(a) - hi(a));
out = u < lo | u > hi;
if any(out)
    u(out) = lo(out) + w(out) .* rand(rs, 1, sum(out));
end
u = min(max(u, lo), hi);
end
