function m = searchMethod(d, opts)
%SEARCHMETHOD  Search method of a box with d searched parameters (M8 amendment R4,
%   docs/PLAN_M5_M8.md R4-3 and R4-4).
%   m = vital.uq.searchMethod(d)
%   m = vital.uq.searchMethod(d, 'GridMaxDim', 2)
%   d <= GridMaxDim  'grid'    dense grid + local refinement + Lipschitz bound
%                              (grid-certified, R4-3)
%   d >  GridMaxDim  'hybrid'  seeded differential evolution + Nelder-Mead with a
%                              bound transform (search estimate, R4-4)
%   The rule is by the number of SEARCHED parameters. Note: after R4-5 the
%   longitudinal groups are searched over Cm_q, Cm_basic and Cm_de (3
%   parameters), so with the default GridMaxDim 2 they are searched by the
%   hybrid method (reports/fragments/uq3/NOTES.md).
%   Errors: vital:badInput (d not a positive integer, GridMaxDim < 0).
arguments
    d (1,1) double
    opts.GridMaxDim (1,1) double = 2
end
if ~(isfinite(d) && d >= 1 && d == round(d))
    error('vital:badInput', 'd must be a positive integer.');
end
if ~(isfinite(opts.GridMaxDim) && opts.GridMaxDim >= 0)
    error('vital:badInput', 'GridMaxDim must be >= 0.');
end
if d <= opts.GridMaxDim
    m = 'grid';
else
    m = 'hybrid';
end
end
