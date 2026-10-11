function bw = surrogateWorst(problem, marginFcn, opts)
%SURROGATEWORST  Bound-worst search of a group whose margin is +Inf at the nominal
%   point, on a smooth surrogate (M8 amendment after review R3, R3-M3(b)).
%   bw = vital.uq.surrogateWorst(problem, marginFcn)
%   bw = vital.uq.surrogateWorst(problem, marginFcn, 'Reserve', 0, 'NumLHS', 32,
%        'Seed', 2026, 'NumStarts', 2, 'MaxEvals', 60, 'FDStep', 1e-3,
%        'MaxRounds', 3, 'Quantity', 'spiral root real part (1/s)')
%
%   Why: the 3.3.1.3 spiral margin (time to double, T2 >= 12 s) is +Inf
%   wherever the spiral is stable, so an optimizer started from +Inf cannot
%   move (FC-901). Its surrogate s, the real part of the spiral root (1/s), is
%   smooth, and T2 = ln2/s is decreasing in s for s > 0, so the worst T2 margin
%   over the box is where s is largest.
%   problem  as vital.uq.boundWorst, except
%     pointFcn    q = f(theta, cond): q.status ('OK' or not), q.value (the
%                 surrogate s: LARGER is worse), q.record, q.reason
%     confirmFcn  (optional) c = f(theta): a fresh assessment over all
%                 conditions: c.status, c.value (the largest s over them),
%                 c.condLabel, c.cond, c.record, c.reason
%   marginFcn  q = f(theta, cond): the TRUE margin at a point (q.status,
%              q.margin, q.record, q.reason), called at the arg-max only
%   Method: vital.uq.boundWorst on -s (so its minimum is the largest s), with
%   Reserve -Inf (the surrogate itself never "violates"; a moving limit of the
%   surrogate is re-searched as in boundWorst, at most MaxRounds rounds).
%   Result (in the TRUE margin's terms; bw has boundWorst's fields, plus
%   bw.surrogate: quantity, value (the largest s found; the search value is
%   -bw.surrogate.value in boundWorst's terms), searchValue, status, reason):
%     s_max <= 0  the spiral is stable at every evaluated point: bw.value =
%                 +Inf; status 'OK' when the surrogate search is OK (reason
%                 'stable over the box (surrogate search): ...'), else the
%                 surrogate search's status and reason (e.g. FC-901,
%                 MOVING_LIMIT, a point without a surrogate)
%     s_max > 0   bw.value = marginFcn at the arg-max (theta, condition):
%                 'VIOLATED' if below Reserve (a definitive counterexample),
%                 else the surrogate search's status
%     no finite s anywhere: 'NOT_ASSESSABLE', value NaN
%   Like every bound-worst, the result is a search estimate (an upper bound
%   on the true minimum), not a proof.
%   Errors: as vital.uq.boundWorst.
arguments
    problem (1,1) struct
    marginFcn function_handle
    opts.NumLHS (1,1) double = 32
    opts.Seed (1,1) double = 2026
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 60
    opts.FDStep (1,1) double = 1e-3
    opts.MaxRounds (1,1) double = 3
    opts.Reserve (1,1) double = 0
    opts.Quantity (1,:) char = 'spiral root real part (1/s)'
end
P = problem;
if ~isfield(P, 'pointFcn') || ~isa(P.pointFcn, 'function_handle')
    error('vital:badInput', 'pointFcn must be a function handle q = f(theta, cond).');
end
sf = P.pointFcn;
P.pointFcn = @(th, c) toMargin(sf(th, c));
if isfield(P, 'confirmFcn') && ~isempty(P.confirmFcn)
    cf = P.confirmFcn;
    P.confirmFcn = @(th) toConfirm(cf(th));
end
bs = vital.uq.boundWorst(P, 'NumLHS', opts.NumLHS, 'Seed', opts.Seed, 'NumStarts', opts.NumStarts, ...
    'MaxEvals', opts.MaxEvals, 'FDStep', opts.FDStep, 'MaxRounds', opts.MaxRounds, 'Reserve', -Inf);
bw = bs;
sMax = -bs.value;
bw.surrogate = struct('quantity', opts.Quantity, 'value', sMax, 'searchValue', -bs.searchValue, ...
    'status', bs.status, 'reason', bs.reason);
bw.reserve = opts.Reserve;
bw.options.Reserve = opts.Reserve;
where = sprintf('%s, theta %s', bs.cond, mat2str(bs.theta, 6));
sr = sprintf('surrogate search on -%s (its margins and reserve are in those terms): %s', opts.Quantity, bs.reason);
if isnan(sMax)
    bw.status = 'NOT_ASSESSABLE';
    bw.value = NaN;
    bw.reason = sprintf('no point of the box has a %s: %s', opts.Quantity, sr);
elseif sMax <= 0
    bw.value = Inf;
    bw.record = '';
    if strcmp(bs.status, 'OK')
        bw.status = 'OK';
        bw.reason = sprintf(['stable over the box (surrogate search): the largest %s found is %.6g <= 0 at %s; ' ...
            'bound-worst +Inf (%s)'], opts.Quantity, sMax, where, sr);
    else
        bw.status = bs.status;
        bw.reason = sprintf('%s; the largest %s found is %.6g <= 0 at %s', sr, opts.Quantity, sMax, where);
    end
else
    try
        q = marginFcn(bs.theta, bs.condition);
    catch err
        q = struct('status', 'ERROR', 'margin', NaN, 'record', '', 'reason', sprintf('%s: %s', err.identifier, err.message));
    end
    if ~strcmp(q.status, 'OK') || isnan(q.margin)
        bw.status = 'NOT_ASSESSABLE';
        bw.value = NaN;
        bw.reason = sprintf('the margin at the surrogate arg-max (%s %.6g at %s) is not available: %s (%s); %s', ...
            opts.Quantity, sMax, where, q.status, q.reason, sr);
    else
        bw.value = q.margin;
        bw.record = q.record;
        if q.margin < opts.Reserve
            bw.status = 'VIOLATED';
            bw.reason = sprintf(['counterexample: at the surrogate arg-max (%s %.6g > 0 at %s) the margin is %.6g < ' ...
                'reserve %g (%s)'], opts.Quantity, sMax, where, q.margin, opts.Reserve, q.record);
        else
            bw.status = bs.status;
            bw.reason = sprintf(['the largest %s found is %.6g > 0 at %s: margin there %.6g (%s), the bound-worst ' ...
                '(the margin decreases as the surrogate grows); %s'], opts.Quantity, sMax, where, q.margin, q.record, sr);
        end
    end
end
bw = orderfields(bw);
end

function q = toMargin(q)
% the surrogate as a boundWorst margin: larger s is worse, so margin = -s
if strcmp(q.status, 'OK')
    q.margin = -q.value;
else
    q.margin = NaN;
end
end

function c = toConfirm(c)
if strcmp(c.status, 'OK')
    c.margin = -c.value;
else
    c.margin = NaN;
end
end
