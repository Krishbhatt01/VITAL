function plan = searchPlan(group, metrics, margin0, fields, opts)
%SEARCHPLAN  Which parameters and which objective the M8 bound-worst search of a
%   group uses (docs/PLAN_M5_M8.md, M8 amendment after review R3, R3-M2/M3).
%   plan = vital.uq.searchPlan(group, metrics, margin0, fields)
%   plan = vital.uq.searchPlan(..., 'LonOnly', true, 'LonFields', {'Cm_q', 'Cm_table'},
%                              'Surrogate', true)
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
%     'full'          every parameter, the margin itself
%   plan.sampledOnly is true when a metric is binary (unit '0/1' in
%   vital.fq.metricNames, e.g. 3.3.1.4 coupled_roll_spiral_present): the margin
%   is flat or jumps, the optimizer's convergence means nothing there, and the
%   bound-worst rests on the sampled points only (R3-M2). vital.uq.analyze
%   also sets it when every evaluated margin is equal (flat).
%   plan fields: group, mode, idx (searched parameter indices into fields,
%     ascending), fields (searched), objective, reason, sampledOnly,
%     sampledReason.
arguments
    group (1,:) char
    metrics cell
    margin0 (1,1) double
    fields cell
    opts.LonOnly (1,1) logical = true
    opts.LonFields cell = {'Cm_q', 'Cm_table'}
    opts.Surrogate (1,1) logical = true
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
end
