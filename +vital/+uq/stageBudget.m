function [s1, same] = stageBudget(full, opts)
%STAGEBUDGET  The stage-1 budget of the staged default run (M8 amendment R4b,
%   R4-8; docs/PLAN_M5_M8.md "Amendment R4b").
%   [s1, same] = vital.uq.stageBudget(full)
%   [s1, same] = vital.uq.stageBudget(full, 'NumCandidates', 2, 'DEPopulation', 8,
%                                     'DEGenerations', 4)
%   full  struct of the full (stage-2) budget, e.g. the vital.uq.analyze options
%   s1    full with NumCandidates, DEPopulation and DEGenerations replaced by the
%         smaller of the full value and the stage-1 value (the reduced budget:
%         2 candidate conditions and a differential-evolution stage of 8 members
%         x 4 generations instead of 16 x 8); every other field (the Monte Carlo
%         N = 200, NumLHS, MaxEvals, ...) unchanged. A field missing from full
%         stays missing.
%   same  isequal(s1, full): stage 2 could not add anything
%   Errors: vital:badInput (a stage-1 value not a non-negative integer).
arguments
    full (1,1) struct
    opts.NumCandidates (1,1) double = 2
    opts.DEPopulation (1,1) double = 8
    opts.DEGenerations (1,1) double = 4
end
s1 = full;
for f = {'NumCandidates', 'DEPopulation', 'DEGenerations'}
    v = opts.(f{1});
    if ~(isfinite(v) && v >= 0 && v == round(v))
        error('vital:badInput', 'the stage-1 %s must be a non-negative integer.', f{1});
    end
    if isfield(full, f{1})
        s1.(f{1}) = min(full.(f{1}), v);
    end
end
same = isequal(s1, full);
end
