function [need, why] = stagePlan(e, opts)
%STAGEPLAN  Does an analysed group need stage 2 of the staged run? (M8 amendment
%   R4b, R4-8; docs/PLAN_M5_M8.md "Amendment R4b").
%   [need, why] = vital.uq.stagePlan(e)
%   [need, why] = vital.uq.stagePlan(e, 'Band', [0.8 1.2])
%   e     a group of vital.uq.analyze (its STAGE-1 result): status, plan.method,
%         csr.judged (status, alphaLo, alphaHi, reason; may be empty when the
%         CSR was not computed), widths (widthScale, bw.status, bw.reason)
%   need  true when
%         (a) e.status is 'DONE' and e.plan.method is not 'lattice' (the
%             longitudinal lattice groups are decided by the shared lattice in
%             stage 1 and need no stage 2), AND
%         (b) the judged CSR bracket [alphaLo, alphaHi] overlaps Band (closed
%             intervals: alphaLo <= Band(2) and alphaHi >= Band(1)), OR the
%             judged CSR is NOT_ASSESSABLE for budget reasons (its reason
%             contains 'FC-901' or 'budget'), OR (no CSR) the x1 bound-worst is
%             NOT_ASSESSABLE with a reason containing 'FC-901' or 'budget'
%   why   the rule that applied (text)
%   Errors: vital:badInput (Band(1) > Band(2)).
arguments
    e (1,1) struct
    opts.Band (1,2) double = [0.8 1.2]
end
B = opts.Band;
if ~(B(1) <= B(2))
    error('vital:badInput', 'Band must satisfy Band(1) <= Band(2).');
end
need = false;
if ~isfield(e, 'status') || ~strcmp(e.status, 'DONE')
    st = ''; if isfield(e, 'status'), st = e.status; end
    why = sprintf('the group was not searched (status %s): nothing to re-run', st);
    return
end
if isfield(e, 'plan') && isfield(e.plan, 'method') && strcmp(e.plan.method, 'lattice')
    why = 'longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2)';
    return
end
budget = @(st, r) strcmp(st, 'NOT_ASSESSABLE') && (contains(r, 'FC-901') || contains(r, 'budget'));
if isfield(e, 'csr') && ~isempty(e.csr) && isfield(e.csr, 'judged')
    cj = e.csr.judged;
    if cj.alphaLo <= B(2) && cj.alphaHi >= B(1)
        need = true;
        why = sprintf('the judged CSR bracket [%.4g, %.4g] (%s) overlaps [%g, %g]', cj.alphaLo, cj.alphaHi, cj.status, ...
            B(1), B(2));
    elseif budget(cj.status, cj.reason)
        need = true;
        why = sprintf('the judged CSR is NOT_ASSESSABLE for budget reasons: %s', cj.reason);
    else
        why = sprintf(['the judged CSR bracket [%.4g, %.4g] (%s) does not overlap [%g, %g] and is not ' ...
            'NOT_ASSESSABLE for budget reasons'], cj.alphaLo, cj.alphaHi, cj.status, B(1), B(2));
    end
    return
end
bw = [];
if isfield(e, 'widths') && ~isempty(e.widths)
    k = find([e.widths.widthScale] == 1, 1);
    if ~isempty(k), bw = e.widths(k).bw; end
end
if ~isempty(bw) && budget(bw.status, bw.reason)
    need = true;
    why = sprintf('no CSR; the x1 bound-worst is NOT_ASSESSABLE for budget reasons: %s', bw.reason);
elseif isempty(bw)
    why = 'no CSR and no x1 bound-worst: nothing decides a stage 2';
else
    why = sprintf('no CSR; the x1 bound-worst (%s) is not NOT_ASSESSABLE for budget reasons', bw.status);
end
end
