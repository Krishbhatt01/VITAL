function s = suggestGains(opts)
%SUGGESTGAINS  Design feedback: propose static SAS / yaw-damper gains that move the
%   failing in-envelope MIL-F-8785C groups to a target Level, and CONFIRM the
%   proposal by re-running vital.fq.assess on the augmented aircraft (M7).
%   s = vital.ctrl.suggestGains()                         registered defaults
%   s = vital.ctrl.suggestGains('Targets', T, 'Gains', G, 'Builder', b, ...
%         'Conditions', C, 'Rules', R, 'Goal', 0.05, 'MaxIter', 4, ...
%         'FDStep', 0.02, 'Resolution', 0.01, 'Bare', resBare)
%
%   Targets   struct array (group, level): the groups to bring to a Level in the
%             validity envelope. Default: 3.2.2.1.1-CatA, 3.3.1.1-CatA-other and
%             3.3.1.1-CatA-COGA, Level 1 each.
%   Gains     struct array (name, lo, hi, start, unit): the search box. Default
%             Kq [0, 0.4] s, Ka [0, 1.0] rad/rad, Kr [0, 1.5] s, start 0.
%   Builder   ctrl = b(AC, env, tr, k), k the gain vector in the order of Gains.
%             Default: vital.ctrl.combine(vital.ctrl.pitchSas(..., 'Kq', k(1),
%             'Ka', k(2)), vital.ctrl.yawDamper(..., 'Kr', k(3))).
%   Conditions  default vital.ctrl.inEnvelopeConditions(); only the in-envelope
%             (headline) results are used.
%   Rules     default vital.fq.loadRules().
%   Goal      design margin m* (normalized, the vital.fq.assess margin) asked of
%             every target at its target Level (default 0.05).
%   MaxIter   search iterations (default 4); FDStep forward-difference step as a
%             fraction of each gain range (default 0.02; backward at the upper
%             bound); Resolution rounding of the proposed gains (default 0.01 in
%             each gain's unit); Bare a precomputed bare-airframe vital.fq.assess
%             result over the same Conditions and Rules (optional; computed if
%             absent).
%
%   METHOD (every margin comes from the whole chain: factory -> trim ->
%   closed-loop linearize -> modes -> metrics -> vital.fq.assess):
%   1. Bare airframe: vital.fq.assess (no controller). A target's margin
%      m_g = min over the records of group g at the target Level of their
%      in-envelope minimum margin; its critical record and condition are the
%      arg-min (the active set). Protected groups: every other group with a
%      finite in-envelope headline Level; each must keep its bare Level
%      (constraint: margin to the bare Level >= min(Goal, m_bare)/2).
%   2. Iterate from k = start: assess the augmented aircraft; forward finite
%      differences of every constraint margin with respect to every gain (one
%      assess per gain), recording the critical record and condition at k and at
%      k + h e_j and whether it SWITCHES; a minimum-norm step in normalized gains
%      (lsqlin) with the linearized constraints m_i + S_i dk >= req_i (req = Goal
%      for targets), the box, and a trust region of half the range; when the
%      linearized problem is infeasible, the least-squares step on the violated
%      constraints. A step is accepted if the merit sum(max(0, req - m)) falls,
%      else halved (twice at most). Stops when every constraint holds or after
%      MaxIter.
%   3. The proposal is the best iterate rounded to Resolution (inside the box).
%   4. CONFIRMATION: a fresh vital.fq.assess of the augmented aircraft with the
%      proposed (rounded) gains. Only this run decides the status.
%
%   s fields
%     status    'TARGET_REACHED'  in the confirmation every target group's
%                                 in-envelope headline Level <= its target and
%                                 no protected group is worse than bare
%               'TARGET_NOT_REACHED'  otherwise (reason names the target that
%                                 missed and its best margin, or the regression)
%               'NOT_ASSESSABLE'  a target group has no in-envelope headline
%                                 Level on the bare airframe (unrated points)
%     reason, targets (group, level, bareLevel, bareMargin, bareCritical,
%     achievedLevel, achievedMargin, critical, reached), gains (name, unit, lo,
%     hi, value = the proposal, unrounded), sensitivity (per iteration: k, h,
%     S, constraint names, margins, critical at k and at each FD point,
%     switched), history, protected (group, bareLevel, achievedLevel,
%     regressed), confirmation (evaluated, gains, groups, res), bare (groups,
%     res), equivalentSystemFlags (in-envelope points whose closed-loop modes
%     are not the classical set; MIL-F-8785C 3.1.12), nAssess, runtime_s.
%   Errors: vital:badInput (unknown target group, bad gain box, start outside
%   the box, Builder not a function handle).
arguments
    opts.Targets struct = struct([])
    opts.Gains struct = struct([])
    opts.Builder = []
    opts.Conditions struct = struct([])
    opts.Rules struct = struct([])
    opts.Goal (1,1) double = 0.05
    opts.MaxIter (1,1) double = 4
    opts.FDStep (1,1) double = 0.02
    opts.Resolution (1,1) double = 0.01
    opts.Bare struct = struct([])
end
t0 = tic;
R = opts.Rules; if isempty(R), R = vital.fq.loadRules(); end
C = opts.Conditions; if isempty(C), C = vital.ctrl.inEnvelopeConditions(); end
T = opts.Targets;
if isempty(T)
    T = struct('group', {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other', '3.3.1.1-CatA-COGA'}, 'level', {1, 1, 1});
end
Gs = opts.Gains;
if isempty(Gs)
    Gs = struct('name', {'Kq', 'Ka', 'Kr'}, 'lo', {0, 0, 0}, 'hi', {0.4, 1.0, 1.5}, 'start', {0, 0, 0}, ...
        'unit', {'s', 'rad/rad', 's'});
end
[T, Gs, B] = validate(T, Gs, opts, R);
nG = numel(Gs);
lo = [Gs.lo]; hi = [Gs.hi]; width = hi - lo; free = width > 0;
gainNames = {Gs.name};
nAssess = 0;

s = struct('status', '', 'reason', '', 'targets', struct([]), 'gains', struct(), 'sensitivity', struct([]), ...
    'history', struct([]), 'protected', struct([]), 'confirmation', struct('evaluated', false), 'bare', struct(), ...
    'equivalentSystemFlags', struct([]), 'search', struct(), 'goal', opts.Goal, 'conditions', struct('id', C.id, 'grid', C.grid, ...
    'axes', C.axes), 'nAssess', 0, 'runtime_s', 0, 'notes', {{}});
s.gains = struct('name', {gainNames}, 'unit', {{Gs.unit}}, 'lo', lo, 'hi', hi, 'start', [Gs.start], ...
    'value', NaN(1, nG), 'unrounded', NaN(1, nG), 'resolution', opts.Resolution);

% ---- 1. bare airframe ------------------------------------------------------------------
bare = opts.Bare;
if isempty(bare)
    bare = vital.fq.assess(R, vital.fq.f16Factory(), C);
    nAssess = nAssess + 1;
end
s.bare = struct('groups', groupTable(bare), 'res', bare);
[cons, s.targets] = buildConstraints(T, bare, R, opts.Goal);
bad = find(isnan([s.targets.bareLevel]));
if ~isempty(bad)
    s.status = 'NOT_ASSESSABLE';
    s.reason = sprintf(['no in-envelope headline Level on the bare airframe for %s (no in-envelope point, or ' ...
        'unrated points): nothing to improve can be established'], strjoin({s.targets(bad).group}, ', '));
    s.nAssess = nAssess; s.runtime_s = toc(t0);
    return
end
s.protected = struct('group', {cons(strcmp({cons.kind}, 'protect')).group}, ...
    'bareLevel', {cons(strcmp({cons.kind}, 'protect')).level}, 'achievedLevel', NaN, 'regressed', false);
req = [cons.req].';
names = arrayfun(@(c) [c.kind ':' c.group], cons, 'UniformOutput', false);

% ---- 2. search ---------------------------------------------------------------------------
evalAt = @(k) assessAt(R, C, B, k, cons);
k = [Gs.start];
[m, crit, resK] = evalAt(k); nAssess = nAssess + 1;
s.history = struct('k', k, 'margins', m, 'merit', merit(m, req), 'accepted', true, 'note', 'start');
sens = struct([]);
stopNote = sprintf('MaxIter = %d reached', opts.MaxIter);
for it = 1:opts.MaxIter
    if all(m >= req)
        stopNote = sprintf('every constraint holds after %d iterations', it - 1);
        break
    end
    % forward finite differences through the whole chain (backward at the upper bound)
    S = zeros(numel(cons), nG); sw = false(numel(cons), nG); h = zeros(1, nG);
    critFD = cell(1, nG);
    for j = find(free)
        h(j) = opts.FDStep * width(j);
        if k(j) + h(j) > hi(j), h(j) = -h(j); end
        kj = k; kj(j) = k(j) + h(j);
        [mj, cj] = evalAt(kj); nAssess = nAssess + 1;
        d = (mj - m) / h(j);
        d(~isfinite(d)) = NaN;
        S(:, j) = d;
        sw(:, j) = ~arrayfun(@(a, b) sameCritical(a, b), crit, cj);
        critFD{j} = cj;
    end
    e = struct('iteration', it, 'k', k, 'h', h, 'gainNames', {gainNames}, ...
        'constraintNames', {names}, 'margins', m, 'req', req, 'S', S, 'critical', {crit}, ...
        'criticalFD', {critFD}, 'switched', sw);
    if isempty(sens), sens = e; else, sens(end+1) = e; end %#ok<AGROW>
    % minimum-norm step in normalized gains, linearized constraints, box, trust region
    x = (k - lo) ./ max(width, realmin);
    Sn = S .* width;
    use = all(isfinite(Sn(:, free)), 2) & isfinite(m);
    lb = max(-x, -0.5).'; ub = min(1 - x, 0.5).';
    lb(~free) = 0; ub(~free) = 0;
    dx = stepFor(Sn, m, req, use, lb, ub);
    accepted = false;
    for a = [1 0.5 0.25]
        kt = min(hi, max(lo, k + a * dx.' .* width));
        [mt, ct, rt] = evalAt(kt); nAssess = nAssess + 1;
        ok = merit(mt, req) < merit(m, req) - 1e-12;
        s.history(end+1) = struct('k', kt, 'margins', mt, 'merit', merit(mt, req), 'accepted', ok, ...
            'note', sprintf('iteration %d, step fraction %g', it, a));
        if ok
            k = kt; m = mt; crit = ct; resK = rt; accepted = true;
            break
        end
    end
    if ~accepted
        stopNote = sprintf('iteration %d: no step (full, half or quarter) reduced the constraint violation', it);
        break
    end
end
if all(m >= req) && ~contains(stopNote, 'every'), stopNote = 'every constraint holds'; end
s.sensitivity = sens;
s.notes{end+1} = ['search: ' stopNote];

% ---- 3. proposal (rounded) --------------------------------------------------------------
kp = round(k / opts.Resolution) * opts.Resolution;
kp = min(hi, max(lo, kp));
s.gains.unrounded = k;
s.gains.value = kp;

% ---- 4. CONFIRMATION: a fresh assessment with the proposed gains -------------------------
% (never the search's last assessment resK: that was made with the unrounded gains)
fac = vital.fq.f16Factory('Controller', @(AC, env, tr) B(AC, env, tr, kp));
resC = vital.fq.assess(R, fac, C);
s.search = struct('lastGains', k, 'lastGroups', groupTable(resK));
nAssess = nAssess + 1;
s.confirmation = struct('evaluated', true, 'gains', kp, 'groups', groupTable(resC), 'res', resC);
missed = {};
for i = 1:numel(s.targets)
    g = resC.groups(strcmp({resC.groups.group}, s.targets(i).group));
    [mm, cc] = levelMargin(resC, s.targets(i).group, s.targets(i).level);
    s.targets(i).achievedLevel = g.inEnvelope.levelHeadline;
    s.targets(i).achievedMargin = mm;
    s.targets(i).critical = cc;
    s.targets(i).reached = ~isnan(g.inEnvelope.levelHeadline) && g.inEnvelope.levelHeadline <= s.targets(i).level;
    if ~s.targets(i).reached
        missed{end+1} = sprintf('%s: Level %s (target %d), margin to the Level %d boundary %.4g at %s (%s)', ...
            s.targets(i).group, num2str(g.inEnvelope.levelHeadline), s.targets(i).level, s.targets(i).level, mm, ...
            condText(cc.cond), cc.record); %#ok<AGROW>
    end
end
regressed = {};
for i = 1:numel(s.protected)
    g = resC.groups(strcmp({resC.groups.group}, s.protected(i).group));
    s.protected(i).achievedLevel = g.inEnvelope.levelHeadline;
    s.protected(i).regressed = isnan(g.inEnvelope.levelHeadline) || g.inEnvelope.levelHeadline > s.protected(i).bareLevel;
    if s.protected(i).regressed
        regressed{end+1} = sprintf('%s: Level %s, bare Level %d', s.protected(i).group, ...
            num2str(g.inEnvelope.levelHeadline), s.protected(i).bareLevel); %#ok<AGROW>
    end
end
P = resC.points;
fl = struct('cond', {}, 'envelope', {}, 'notes', {});
for i = 1:numel(P)
    if isfield(P(i).info, 'equivalentSystem') && strcmp(P(i).info.equivalentSystem, 'FLAGGED')
        fl(end+1) = struct('cond', P(i).cond, 'envelope', P(i).envelope, 'notes', {P(i).info.notes}); %#ok<AGROW>
    end
end
s.equivalentSystemFlags = fl;
if isempty(missed) && isempty(regressed)
    s.status = 'TARGET_REACHED';
    s.reason = sprintf('confirmed by re-assessment with %s', gainText(gainNames, kp));
else
    s.status = 'TARGET_NOT_REACHED';
    parts = {};
    if ~isempty(missed), parts{end+1} = ['target not reached: ' strjoin(missed, '; ')]; end
    if ~isempty(regressed), parts{end+1} = ['worse than bare: ' strjoin(regressed, '; ')]; end
    s.reason = sprintf('%s (gains %s; %s)', strjoin(parts, ' | '), gainText(gainNames, kp), stopNote);
end
s.nAssess = nAssess;
s.runtime_s = toc(t0);
end

% =========================================================================================
function [T, Gs, B] = validate(T, Gs, opts, R)
groups = unique({R.group});
if ~all(isfield(T, {'group', 'level'}))
    error('vital:badInput', 'Targets must be a struct array with fields group and level.');
end
for i = 1:numel(T)
    if ~any(strcmp(T(i).group, groups))
        error('vital:badInput', 'target group "%s" is not a rule group.', T(i).group);
    end
    L = T(i).level;
    lv = [R(strcmp({R.group}, T(i).group)).level];
    if ~(isscalar(L) && any(L == lv))
        error('vital:badInput', 'target group "%s" has no records at Level %s.', T(i).group, num2str(L));
    end
end
if ~all(isfield(Gs, {'name', 'lo', 'hi', 'start'}))
    error('vital:badInput', 'Gains must be a struct array with fields name, lo, hi and start.');
end
if ~isfield(Gs, 'unit'), [Gs.unit] = deal(''); end
for i = 1:numel(Gs)
    v = [Gs(i).lo Gs(i).hi Gs(i).start];
    if numel(v) ~= 3 || any(~isfinite(v)) || Gs(i).lo > Gs(i).hi || Gs(i).start < Gs(i).lo || Gs(i).start > Gs(i).hi
        error('vital:badInput', 'gain %s: need finite lo <= start <= hi (got %s).', Gs(i).name, num2str(v));
    end
end
if numel(unique({Gs.name})) < numel(Gs)
    error('vital:badInput', 'gain names must be distinct.');
end
B = opts.Builder;
if isempty(B)
    names = {Gs.name};
    if ~all(ismember(names, {'Kq', 'Ka', 'Kr'}))
        error('vital:badInput', 'the default Builder knows the gains Kq, Ka and Kr only; give a Builder for %s.', ...
            strjoin(setdiff(names, {'Kq', 'Ka', 'Kr'}), ', '));
    end
    B = @(AC, env, tr, k) defaultBuilder(AC, env, tr, k, names);
elseif ~isa(B, 'function_handle')
    error('vital:badInput', 'Builder must be a function handle ctrl = b(AC, env, tr, k).');
end
if ~(isfinite(opts.Goal) && opts.Goal >= 0)
    error('vital:badInput', 'Goal must be finite and >= 0.');
end
if ~(opts.MaxIter >= 0 && opts.MaxIter == round(opts.MaxIter))
    error('vital:badInput', 'MaxIter must be a non-negative integer.');
end
if ~(opts.FDStep > 0 && opts.FDStep <= 0.5)
    error('vital:badInput', 'FDStep must be in (0, 0.5] (fraction of the gain range).');
end
if ~(isfinite(opts.Resolution) && opts.Resolution > 0)
    error('vital:badInput', 'Resolution must be finite and > 0.');
end
end

function ctl = defaultBuilder(AC, env, tr, k, names)
% pitch SAS (Kq, Ka) and yaw damper (Kr); a gain not searched is 0 and a law with
% no searched gain is omitted
v = struct('Kq', 0, 'Ka', 0, 'Kr', 0);
for i = 1:numel(names), v.(names{i}) = k(i); end
parts = {};
if any(ismember(names, {'Kq', 'Ka'}))
    parts{end+1} = vital.ctrl.pitchSas(AC, env, tr, 'Kq', v.Kq, 'Ka', v.Ka);
end
if any(strcmp(names, 'Kr'))
    parts{end+1} = vital.ctrl.yawDamper(AC, env, tr, 'Kr', v.Kr);
end
if isscalar(parts), ctl = parts{1}; else, ctl = vital.ctrl.combine(parts{:}); end
end

function [cons, targets] = buildConstraints(T, bare, R, goal)
cons = struct('kind', {}, 'group', {}, 'level', {}, 'req', {}, 'bareMargin', {});
targets = struct('group', {}, 'level', {}, 'bareLevel', {}, 'bareMargin', {}, 'bareCritical', {}, ...
    'achievedLevel', {}, 'achievedMargin', {}, 'critical', {}, 'reached', {});
for i = 1:numel(T)
    g = bare.groups(strcmp({bare.groups.group}, T(i).group));
    [m, cr] = levelMargin(bare, T(i).group, T(i).level);
    targets(end+1) = struct('group', T(i).group, 'level', T(i).level, 'bareLevel', g.inEnvelope.levelHeadline, ...
        'bareMargin', m, 'bareCritical', cr, 'achievedLevel', NaN, 'achievedMargin', NaN, ...
        'critical', struct('record', '', 'cond', struct(), 'value', NaN), 'reached', false); %#ok<AGROW>
    cons(end+1) = struct('kind', 'target', 'group', T(i).group, 'level', T(i).level, 'req', goal, 'bareMargin', m); %#ok<AGROW>
end
for g = bare.groups(:).'
    if any(strcmp(g.group, {T.group})), continue; end
    L = g.inEnvelope.levelHeadline;
    if isnan(L) || L >= 4 || ~any([R(strcmp({R.group}, g.group)).level] == L), continue; end
    m = levelMargin(bare, g.group, L);
    if isnan(m), continue; end
    cons(end+1) = struct('kind', 'protect', 'group', g.group, 'level', L, 'req', max(0, min(goal, m) / 2), ...
        'bareMargin', m); %#ok<AGROW>
end
end

function [m, cr] = levelMargin(res, group, L)
% In-envelope margin of a group to its Level-L boundary: the minimum over the
% group's Level-L records of their in-envelope minimum margin. NaN when a record
% has unrated in-envelope points or none rated; Inf when no record applies.
m = Inf; cr = struct('record', '', 'cond', struct(), 'value', NaN);
recs = res.rules(strcmp({res.rules.group}, group) & [res.rules.level] == L);
for r = recs(:).'
    ie = r.inEnvelope;
    if strcmp(ie.status, 'NOT_APPLICABLE'), continue; end
    if ie.nExcluded > 0 || isempty(ie.criticalIndex) || isnan(ie.minMargin)
        m = NaN; cr = struct('record', r.id, 'cond', struct(), 'value', NaN);
        return
    end
    if ie.minMargin < m || isempty(cr.record)
        m = ie.minMargin;
        cr = struct('record', r.id, 'cond', ie.critical, 'value', ie.criticalValue);
    end
end
end

function [m, crit, res] = assessAt(R, C, B, k, cons)
res = vital.fq.assess(R, vital.fq.f16Factory('Controller', @(AC, env, tr) B(AC, env, tr, k)), C);
m = zeros(numel(cons), 1);
crit = struct('record', {}, 'cond', {}, 'value', {});
for i = 1:numel(cons)
    [m(i), crit(i)] = levelMargin(res, cons(i).group, cons(i).level);
end
end

function v = merit(m, req)
d = req(:) - m(:);
d(isnan(m(:))) = Inf;
v = sum(max(0, d));
end

function tf = sameCritical(a, b)
tf = strcmp(a.record, b.record) && isequal(a.cond, b.cond);
end

function dx = stepFor(Sn, m, req, use, lb, ub)
% minimum-norm step (normalized gains) under the linearized constraints; the
% least-squares step on the violated constraints when that is infeasible
nG = size(Sn, 2);
dx = zeros(nG, 1);
free = ub > lb;
if ~any(free) || ~any(use), return; end
o = optimoptions('lsqlin', 'Display', 'off');
A = -Sn(use, free); b = m(use) - req(use);
nf = sum(free);
[d, ~, ~, flag] = lsqlin(eye(nf), zeros(nf, 1), A, b, [], [], lb(free), ub(free), [], o);
if isempty(d) || flag <= 0
    viol = use & (m < req);
    if ~any(viol), return; end
    d = lsqlin(Sn(viol, free), req(viol) - m(viol), [], [], [], [], lb(free), ub(free), [], o);
end
dx(free) = d;
end

function G = groupTable(res)
G = struct('group', {}, 'paragraph', {}, 'category', {}, 'levelHeadline', {}, 'levelText', {}, ...
    'criticalMargin', {}, 'critical', {}, 'status', {});
for g = res.groups(:).'
    ie = g.inEnvelope;
    G(end+1) = struct('group', g.group, 'paragraph', g.paragraph, 'category', g.category, ...
        'levelHeadline', ie.levelHeadline, 'levelText', ie.levelText, 'criticalMargin', ie.criticalMargin, ...
        'critical', ie.critical, 'status', ie.status); %#ok<AGROW>
end
end

function t = condText(c)
if ~isstruct(c) || isempty(fieldnames(c)), t = '(no condition)'; return; end
f = fieldnames(c);
f = f(~ismember(f, {'gamma_deg', 'g_ftps2'}));
t = strjoin(cellfun(@(n) sprintf('%s=%g', n, c.(n)), f.', 'UniformOutput', false), ' ');
end

function t = gainText(names, k)
t = strjoin(arrayfun(@(i) sprintf('%s = %g', names{i}, k(i)), 1:numel(names), 'UniformOutput', false), ', ');
end
