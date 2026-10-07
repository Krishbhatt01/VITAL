function C = inEnvelopeConditions()
%INENVELOPECONDITIONS  The registered F-16 condition space restricted to the grid
%   values that hold every point inside the NESC validity envelope (M7).
%   C = vital.ctrl.inEnvelopeConditions()
%
%   vital.fq.loadConditions(conditions_f16.json, 'Axes', ...) with
%     h_ft        [5000 8000 13000]
%     mach        [0.45 0.50 0.55 0.63]
%     cg_pct_mac  [20 25 30]
%   These are the default-grid values whose points can be IN the validity
%   envelope (|h - 10,000 ft| <= 5,000 ft, |KEAS - 287.8| <= 20 %): 36 points,
%   the 30 IN points of reports/fq/f16_fq_default_baseline (no refinement point
%   of the default grid is IN) and 6 EXTRAPOLATED (Mach 0.63 at 5,000 and
%   8,000 ft). The headline (in-envelope) Levels of vital.fq.assess over C, with
%   no refinement, are therefore Levels over exactly the default grid's
%   in-envelope points. C.grid is 'user' (vital.fq.loadConditions 'Axes').
file = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
C = vital.fq.loadConditions(file, 'Axes', struct('h_ft', [5000 8000 13000], 'mach', [0.45 0.50 0.55 0.63], ...
    'cg_pct_mac', [20 25 30]));
end
