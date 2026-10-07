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
%   dashed grey; body axes solid. Every 3-D plot uses North, East, UP so the
%   pictures look the right way up (z down is plotted as -Up).
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
    fprintf('figures saved to %s\n', o.SaveDir);
end
if nargout == 0, clear R; end
end

function d = ifPlot(on, d)
if ~on, d = ''; end
end
