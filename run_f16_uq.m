function r = run_f16_uq(opts)
%RUN_F16_UQ  M8 user entry point: does the augmented F-16's in-envelope MIL-F-8785C
%   Level hold when the aerodynamic data are uncertain?
%
%   run_f16_uq                      plan defaults (docs/PLAN_M5_M8.md, M8 and
%                                   amendment R4): every group with a finite
%                                   in-envelope headline Level of the augmented
%                                   aircraft (Kq 0.02, Ka 0.14, Kr 0.82), the x1
%                                   box of the JUDGMENT sigmas
%                                   (uq\f16_uncertainty.json, spec v2), the
%                                   Critical Similitude Ratio of the judged and
%                                   the equal-percentage (10 %) shapes (the
%                                   headline), the shared lattice for the
%                                   longitudinal groups (R4b), grid search for <= 2 searched
%                                   parameters / hybrid (DE 16 x 8 + Nelder-Mead
%                                   2 starts x 150) above, 32 LHS points, 4
%                                   candidate conditions, N = 200 Monte Carlo
%                                   samples (many hours: see
%                                   reports/fragments/uq3/NOTES.md)
%   run_f16_uq('Groups', {'3.3.1.1-CatA-other'}, 'WidthScales', 1, ...)
%                                   vital.uq.analyze options: Groups,
%                                   WidthScales, Conditions, NumLHS, NumStarts,
%                                   MaxEvals, NumCandidates, N
%   run_f16_uq(..., 'WidthScales', [0.5 1 1.5])   the R3 width sensitivity (off by
%                                   default since amendment R4-2)
%   run_f16_uq(..., 'CSR', true, 'Method', 'auto', 'AlphaMax', 3, 'Resolution', 0.01,
%              'EqualPct', 0.10, 'DEPopulation', 16, 'DEGenerations', 8,
%              'GridPoints', 11, 'Spec', spec, 'Rules', R)   amendment R4 options
%                                   (vital.uq.analyze)
%   run_f16_uq(..., 'MaxRounds', 3, 'LonOnly', true, 'Surrogate', true)
%                                   the review-R3 amendment (2026-10-09; defaults
%                                   on): moving limits re-searched (at most
%                                   MaxRounds rounds), 3.2.x groups searched over
%                                   Cm_q and Cm_table only, +Inf spiral groups
%                                   searched on Re(spiral root)
%   run_f16_uq(..., 'Staged', true, 'Stage1', struct('NumCandidates', 2), 'Stage2Band',
%              [0.8 1.2], 'Lattice', true, 'LatticeMaxLevel', 10, 'LatticeMaxPoints',
%              6000, 'LatDropCmq', true, 'Bracket', true)
%                                   amendment R4b (2026-10-14; defaults on):
%                                   STAGED run (R4-8: stage 1 at NumCandidates 2
%                                   and differential evolution 8 x 4 with the
%                                   stated Monte Carlo N = 200; stage 2 at the
%                                   full budget only for groups whose judged CSR
%                                   bracket overlaps [0.8, 1.2] or that are
%                                   NOT_ASSESSABLE for budget reasons (FC-901);
%                                   the report states the deciding stage), the
%                                   SHARED ADAPTIVE LATTICE of the longitudinal
%                                   groups (R4-3 corrected; caps 10 levels per
%                                   axis and 6000 lattice points per group),
%                                   breakpoint BRACKETING of linearization
%                                   failures (R4-7) and lateral groups without
%                                   Cm_q (R4-9, gated); 'Staged' false runs one
%                                   stage at the given budget
%   run_f16_uq(..., 'LatticeCorners', true, 'LatticeTotalPoints', 12000, 'Piecewise', true)
%                                   amendment R5 (2026-10-14; defaults on): h/2
%                                   lattice certificate, verdict from the judged
%                                   box R(1) (alpha* reported as a bracket),
%                                   piecewise certificate at the aero-table
%                                   breakpoints, fresh assessments at the
%                                   corners of R(1) and R(alphaLo), a global
%                                   lattice budget, the stage-2 band from the
%                                   measured stage-1 error (vital.uq.stageBand)
%   run_f16_uq(..., 'Label', 'x', 'ReportDir', d, 'Overwrite', true, 'Quiet', true)
%
%   Writes <ReportDir>\f16_uq_<Label>.json/.md (default reports\uq,
%   f16_uq_default). An existing file is never overwritten unless 'Overwrite':
%   the run is then written under a timestamped name and the printout says so.
%   Prints the headline (vital.uq.headline): per group the nominal Level, the
%   CSR alpha* of both shapes with the parametric safety margin and the CPV,
%   the x1 bound-worst, the Monte Carlo successes/N and Clopper-Pearson lower
%   bound, and the R4 verdict; then the box table per width; the widths are
%   labelled JUDGMENT.
%   Below it: the bound-worst is a search estimate (upper bound), not a proof;
%   the box nesting; the groups omitted for a NaN headline.
%   r: the vital.uq.analyze result plus r.files (json, md) and r.printout.
%   Works from a fresh MATLAB session: it puts VITAL on the path itself.
arguments
    opts.Label (1,:) char = 'default'
    opts.ReportDir (1,:) char = ''
    opts.Overwrite (1,1) logical = false
    opts.Quiet (1,1) logical = false
    opts.Groups cell = {}
    opts.WidthScales (1,:) double = 1
    opts.Conditions struct = struct([])
    opts.NumLHS (1,1) double = 32
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 150
    opts.NumCandidates (1,1) double = 4
    opts.N (1,1) double = 200
    opts.MaxRounds (1,1) double = 3
    opts.LonOnly (1,1) logical = true
    opts.Surrogate (1,1) logical = true
    opts.Method (1,:) char = 'auto'
    opts.CSR (1,1) logical = true
    opts.Spec struct = struct([])
    opts.Rules struct = struct([])
    opts.AlphaMax (1,1) double = 3
    opts.Resolution (1,1) double = 0.01
    opts.EqualPct (1,1) double = 0.10
    opts.DEPopulation (1,1) double = 16
    opts.DEGenerations (1,1) double = 8
    opts.GridPoints (1,1) double = 11
    opts.Staged (1,1) logical = true
    opts.Stage1 struct = struct([])
    opts.Stage2Band (1,2) double = [0.8 1.2]   % R5-4: = vital.uq.stageBand(measured errors, max 0.075): the floor (ADR-036 uq5-4)
    opts.Lattice (1,1) logical = true
    opts.LatticeMaxLevel (1,1) double = 10
    opts.LatticeMaxPoints (1,1) double = 6000
    opts.LatDropCmq (1,1) logical = true
    opts.Bracket (1,1) logical = true
    opts.LatticeCorners (1,1) logical = true
    opts.LatticeTotalPoints (1,1) double = 12000
    opts.Piecewise (1,1) logical = true
