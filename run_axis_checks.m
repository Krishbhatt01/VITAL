function R = run_axis_checks(varargin)
%RUN_AXIS_CHECKS  Visual axis checks: vector plots of VITAL's frames, rotations,
%   translations and CG bookkeeping, each with numeric checks against an
%   independent reference (the entry point for users).
%
%   run_axis_checks                         draw all 13 cases and print the verdicts;
%                                           PNGs go to <VITAL>\reports\axis_checks
%   run_axis_checks('Cases', {'pitch','cg'})  only some cases (ids below)
%   run_axis_checks('Plot', false)          numbers only
%   run_axis_checks('SaveDir', d)           save PNGs somewhere else ('' = do not save)
%   R = run_axis_checks(...)                returns the cases and their checks
%
%   Case ids: yaw, pitch, roll, combined, level, climb, sideslip, gravity, cg,
%   station, control, path, earth. See vital.viz.axisChecks for what each
%   one shows and checks. Colours: x red, y green, z blue; NED (ground) axes
%   dashed grey; body axes solid. Every 3-D plot uses one RIGHT-HANDED display
%   map (vital.viz.displayMap): plot x = East / right wing, y = North / nose,
%   z = Up, so East is drawn to the right of North (never a mirror image).
%   Each figure carries a "what this shows" panel and a plain-language meaning
%   under every numeric check (vital.viz.axisNotes). With plotting and a
%   SaveDir, README.md with the same explanations is written beside the PNGs.
%   Works from any MATLAB session: it puts VITAL on the path itself.
addpath(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('Cases', {});
p.addParameter('Plot', true);
p.addParameter('Visible', true);
p.addParameter('SaveDir', fullfile(fileparts(mfilename('fullpath')), 'reports', 'axis_checks'));
p.parse(varargin{:});
o = p.Results;
R = vital.viz.axisChecks('Cases', o.Cases, 'Plot', o.Plot, 'Visible', o.Visible, ...
    'SaveDir', ifPlot(o.Plot, o.SaveDir));
fprintf('VITAL axis checks (%d cases)\n', numel(R.cases));
for c = R.cases(:)'
    nOk = sum([c.checks.pass]);
    if all([c.checks.pass]), v = 'PASS'; else, v = 'FAIL'; end
    fprintf('  %-4s %-9s %2d/%-2d checks  %s\n', v, c.id, nOk, numel(c.checks), c.title);
    for i = find(~[c.checks.pass])          % find(): a loop over an empty 0x1 array would run once
        ch = c.checks(i);
        fprintf('         failed: %s (error %.3g > tol %.3g)\n', ch.what, ch.error, ch.tol);
    end
end
if R.allPass
    fprintf('ALL AXIS CHECKS PASS\n');
else
    fprintf('SOME AXIS CHECKS FAIL\n');
end
if o.Plot && ~isempty(o.SaveDir)
    writeReadme(R, o.SaveDir);
    fprintf('figures and README.md saved to %s\n', o.SaveDir);
end
if nargout == 0, clear R; end
end

function d = ifPlot(on, d)
if ~on, d = ''; end
end

function writeReadme(R, d)
% README.md beside the PNGs: every case's explanation and every check's meaning
L = {'# VITAL visual axis checks', '', ...
    'Written by `run_axis_checks`. Every plotted vector is computed by VITAL''s own functions; every numeric check compares it with a value built a different way: a hand-written formula (ANALYTIC) or MATLAB''s Aerospace Toolbox (INDEP).', '', ...
    '3-D plots use one right-handed display map: plot x = East / right wing, plot y = North / nose, plot z = Up. Colours: x red, y green, z blue; ground axes dashed grey; body axes solid.', ''};
ids = {R.cases.id};
for k = 1:numel(R.cases)
    c = R.cases(k);
    if all([c.checks.pass]), v = 'PASS'; else, v = 'FAIL'; end
    png = dir(fullfile(d, sprintf('*_%s.png', c.id)));
    L{end+1} = sprintf('## %d. %s  (`%s`, %s)', k, c.title, c.id, v); %#ok<AGROW>
    if ~isempty(png), L{end+1} = sprintf('![%s](%s)', c.id, png(1).name); end %#ok<AGROW>
    L = [L, {'', ['**What this shows and why it matters.** ' c.explain], '', ...
        '| result | check | what it means | reference |', '|---|---|---|---|'}]; %#ok<AGROW>
    for j = 1:numel(c.checks)
        ch = c.checks(j);
        if ch.pass, r = 'PASS'; else, r = 'FAIL'; end
        L{end+1} = sprintf('| %s | %s | %s | %s |', r, strrep(ch.what, '|', '/'), ch.meaning, ch.ref); %#ok<AGROW>
    end
    L{end+1} = ''; %#ok<AGROW>
end
L{end+1} = sprintf('Cases: %s.', strjoin(ids, ', '));
fid = fopen(fullfile(d, 'README.md'), 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end
