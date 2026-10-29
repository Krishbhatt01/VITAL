function [sl, files] = plotTrim6dof(log, P)
%PLOTTRIM6DOF  The result figures of models/F16Trim6DOF.slx, from ITS OWN logged data.
%   sl = vital.slx.plotTrim6dof(sim6dof)             unpack the log only
%   [sl, files] = vital.slx.plotTrim6dof(sim6dof, P6dof)   unpack, draw, save PNGs
%   sim6dof is what the model's To Workspace block 'sim6dof' writes (Structure With
%   Time): every number drawn here is a Simulink signal (6DOF block, Aerospace
%   Blockset air-data blocks, the loads block). No VITAL simulation is run. The
%   model's StopFcn calls this when you press Run; run_f16_trim_6dof calls it too.
%   sl fields (1 x N, SI and rad): t V alpha beta mach qbar h hdot phi theta psi p q r
%   xN xE de da dr throttle, F (3 x N, net force at the CG, body axes, N),
%   M (3 x N, net moment about the CG, N m).
%   P (vital.slx.trim6dofSetup) gives the trim values (P.tr, P.V, P.h), m, g, cbar and
%   P.plotDir (where 1_trim_hold_states.png, 2_trim_hold_deviation_log.png and
%   3_trim_hold_net_loads.png are written).
v = log.signals.values;
if ndims(v) == 3, v = reshape(v, [], size(v, 3)).'; end
names = {'V', 'alpha', 'beta', 'mach', 'qbar', 'h', 'hdot', 'phi', 'theta', 'psi', 'p', 'q', 'r', ...
    'xN', 'xE', 'de', 'da', 'dr', 'throttle'};
sl.t = log.time(:).';
for k = 1:numel(names)
    sl.(names{k}) = v(:, k).';
end
sl.F = v(:, 20:22).';
sl.M = v(:, 23:25).';
files = {};
if nargin < 2, return; end
if ~isfolder(P.plotDir), mkdir(P.plotDir); end
files{end+1} = plotStates(sl, P);
files{end+1} = plotDeviation(sl, P);
files{end+1} = plotLoads(sl, P);
end

function f = plotStates(s, P)
ft = 0.3048; tr = P.tr; t = s.t;
fig = figure('Name', 'F16Trim6DOF: states (Simulink result)', 'Position', [50 50 1400 820]);
tl = tiledlayout(fig, 3, 4, 'TileSpacing', 'compact');
title(tl, {sprintf('Simulink F16Trim6DOF result: NASA F-16 trimmed, %g s, h %.0f ft, V %.2f ft/s, Mach %.3f', ...
    t(end), P.h / ft, P.V / ft, P.Mach), 'Y-axes: trim value \pm a fixed band, so a flat line is really flat'});
S = {
    'True airspeed V', s.V / ft, P.V / ft, 1, 'ft/s'
    'Angle of attack \alpha', rad2deg(s.alpha), rad2deg(tr.alpha), 0.5, 'deg'
    'Sideslip \beta', rad2deg(s.beta), 0, 0.5, 'deg'
    'Altitude h', s.h / ft, P.h / ft, 10, 'ft'
    'Climb rate dh/dt', s.hdot / ft, 0, 1, 'ft/s'
    'Pitch \theta', rad2deg(s.theta), rad2deg(tr.theta), 0.5, 'deg'
    'Roll \phi', rad2deg(s.phi), 0, 0.5, 'deg'
    'Heading \psi', rad2deg(s.psi), rad2deg(P.eul0(3)), 0.5, 'deg'
    'Pitch rate q', rad2deg(s.q), 0, 0.5, 'deg/s'
    'Roll p and yaw r rate', rad2deg([s.p; s.r]), 0, 0.5, 'deg/s'};
for i = 1:size(S, 1)
    ax = nexttile(tl);
    plot(ax, t, S{i, 2}, 'LineWidth', 1.6); hold(ax, 'on');
    yline(ax, S{i, 3}, ':', 'trim', 'Color', [0.4 0.4 0.4]);
    ylim(ax, S{i, 3} + [-1 1] * S{i, 4}); grid(ax, 'on');
    title(ax, S{i, 1}); ylabel(ax, S{i, 5}); xlabel(ax, 't (s)');
