function mc = monteCarlo(problem, opts)
%MONTECARLO  Seeded Monte Carlo of the Level at one condition (M8; generic).
%   mc = vital.uq.monteCarlo(problem)
%   mc = vital.uq.monteCarlo(problem, 'N', 200, 'Seed', 2026, 'Conf', 0.95)
%
%   problem fields
%     names, nominal (1 x d), sigma (1 x d, the 1-sigma widths actually used),
%     lo, hi (the box, only to flag samples inside it), cond, condLabel,
%     level0 (the nominal headline Level), pointFcn: q = f(theta, cond) with
%     q.status, q.level (the group's Level at the point), q.margin, q.record,
%     q.reason
%   Samples theta_k = nominal + sigma .* z_k, z_k ~ N(0, I) from
%   RandStream('mt19937ar', 'Seed', Seed) (the stream of rng(Seed, 'twister')),
%   drawn as randn(stream, N, d), serial; the global random state is not used.
%   SUCCESS: q.status 'OK' and q.level <= level0 (at least as good as the
%   nominal headline Level). A sample that is not OK (or throws) is a FAILURE
%   and is listed in mc.failures with its reason.
%   mc fields: N, x (successes), success (N x 1 logical), theta (N x d), level,
%     margin, status, record, inBox (N x 1 logical), failures (index, theta,
%     status, level, margin, reason), cpLower (one-sided Clopper-Pearson lower
%     bound at Conf), conf, seed, cond, condLabel, level0, names, sigma.
%   Errors: vital:badInput (N not a positive integer, sizes, sigma < 0).
arguments
    problem (1,1) struct
    opts.N (1,1) double = 200
    opts.Seed (1,1) double = 2026
    opts.Conf (1,1) double = 0.95
end
P = problem;
need = {'nominal', 'sigma', 'lo', 'hi', 'cond', 'level0', 'pointFcn'};
for k = 1:numel(need)
    if ~isfield(P, need{k}), error('vital:badInput', 'monteCarlo problem lacks field "%s".', need{k}); end
end
N = opts.N;
if ~(isfinite(N) && N >= 1 && N == round(N))
    error('vital:badInput', 'N must be a positive integer.');
end
d = numel(P.nominal);
if numel(P.sigma) ~= d || numel(P.lo) ~= d || numel(P.hi) ~= d
    error('vital:badInput', 'nominal, sigma, lo and hi must have the same length.');
end
if any(~isfinite(P.sigma)) || any(P.sigma < 0)
    error('vital:badInput', 'sigma must be finite and >= 0.');
end
if ~isa(P.pointFcn, 'function_handle')
    error('vital:badInput', 'pointFcn must be a function handle.');
end
if ~isfield(P, 'condLabel'), P.condLabel = ''; end
if ~isfield(P, 'names'), P.names = {}; end
nominal = P.nominal(:).'; sigma = P.sigma(:).';
rs = RandStream('mt19937ar', 'Seed', opts.Seed);
Z = randn(rs, N, d);
TH = nominal + sigma .* Z;

mc.N = N;
mc.seed = opts.Seed;
mc.conf = opts.Conf;
mc.cond = P.cond;
mc.condLabel = P.condLabel;
mc.level0 = P.level0;
mc.names = P.names;
mc.sigma = sigma;
mc.theta = TH;
mc.level = NaN(N, 1);
mc.margin = NaN(N, 1);
mc.status = repmat({''}, N, 1);
mc.record = repmat({''}, N, 1);
mc.success = false(N, 1);
mc.inBox = all(TH >= P.lo(:).' & TH <= P.hi(:).', 2);
mc.failures = struct('index', {}, 'theta', {}, 'status', {}, 'level', {}, 'margin', {}, 'reason', {});
for k = 1:N
    try
        q = P.pointFcn(TH(k, :), P.cond);
    catch err
        q = struct('status', 'ERROR', 'level', NaN, 'margin', NaN, 'record', '', ...
            'reason', sprintf('%s: %s', err.identifier, err.message));
    end
    mc.status{k} = q.status;
    mc.level(k) = q.level;
    mc.margin(k) = q.margin;
    if isfield(q, 'record'), mc.record{k} = q.record; end
    ok = strcmp(q.status, 'OK');
    mc.success(k) = ok && q.level <= P.level0;
    if ~ok
        mc.failures(end+1) = struct('index', k, 'theta', TH(k, :), 'status', q.status, 'level', q.level, ...
            'margin', q.margin, 'reason', q.reason);
    end
end
mc.x = sum(mc.success);
mc.cpLower = vital.uq.clopperPearson(mc.x, N, opts.Conf, 'Sided', 'lower');
mc.nNotOK = numel(mc.failures);
mc.nWorseLevel = sum(strcmp(mc.status, 'OK') & ~mc.success);
end
