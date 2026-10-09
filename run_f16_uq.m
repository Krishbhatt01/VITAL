function r = run_f16_uq(opts)
%RUN_F16_UQ  M8 user entry point: does the augmented F-16's in-envelope MIL-F-8785C
%   Level hold when the aerodynamic data are uncertain?
%
%   run_f16_uq                      plan defaults (docs/PLAN_M5_M8.md, M8): every
%                                   group with a finite in-envelope headline Level
%                                   of the augmented aircraft (Kq 0.02, Ka 0.14,
%                                   Kr 0.82), widths x0.5 / x1 / x1.5 of the
%                                   JUDGMENT sigmas (uq\f16_uncertainty.json),
%                                   32 LHS points, 2 fmincon starts x 60
%                                   evaluations, 4 candidate conditions, N = 200
%                                   Monte Carlo samples (an hour or more)
%   run_f16_uq('Groups', {'3.3.1.1-CatA-other'}, 'WidthScales', 1, ...)
%                                   vital.uq.analyze options: Groups,
%                                   WidthScales, Conditions, NumLHS, NumStarts,
%                                   MaxEvals, NumCandidates, N
%   run_f16_uq(..., 'Label', 'x', 'ReportDir', d, 'Overwrite', true, 'Quiet', true)
%
%   Writes <ReportDir>\f16_uq_<Label>.json/.md (default reports\uq,
%   f16_uq_default). An existing file is never overwritten unless 'Overwrite':
%   the run is then written under a timestamped name and the printout says so.
%   Prints the headline table: per group the nominal Level, the bound-worst
%   margin and status, the Monte Carlo successes/N and Clopper-Pearson lower
%   bound, and the verdict at every width; the widths are labelled JUDGMENT.
%   r: the vital.uq.analyze result plus r.files (json, md) and r.printout.
%   Works from a fresh MATLAB session: it puts VITAL on the path itself.
arguments
    opts.Label (1,:) char = 'default'
    opts.ReportDir (1,:) char = ''
    opts.Overwrite (1,1) logical = false
    opts.Quiet (1,1) logical = false
    opts.Groups cell = {}
    opts.WidthScales (1,:) double = [0.5 1 1.5]
    opts.Conditions struct = struct([])
    opts.NumLHS (1,1) double = 32
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 60
    opts.NumCandidates (1,1) double = 4
    opts.N (1,1) double = 200
end
addpath(fileparts(mfilename('fullpath')));
rdir = opts.ReportDir;
if isempty(rdir), rdir = fullfile(vital.paths('reports'), 'uq'); end
r = vital.uq.analyze('Groups', opts.Groups, 'WidthScales', opts.WidthScales, 'Conditions', opts.Conditions, ...
    'NumLHS', opts.NumLHS, 'NumStarts', opts.NumStarts, 'MaxEvals', opts.MaxEvals, ...
    'NumCandidates', opts.NumCandidates, 'N', opts.N, 'Quiet', opts.Quiet);
name = ['f16_uq_' opts.Label];
kept = '';
if ~opts.Overwrite && (isfile(fullfile(rdir, [name '.json'])) || isfile(fullfile(rdir, [name '.md'])))
    kept = name;
    name = sprintf('%s_%s', name, char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS')));
end
r.files = vital.uq.writeReport(r, rdir, name);
P = {'', 'M8 UNCERTAINTY: augmented NESC F-16, in-envelope MIL-F-8785C Levels under JUDGMENT aerodynamic widths', ''};
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