end
ax = nexttile(tl);
plot(ax, t, s.xN / ft, t, s.xE / ft, 'LineWidth', 1.6); grid(ax, 'on');
legend(ax, 'north', 'east', 'Location', 'northwest');
title(ax, 'Position: x = V t along the heading'); ylabel(ax, 'ft'); xlabel(ax, 't (s)');
ax = nexttile(tl);
yyaxis(ax, 'left'); plot(ax, t, rad2deg(s.de), 'LineWidth', 1.6); ylabel(ax, 'elevator (deg)');
ylim(ax, rad2deg(tr.u(1)) + [-1 1]);
yyaxis(ax, 'right'); plot(ax, t, 100 * s.throttle, 'LineWidth', 1.6); ylabel(ax, 'throttle (%)');
ylim(ax, 100 * tr.u(4) + [-5 5]); grid(ax, 'on');
title(ax, 'Controls held at u-bar'); xlabel(ax, 't (s)');
f = saveFig(fig, P.plotDir, '1_trim_hold_states.png');
end

function f = plotDeviation(s, P)
ft = 0.3048; tr = P.tr; t = s.t;
fig = figure('Name', 'F16Trim6DOF: change from trim (Simulink result)', 'Position', [80 80 1000 520]);
D = {abs(s.V - P.V) / ft, 'V (ft/s)'; rad2deg(abs(s.alpha - tr.alpha)), '\alpha (deg)';
    rad2deg(abs(s.theta - tr.theta)), '\theta (deg)'; abs(s.h - P.h) / ft, 'h (ft)';
    abs(s.hdot) / ft, 'dh/dt (ft/s)'; rad2deg(abs(s.q)), 'q (deg/s)';
    rad2deg(abs([s.beta; s.phi; s.p; s.r])), '\beta, \phi (deg), p, r (deg/s)'};
ax = axes(fig); hold(ax, 'on');
for i = 1:size(D, 1)
    semilogy(ax, t, max(max(D{i, 1}, [], 1), 1e-18), 'LineWidth', 1.4, 'DisplayName', D{i, 2});
end
set(ax, 'YScale', 'log'); grid(ax, 'on'); ylim(ax, [1e-18 1]);
yline(ax, 1e-12, '--', 'double-precision round-off for these magnitudes', 'HandleVisibility', 'off');
legend(ax, 'Location', 'eastoutside'); xlabel(ax, 't (s)'); ylabel(ax, '|value - trim value|');
title(ax, 'How flat is flat? Simulink result minus the trim value (log scale; exact zero drawn at 1e-18)');
f = saveFig(fig, P.plotDir, '2_trim_hold_deviation_log.png');
end

function f = plotLoads(s, P)
W = P.m * P.g; t = s.t;
fig = figure('Name', 'F16Trim6DOF: net load at the CG (Simulink result)', 'Position', [110 110 1000 420]);
tl = tiledlayout(fig, 1, 2);
title(tl, 'Net load the 6DOF block receives = aero + thrust + weight: zero at a trim');
ax = nexttile(tl); plot(ax, t, s.F / W, 'LineWidth', 1.4); grid(ax, 'on');
legend(ax, 'F_x', 'F_y', 'F_z'); ylabel(ax, 'force / weight'); xlabel(ax, 't (s)'); ylim(ax, [-1 1] * 1e-3);
title(ax, 'Net force / weight (y-axis \pm 0.001)');
ax = nexttile(tl); plot(ax, t, s.M / (W * P.cbar), 'LineWidth', 1.4); grid(ax, 'on');
legend(ax, 'L', 'M', 'N'); ylabel(ax, 'moment / (weight c-bar)'); xlabel(ax, 't (s)'); ylim(ax, [-1 1] * 1e-3);
title(ax, 'Net moment about the CG / (weight c-bar)');
f = saveFig(fig, P.plotDir, '3_trim_hold_net_loads.png');
end

function f = saveFig(fig, dir, name)
f = fullfile(dir, name);
exportgraphics(fig, f, 'Resolution', 130);
end
