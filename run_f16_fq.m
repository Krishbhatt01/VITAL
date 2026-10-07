function res = run_f16_fq(opts)
%RUN_F16_FQ  MIL-F-8785C Class IV flying-qualities assessment of the NESC F-16
%   (bare airframe; the entry point for users).
%
%   run_f16_fq                               registered default grid (altitude x
%                                            Mach x CG, in and around the NESC
%                                            validity envelope), with refinement
%   run_f16_fq('Grid', 'exploration')        the wide exploration grid (mostly
%                                            EXTRAPOLATED); also 'test', 'readme',
%                                            'mutation' (rules/mil_f_8785c/conditions_f16.json)
%   run_f16_fq('Axes', struct('h_ft', [5000 8000], 'mach', [0.45 0.5], 'cg_pct_mac', 25))
%                                            a user grid (h_ft, mach or V_ftps, cg_pct_mac)
%   run_f16_fq(..., 'Refine', false)         grid only
%   run_f16_fq(..., 'AeroScale', struct('Cm_q', 0.3))   a mutated aircraft
%                                            (Cm_q, Cl_p, Cnt_table; see
%                                            vital.aircraft.f16.config)
%   run_f16_fq(..., 'ReportDir', d)          default <VITAL>\reports\fq
%   run_f16_fq(..., 'Overwrite', true)       replace an existing report of the
%                                            same name (default: never; a
%                                            timestamped name is used instead)
%   res = run_f16_fq(..., 'Quiet', true)     no printout
%
%   Report files: <ReportDir>\f16_fq_<grid>_<AeroScale tag>.json/.md
%   (vital.fq.reportName; grid 'user' for 'Axes'), e.g. f16_fq_default_baseline.
%   An existing file is never silently overwritten (review R2 M9).
%
%   Prints, per rule group (paragraph + Category): paragraph, category,
%   metric(s), the HEADLINE Level = the Level over the points inside the NESC
%   model's validity envelope (rules/mil_f_8785c/conditions_f16.json 'validity';
%   a stated judgment), its margin and critical condition, the status and the
%   unrated (excluded) points; then, separately labelled EXTRAPOLATED (outside
%   the NESC model validity), the Level and critical condition over the other
%   points; then the coverage table of criteria VITAL does not assess.
%   A group with unrated points never shows a plain Level (review R2 B2).
%   There is no published MIL-F-8785C Level for this model: every Level is a
%   REG (regression) result of the VITAL chain, not a published value.
%   Works from a fresh MATLAB session: it puts VITAL on the path itself.
arguments
    opts.Grid (1,:) char = 'default'
    opts.Axes struct = struct([])
    opts.Refine (1,1) logical = true
    opts.ReportDir (1,:) char = ''
    opts.AeroScale (1,1) struct = struct()
    opts.Overwrite (1,1) logical = false
    opts.Quiet (1,1) logical = false
end
addpath(fileparts(mfilename('fullpath')));
if isempty(opts.ReportDir), opts.ReportDir = fullfile(vital.paths('reports'), 'fq'); end
C = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), ...
    'Grid', opts.Grid, 'Axes', opts.Axes);
