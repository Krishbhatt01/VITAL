function plan = searchPlan(group, metrics, margin0, fields, opts)
%SEARCHPLAN  Which parameters and which objective the M8 bound-worst search of a
%   group uses (docs/PLAN_M5_M8.md, M8 amendment after review R3, R3-M2/M3;
%   amendment R4b, R4-3 corrected and R4-9).
%   plan = vital.uq.searchPlan(group, metrics, margin0, fields)
%   plan = vital.uq.searchPlan(..., 'LonOnly', true, 'LonFields', {'Cm_q', 'Cm_table'},
%                              'Surrogate', true, 'Method', 'auto', 'GridMaxDim', 2,
%                              'LatDropCmq', false, 'Lattice', false)
%
%   group    group name, e.g. '3.2.2.1.1-CatA'
%   metrics  cellstr: the metrics of the group's records (res.groups.metrics)
%   margin0  the group's nominal in-envelope margin to its headline Level
%   fields   1 x d AeroScale fields of the box, in box order
%   Modes (first that applies):
%     'surrogate'     margin0 = +Inf and every metric is spiral_T2_s (3.3.1.3):
%                     the box is searched on the smooth surrogate Re(spiral
%                     root), maximized (vital.uq.surrogateWorst), with candidate
%                     conditions ranked by it; all parameters (R3-M3(b))
%     'longitudinal'  a MIL-F-8785C 3.2.x group (longitudinal) and LonOnly: only
%                     the LonFields present in the box are searched, the lateral
%                     multipliers are held at 1. Justification: at a wings-level,
%                     beta = 0 trim the lateral multipliers change no
%                     longitudinal metric (tests/M8/tUqR3F16.m#lonLatInvariance,
%                     1e-9 relative; R3-M3(a)). Lateral groups keep the full box
%                     because Cm_table moves the trim. No LonField in the box:
%                     'full'.
%     'lateral'       (amendment R4b, R4-9; 'LatDropCmq' true) a lateral group
%                     (name starting '3.3.') whose box has Cm_q and at least one
%                     other parameter does not search Cm_q (held at 1): Cm_q acts
%                     only through the pitch rate, zero at the wings-level trim,
%                     so it cannot change a lateral metric (gate:
%                     tests/M8/tUqR4bF16.m#lateralInvarianceCmq, and the runtime
%                     check of vital.uq.analyze with the fallback
%                     vital.uq.gatePlan). A 'surrogate' group drops Cm_q the same
%                     way and keeps its mode. plan.dropped = {'Cm_q'}.
%     'full'          every parameter, the margin itself
%   plan.method: 'Method' if it is not 'auto'; with 'auto', 'lattice' for a
%   'longitudinal' plan when 'Lattice' is true (R4b R4-3 corrected: the shared
%   adaptive lattice, vital.uq.lattice, whatever the dimension <= 3), else
%   vital.uq.searchMethod(number of searched parameters).
%   Defaults: 'LatDropCmq' false and 'Lattice' false here (the R3/R4 plans);
%   vital.uq.analyze passes true for both (the R4b design).
%   plan.sampledOnly is true when a metric is binary (unit '0/1' in
%   vital.fq.metricNames, e.g. 3.3.1.4 coupled_roll_spiral_present): the margin
%   is flat or jumps, the optimizer's convergence means nothing there, and the
%   bound-worst rests on the sampled points only (R3-M2). vital.uq.analyze
%   also sets it when every evaluated margin is equal (flat).
%   plan fields: group, mode, idx (searched parameter indices into fields,
%     ascending), fields (searched), objective, reason, sampledOnly,
%     sampledReason, method, dropped (cellstr), latCheck (the R4-9 check; empty
%     fields until vital.uq.gatePlan sets it).
arguments
    group (1,:) char
    metrics cell
    margin0 (1,1) double
    fields cell
    opts.LonOnly (1,1) logical = true
    opts.LonFields cell = {'Cm_q', 'Cm_table', 'Cm_basic', 'Cm_de'}
    opts.Surrogate (1,1) logical = true
    opts.Method (1,:) char = 'auto'
    opts.GridMaxDim (1,1) double = 2
    opts.LatDropCmq (1,1) logical = false
    opts.Lattice (1,1) logical = false
end
d = numel(fields);
plan = struct('group', group, 'mode', 'full', 'idx', 1:d, 'fields', {fields(:).'}, ...
    'objective', 'margin to the nominal Level (minimized)', ...
    'reason', 'all parameters (the margin depends on the whole box)', 'sampledOnly', false, 'sampledReason', '');
[names, units] = vital.fq.metricNames();
bin = names(strcmp(units, '0/1'));
isBin = ismember(metrics, bin);
if any(isBin)
    plan.sampledOnly = true;
    plan.sampledReason = sprintf(['binary metric (%s, 0/1): the margin is flat or jumps, so the optimizer''s ' ...
        'convergence means nothing; the bound-worst rests on the sampled points only'], strjoin(metrics(isBin), ', '));
end
if opts.Surrogate && margin0 == Inf && ~isempty(metrics) && all(strcmp(metrics, 'spiral_T2_s'))
    plan.mode = 'surrogate';
    plan.objective = 'spiral root real part (1/s), maximized';
    plan.reason = ['the nominal margin is +Inf (a stable spiral: T2 infinite), which an optimizer cannot move; ' ...
        'the box is searched on the smooth surrogate Re(spiral root) (maximized) over all parameters, and the ' ...
        'candidate conditions are ranked by it'];
elseif opts.LonOnly && startsWith(group, '3.2.')
    il = find(ismember(fields, opts.LonFields));
    if ~isempty(il)
        plan.mode = 'longitudinal';
        plan.idx = il(:).';
        plan.fields = fields(plan.idx);
        plan.reason = sprintf(['longitudinal group: searched over the longitudinal parameters only (%s), the ' ...
            'lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: ' ...
            'tests/M8/tUqR3F16.m#lonLatInvariance)'], strjoin(plan.fields, ', '));
    end
end
plan.dropped = {};
iq = plan.idx(strcmp(fields(plan.idx), 'Cm_q'));
if opts.LatDropCmq && startsWith(group, '3.3.') && ~isempty(iq) && numel(plan.idx) > 1
    plan.idx = setdiff(plan.idx, iq);
    plan.fields = fields(plan.idx);
    plan.dropped = {'Cm_q'};
    if strcmp(plan.mode, 'full'), plan.mode = 'lateral'; end
    plan.reason = sprintf(['%s; R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the ' ...
        'pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated)'], plan.reason);
end
if strcmp(opts.Method, 'auto')
    if opts.Lattice && strcmp(plan.mode, 'longitudinal')
        plan.method = 'lattice';
    else
        plan.method = vital.uq.searchMethod(numel(plan.idx), 'GridMaxDim', opts.GridMaxDim);
    end
else
    plan.method = opts.Method;
end
plan.latCheck = struct('passed', false, 'reason', 'not checked');
end
