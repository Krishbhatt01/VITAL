function res = run_f16_simulink(opts)
%RUN_F16_SIMULINK  M9-A entry point: the F-16 through the generated Simulink model
%   VitalPlant, compared with vital.sim.run (docs/PLAN_M9.md section 4).
%
%   res = run_f16_simulink()
%   res = run_f16_simulink('tFinal', 10, 'dt', 0.01, 'Plot', true, 'SaveDir', d)
%
%   Trims level at the NESC README point (565.6854 ft/s, 10013 ft, CG 25 % MAC),
%   builds models/VitalPlant.slx if it is missing, then runs the Simulink path and
%   vital.sim.run with the M7 SAS (pitch SAS Kq 0.02 s, Ka 0.14; yaw damper Kr 0.82 s;
%   100 Hz) and a 1 deg elevator doublet at t = 1 s (0.5 s halves). Prints the
%   largest differences and, with 'Plot', overlays alpha, q, theta and r (saved as
%   PNG in SaveDir when given).
%   res fields: slx, mat (the two outputs), cmp (vital.slx.compare), trim, file.
arguments
    opts.tFinal (1,1) double = 5
    opts.dt (1,1) double = 0.01
    opts.Plot (1,1) logical = true
    opts.SaveDir (1,:) char = ''
end
addpath(fileparts(mfilename('fullpath')));
ft = 0.3048;
AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
cond = struct('type', 'level', 'V', 565.6854 * ft, 'h', 10013 * ft, 'gamma', 0, 'psi', 0);
tr = vital.trim.solve(AC, env, cond);
if ~strcmp(tr.status, 'OK')
    error('vital:trim:notOk', 'README trim is %s; nothing simulated.', tr.status);
end
file = vital.slx.modelFile();
if ~isfile(file)
    fprintf('building %s\n', file);
    vital.slx.build();
end
c = vital.ctrl.combine(vital.ctrl.pitchSas(AC, env, tr, 'Kq', 0.02, 'Ka', 0.14, 'Rate', 100), ...
    vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.82, 'Rate', 100));
args = {'dt', opts.dt, 'tFinal', opts.tFinal, 'Controller', c, ...
    'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator')};
res.slx = vital.slx.simulate(AC, env, tr.x, tr.u, args{:});
res.mat = vital.sim.run(AC, env, tr.x, tr.u, args{:});
res.trim = tr;
res.file = file;
fprintf('Simulink (%s): %s in %.1f s;  vital.sim.run: %s in %.1f s\n', file, res.slx.status, ...
    res.slx.wallTime_s, res.mat.status, res.mat.wallTime_s);
if isequal(size(res.slx.x), size(res.mat.x))
    res.cmp = vital.slx.compare(res.slx, res.mat);
    fprintf('max scaled state difference E = %.3g (PLAN_M9 tolerance 1e-9); max |dt| %.3g s; max |du| %.3g\n', ...
        res.cmp.E, res.cmp.tErr, res.cmp.uErr);
else
    res.cmp = struct('e', NaN(13, 1), 'E', NaN, 'tErr', NaN, 'uErr', NaN, 'n', NaN);
    fprintf('max scaled state difference: logs differ in length (%d vs %d samples)\n', ...
        numel(res.slx.t), numel(res.mat.t));
end
if opts.Plot
    f = figure('Name', 'VITAL M9: Simulink vs vital.sim.run');
    tl = tiledlayout(f, 2, 2);
    title(tl, 'F-16 README trim, M7 SAS, 1 deg elevator doublet');
    sig = {'alpha', 'q', 'theta', 'r'};
    for i = 1:4
        ax = nexttile(tl);
        plot(ax, res.mat.t, rad2deg(res.mat.y.(sig{i})), '-', res.slx.t, rad2deg(res.slx.y.(sig{i})), '--');
        grid(ax, 'on'); xlabel(ax, 't (s)'); ylabel(ax, [sig{i} ' (deg or deg/s)']);
        legend(ax, {'vital.sim.run', 'Simulink VitalPlant'}, 'Location', 'best');
    end
    if ~isempty(opts.SaveDir)
        if ~isfolder(opts.SaveDir), mkdir(opts.SaveDir); end
        exportgraphics(f, fullfile(opts.SaveDir, 'f16_simulink_vs_matlab.png'));
    end
end
end