name = vital.fq.reportName(C.grid, opts.AeroScale);
kept = '';
if ~opts.Overwrite && (isfile(fullfile(opts.ReportDir, [name '.json'])) || isfile(fullfile(opts.ReportDir, [name '.md'])))
    kept = fullfile(opts.ReportDir, name);
    name = sprintf('%s_%s', name, char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS')));
end
R = vital.fq.loadRules();
cov = vital.fq.loadCoverage();
lab = sprintf(['NESC F-16 bare airframe, MIL-F-8785C Class IV. REG: no published F-16 Level exists; ' ...
    'these Levels are regression results only. AeroScale: %s'], scaleStr(opts.AeroScale));
out = vital.fq.assess(R, vital.fq.f16Factory('AeroScale', opts.AeroScale), C, 'Refine', opts.Refine, ...
    'ReportDir', opts.ReportDir, 'ReportName', name, 'Coverage', cov, 'Label', lab);
if nargout > 0, res = out; end
if opts.Quiet, return; end

ax = {C.axes.name};
fprintf('MIL-F-8785C Class IV flying qualities: %s\n', lab);
fprintf('  condition space %s, grid %s: %d points (%d refinement), %.1f s total, %.3f s per point\n', ...
    C.id, C.grid, numel(out.points), sum([out.points.refine]), out.timing.total_s, out.timing.perPoint_s);
st = {out.points.status};
[u, ~, j] = unique(st);
fprintf('  point status: %s\n', strjoin(arrayfun(@(k) sprintf('%s %d', u{k}, sum(j == k)), 1:numel(u), 'UniformOutput', false), ', '));
nIn = sum(strcmp({out.points.envelope}, 'IN'));
fprintf('  validity envelope (judgment, see conditions_f16.json): %d points IN, %d EXTRAPOLATED\n', nIn, numel(out.points) - nIn);
if ~isempty(C.validity), fprintf('    %s\n', C.validity.judgment); end
for c = fieldnames(C.categoryPolicy).'
    e = C.categoryPolicy.(c{1});
    if ~e.assess, fprintf('  Category %s NOT_ASSESSABLE: %s\n', c{1}, e.reason); end
end
fprintf('\n  HEADLINE: points inside the NESC validity envelope\n');
fprintf('  %-20s %-10s %-4s %-44s %-30s %9s  %-38s %-15s %s\n', 'group', 'paragraph', 'Cat', 'metric(s)', 'Level', ...
    'margin', 'critical condition', 'status', 'excluded (unrated)');
for g = out.groups(:).'
    s = g.inEnvelope;
    fprintf('  %-20s %-10s %-4s %-44s %-30s %9s  %-38s %-15s %s\n', g.group, g.paragraph, g.category, ...
        strjoin(g.metrics, ','), lvlStr(s), num(s.criticalMargin), condStr(s.critical, ax), s.status, exStr(s.excludedBy));
end
fprintf('\n  EXTRAPOLATED (outside the NESC model validity envelope; indicative only)\n');
fprintf('  %-20s %-4s %-30s %9s  %-38s %-15s %s\n', 'group', 'Cat', 'Level', 'margin', 'critical condition', 'status', 'excluded (unrated)');
for g = out.groups(:).'
    x = g.extrapolated;
    fprintf('  %-20s %-4s %-30s %9s  %-38s %-15s %s\n', g.group, g.category, lvlStr(x), num(x.criticalMargin), ...
        condStr(x.critical, ax), x.status, exStr(x.excludedBy));
end
fprintf(['  Notes: Level = the best Level whose boundaries all hold (6.7.1); "or worse (k unrated)" = k points could not be\n' ...
    '  rated, so the Level is not established; margin = normalized margin to the boundary of the Level achieved (one scale per\n' ...
    '  record: the upper side of a two-sided bound is also divided by the lower bound). Table VI Category A: CO/GA use the\n' ...
    '  "A (CO and GA)" row only (extract interpretation), other Category A phases the "A" row; 3.3.1.4 also prohibits the\n' ...
    '  coupled roll-spiral mode in the other Category A phases (conservative reading).\n']);
fprintf('\n  Criteria NOT assessed (coverage table)\n');
fprintf('  %-16s %-12s %-50s %s\n', 'class', 'paragraph', 'metric', 'reason');
for c = cov(:).'
    r = char(c.reason); if numel(r) > 110, r = [r(1:107) '...']; end
    fprintf('  %-16s %-12s %-50s %s\n', c.class, c.paragraph, c.metric, r);
end
fprintf('\n  report: %s\n          %s\n', out.files.json, out.files.md);
if ~isempty(kept)
    fprintf('  (an existing report %s.* was kept; this run was written under a timestamped name. Use ''Overwrite'', true to replace it.)\n', kept);
end
end

function s = lvlStr(g)
if isnan(g.worstLevel)
    s = '-';
elseif isempty(g.levelText)
    s = sprintf('L%d', g.worstLevel);
else
    s = g.levelText;
end
end

function s = scaleStr(a)
f = fieldnames(a);
if isempty(f), s = 'none (baseline)'; return; end
s = strjoin(cellfun(@(n) sprintf('%s x %g', n, a.(n)), f.', 'UniformOutput', false), ', ');
end

function s = num(v)
if isempty(v) || isnan(v), s = '-'; elseif isinf(v), s = sprintf('%g', v); else, s = sprintf('%.3f', v); end
end

function s = condStr(c, ax)
if isempty(fieldnames(c)), s = '-'; return; end
p = {};
for k = 1:numel(ax)
    if isfield(c, ax{k}), p{end+1} = sprintf('%s=%g', ax{k}, c.(ax{k})); end %#ok<AGROW>
end
s = strjoin(p, ' ');
end

function s = exStr(e)
if isempty(e), s = '0'; return; end
s = strjoin(arrayfun(@(x) sprintf('%s x%d', x.reason, x.count), e, 'UniformOutput', false), '; ');
end
