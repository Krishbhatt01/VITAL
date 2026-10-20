function band = stageBand(errors, opts)
%STAGEBAND  The stage-2 re-run band of the staged default run from the measured
%   stage-1 error (M8 amendment R5, R5-4; docs/PLAN_M5_M8.md "Amendment R5":
%   "set the re-run band to cover the largest measured error x 2, never
%   narrower than [0.8, 1.2]").
%   band = vital.uq.stageBand(errors)
%   band = vital.uq.stageBand(errors, 'Floor', [0.8 1.2])
%   errors  measured |alpha*(stage 1) - alpha*(stage 2)| of the judged CSR (any
%           number >= 1 of them, alpha units; reports/fragments/uq5/DECISIONS.md
%           ADR-036 uq5-4 records the measurement)
%   band    [min(Floor(1), 1 - 2e), max(Floor(2), 1 + 2e)], e = max(errors): a
%           group whose stage-1 judged bracket overlaps it is re-run at the full
%           budget (vital.uq.stagePlan), so a stage-1 decision about alpha* = 1
%           stands only when it is at least twice the largest measured error
%           away from 1.
%   Errors: vital:badInput (errors empty, not finite or < 0; Floor not around 1).
arguments
    errors (1,:) double
    opts.Floor (1,2) double = [0.8 1.2]
end
F = opts.Floor;
if isempty(errors) || any(~isfinite(errors)) || any(errors < 0)
    error('vital:badInput', 'stageBand needs at least one measured error, every one finite and >= 0.');
end
if ~(F(1) <= 1 && F(2) >= 1)
    error('vital:badInput', 'Floor must contain 1 (Floor(1) <= 1 <= Floor(2)).');
end
e = max(errors);
band = [min(F(1), 1 - 2 * e), max(F(2), 1 + 2 * e)];
end