end
addpath(fileparts(mfilename('fullpath')));
rdir = opts.ReportDir;
if isempty(rdir), rdir = fullfile(vital.paths('reports'), 'uq'); end
r = vital.uq.analyze('Groups', opts.Groups, 'WidthScales', opts.WidthScales, 'Conditions', opts.Conditions, ...
    'NumLHS', opts.NumLHS, 'NumStarts', opts.NumStarts, 'MaxEvals', opts.MaxEvals, ...
    'NumCandidates', opts.NumCandidates, 'N', opts.N, 'Quiet', opts.Quiet, 'MaxRounds', opts.MaxRounds, ...
    'LonOnly', opts.LonOnly, 'Surrogate', opts.Surrogate, 'Method', opts.Method, 'CSR', opts.CSR, ...
    'Spec', opts.Spec, 'Rules', opts.Rules, 'AlphaMax', opts.AlphaMax, 'Resolution', opts.Resolution, ...
    'EqualPct', opts.EqualPct, 'DEPopulation', opts.DEPopulation, 'DEGenerations', opts.DEGenerations, ...
    'GridPoints', opts.GridPoints, 'Staged', opts.Staged, 'Stage1', opts.Stage1, 'Stage2Band', opts.Stage2Band, ...
    'Lattice', opts.Lattice, 'LatDropCmq', opts.LatDropCmq, 'Bracket', opts.Bracket, ...
    'LatticeMaxLevel', opts.LatticeMaxLevel, 'LatticeMaxPoints', opts.LatticeMaxPoints, ...
    'LatticeCorners', opts.LatticeCorners, 'LatticeTotalPoints', opts.LatticeTotalPoints, 'Piecewise', opts.Piecewise);
name = ['f16_uq_' opts.Label];
kept = '';
if ~opts.Overwrite && (isfile(fullfile(rdir, [name '.json'])) || isfile(fullfile(rdir, [name '.md'])))
    kept = name;
    name = sprintf('%s_%s', name, char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS')));
end
r.files = vital.uq.writeReport(r, rdir, name);
P = {'', ['M8 UNCERTAINTY: augmented NESC F-16, in-envelope MIL-F-8785C Levels under JUDGMENT aerodynamic widths ' ...
    '(headline: Critical Similitude Ratio, amendment R4)'], ''};
P = [P, vital.uq.headline(r)];
P{end+1} = '';
P{end+1} = sprintf('Report: %s', r.files.md);
if ~isempty(kept)
    P{end+1} = sprintf('The existing file %s.json/.md was kept (not overwritten; use ''Overwrite'', true).', ...
        fullfile(rdir, kept));
end
r.printout = strjoin(P, newline);
if ~opts.Quiet, fprintf('%s\n', r.printout); end
end
