function plan = gatePlan(plan, check, fields, opts)
%GATEPLAN  The R4-9 fallback (M8 amendment R4b; docs/PLAN_M5_M8.md "Amendment
%   R4b": lateral groups drop Cm_q, gated by an invariance test, with a fallback
%   to the full set if the gate fails).
%   plan = vital.uq.gatePlan(plan, check, fields)
%   plan = vital.uq.gatePlan(plan, check, fields, 'Method', 'auto', 'GridMaxDim', 2)
%   plan    a vital.uq.searchPlan result (plan.dropped: the parameters it does
%           not search)
%   check   the invariance check of the dropped parameters (check.passed,
%           check.reason; vital.uq.invarianceCheck)
%   fields  1 x d AeroScale fields of the box
%   If plan.dropped is not empty and check.passed is false, every parameter is
%   searched again: idx 1:d, fields all, dropped {}, mode 'full' (a 'surrogate'
%   plan keeps its mode), method recomputed by vital.uq.searchMethod when
%   'Method' is 'auto', and plan.reason says the gate FAILED. plan.latCheck =
%   check in every case.
arguments
    plan (1,1) struct
    check (1,1) struct
    fields cell
    opts.Method (1,:) char = 'auto'
    opts.GridMaxDim (1,1) double = 2
end
plan.latCheck = check;
if ~isfield(plan, 'dropped') || isempty(plan.dropped)
    return
end
if check.passed
    plan.reason = sprintf('%s; the R4-9 gate passed (%s)', plan.reason, check.reason);
    return
end
d = numel(fields);
plan.reason = sprintf(['%s; the R4-9 gate FAILED (%s), so %s is searched again (fallback to the full set of ' ...
    'parameters)'], plan.reason, check.reason, strjoin(plan.dropped, ', '));
plan.idx = 1:d;
plan.fields = fields(:).';
plan.dropped = {};
if ~strcmp(plan.mode, 'surrogate'), plan.mode = 'full'; end
if strcmp(opts.Method, 'auto')
    plan.method = vital.uq.searchMethod(d, 'GridMaxDim', opts.GridMaxDim);
end
end
