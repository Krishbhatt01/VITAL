%RUN_F16_AXES_EXAMPLE  A HYPOTHETICAL, detailed F-16 axis tree with loads, to visualise
%   how vital.Axis and vital.Loads are meant to be used on a real aircraft.
%
%   Run:  run_f16_axes_example     (a SCRIPT; prints tables, draws one figure and saves
%                                   it to reports/examples/f16_axes_example.png)
%
%   NOT THE NESC MODEL. The NESC F-16 has only bfrp/mrc/cg/engine axes and lumped
%   aero + thrust. The positions and loads below are ROUND, ILLUSTRATIVE numbers
%   chosen to look like an F-16 (length ~15 m, span 9.45 m with AIM-9s, c-bar 3.45 m,
%   W = 91.2 kN); they are not from a source and are not trimmed.
%
%   Body axes everywhere unless stated: x forward, y right, z down (metres).
%   The root 'bfrp' sits at the NESC moment reference centre (35 % MAC).
%
%   Part A  the axis tree (where everything is and how it is rotated)
%   Part B  in flight: each component's load in ITS OWN axis -> summed at the CG
%   Part C  parked on the ground: weight + 3 gear reactions = exactly zero at the CG
%   Part D  one picture of all of it

root = fileparts(mfilename('fullpath'));
addpath(root);
d = @deg2rad;

%% Part A: the axis tree --------------------------------------------------------------
bfrp = vital.Axis.root('bfrp');                                 % 35 % MAC, the datum

% reference points
cg    = vital.Axis([0.345 0 0], eye(3), bfrp, 'Name', 'cg');    % 25 % MAC: 0.10 c-bar ahead
stn   = vital.Axis.station([8.6 0 0], bfrp, 'Name', 'station'); % drawing frame: x aft, z up,
                                                                % nose tip = station 0
% crew and sensors
pilot = vital.Axis([5.4 0 -1.1], eye(3), bfrp, 'Name', 'pilot_eye');
adb   = vital.Axis([8.9 0 0.1], eye(3), bfrp, 'Name', 'nose_boom');      % air-data probe
imu   = vital.Axis([1.5 0 0.2], d([0 0.5 0]), bfrp, 'Name', 'imu');      % mounted 0.5 deg nose-up

% lifting surfaces (one axis per panel, at its aerodynamic centre)
wingL = vital.Axis([0.2 -2.4 0.05], eye(3), bfrp, 'Name', 'wing_L');
wingR = vital.Axis([0.2  2.4 0.05], eye(3), bfrp, 'Name', 'wing_R');
flpL  = vital.Axis([-1.3 -2.8 0.05], d([0 5 0]), bfrp, 'Name', 'flaperon_L');  % TE down 5 deg
flpR  = vital.Axis([-1.3  2.8 0.05], d([0 5 0]), bfrp, 'Name', 'flaperon_R');
de = -2;                                                        % stabilator, deg (TE up < 0)
htL   = vital.Axis([-4.9 -2.0 0.15], d([-10 de 0]), bfrp, 'Name', 'htail_L');  % 10 deg anhedral
htR   = vital.Axis([-4.9  2.0 0.15], d([ 10 de 0]), bfrp, 'Name', 'htail_R');
vt    = vital.Axis([-4.6 0 -2.0], eye(3), bfrp, 'Name', 'vtail');
rud   = vital.Axis([-1.0 0 0], d([0 0 0]), vt, 'Name', 'rudder');   % CHILD of vtail: hinge
                                                                    % 1 m aft of it; dr = 0 (psi)

% propulsion
inlet  = vital.Axis([3.0 0 0.9], eye(3), bfrp, 'Name', 'inlet');
nozzle = vital.Axis([-6.0 0 0.1], eye(3), bfrp, 'Name', 'nozzle');   % F100 thrust line

% stores
tank  = vital.Axis([0.6 0 1.1], eye(3), bfrp, 'Name', 'tank_C');      % centreline tank
aimL  = vital.Axis([-0.8 -4.75 0], eye(3), bfrp, 'Name', 'aim9_L');   % wingtip missiles
aimR  = vital.Axis([-0.8  4.75 0], eye(3), bfrp, 'Name', 'aim9_R');

% landing gear (contact points, gear down)
gN    = vital.Axis([ 3.9  0   1.70], eye(3), bfrp, 'Name', 'gear_nose');
gL    = vital.Axis([-0.3 -1.2 1.75], eye(3), bfrp, 'Name', 'gear_L');
gR    = vital.Axis([-0.3  1.2 1.75], eye(3), bfrp, 'Name', 'gear_R');

% flight-condition axes (state dependent: built per evaluation, never stored)
alpha = d(2.65); beta = 0;                                      % ~ the NESC case-11 trim
wind  = vital.Axis.wind(alpha, beta, cg, 'Name', 'wind');       % x along the airspeed
stab  = vital.Axis.stability(alpha, cg, 'Name', 'stability');

axesAll = {cg, stn, pilot, adb, imu, wingL, wingR, flpL, flpR, htL, htR, vt, rud, ...
    inlet, nozzle, tank, aimL, aimR, gN, gL, gR, wind, stab};

fprintf('\nPart A: axis tree (origin in bfrp, m; orientation vs bfrp as 3-2-1 Euler, deg)\n');
fprintf('  %-12s %8s %8s %8s   %7s %7s %7s\n', 'axis', 'x', 'y', 'z', 'phi', 'theta', 'psi');
for k = 1:numel(axesAll)
    a = axesAll{k};
    [C, r] = a.poseIn(bfrp);           % C = C_bfrp,a: maps a's components to bfrp's
    e = rad2deg(vital.frames.dcm2eul(C.'));   % C.' = C_a,bfrp: the orientation as constructed
    fprintf('  %-12s %8.3f %8.3f %8.3f   %7.2f %7.2f %7.2f\n', a.Name, r, e);
end

%% Part B: in flight, each load in its own axis -> total at the CG --------------------
% Illustrative numbers (N, N m). A surface's force is written in ITS axis, so the
% anhedral and stabilator deflection are applied by the class, not by hand.
loads = {
    vital.Loads([-1500; 0; -40000], [0; -6000; 0], wingL),   'wing_L: drag + lift, own pitching moment'
    vital.Loads([-1500; 0; -40000], [0; -6000; 0], wingR),   'wing_R'
    vital.Loads([ -150; 0;  -1500], [0; 0; 0], flpL),        'flaperon_L: extra lift from 5 deg TE down'
    vital.Loads([ -150; 0;  -1500], [0; 0; 0], flpR),        'flaperon_R'
    vital.Loads([ -200; 0;   1200], [0; 0; 0], htL),         'htail_L: down-load (+z in its own axis)'
    vital.Loads([ -200; 0;   1200], [0; 0; 0], htR),         'htail_R'
    vital.Loads([ -300; 0;      0], [0; 0; 0], vt),          'vtail: drag only (beta = 0)'
    vital.Loads([-3500; 0;  -9000], [0; 25000; 0], bfrp),    'fuselage: body lift + nose-up moment'
    vital.Loads([14000; 0;      0], [0; 0; 0], nozzle),      'thrust along the nozzle x'
    vital.Loads([ -900; 0;      0], [0; 0; 0], inlet),       'inlet ram drag'
    vital.Loads([ -600; 0;      0], [0; 0; 0], tank),        'tank drag'
    vital.Loads([ -250; 0;   -300], [0; 0; 0], aimL),        'aim9_L drag + lift'
    vital.Loads([ -250; 0;   -300], [0; 0; 0], aimR),        'aim9_R'
    };
mass = 9298.6;  g = 9.80665;  W = mass * g;
theta = alpha;                                                   % level flight: theta = alpha
weight = vital.Loads(W * [-sin(theta); 0; cos(theta)], [0; 0; 0], cg);  % gravity, at the CG

fprintf('\nPart B: in flight (illustrative, NOT trimmed). Each load moved to the CG:\n');
fprintf('  %-12s %9s %9s %9s | %10s %10s %10s   %s\n', 'from', 'Fx', 'Fy', 'Fz', 'L', 'M', 'N', 'what');
for k = 1:size(loads, 1)
    Lc = loads{k, 1}.transform(cg);
    fprintf('  %-12s %9.0f %9.0f %9.0f | %10.0f %10.0f %10.0f   %s\n', loads{k, 1}.RefAxis.Name, Lc.F, Lc.M, loads{k, 2});
end
Lw = weight;
fprintf('  %-12s %9.0f %9.0f %9.0f | %10.0f %10.0f %10.0f   %s\n', 'cg', Lw.F, Lw.M, 'weight (body axes)');
total = vital.Loads.aggregate([loads(:, 1); {weight}], cg);
fprintf('  %-12s %9.0f %9.0f %9.0f | %10.0f %10.0f %10.0f\n', 'TOTAL @cg', total.F, total.M);
aero = vital.Loads.aggregate(loads(:, 1), wind);                % aero + thrust, no weight
fprintf('  aero + thrust in wind axes: Fx %.0f N (thrust - drag), side %.0f N, lift %.0f N (= -Fz_wind)\n', ...
    aero.F(1), aero.F(2), -aero.F(3));
fprintf('  Not zero, because these are made-up numbers. vital.trim.solve finds the alpha,\n');
fprintf('  elevator and throttle that make exactly this total zero (Fx, Fz and M).\n');

%% Part C: parked, weight + gear reactions balance exactly ----------------------------
xc = cg.originIn(bfrp); xn = gN.originIn(bfrp); xm = gL.originIn(bfrp);
% vertical reactions (up = -z): Nn + 2 Nm = W and Nn (xn - xcg) + 2 Nm (xm - xcg) = 0
A = [1 2; xn(1) - xc(1), 2 * (xm(1) - xc(1))];
N = A \ [W; 0];
ground = {vital.Loads([0; 0; -N(1)], [0; 0; 0], gN), vital.Loads([0; 0; -N(2)], [0; 0; 0], gL), ...
    vital.Loads([0; 0; -N(2)], [0; 0; 0], gR), vital.Loads([0; 0; W], [0; 0; 0], cg)};
tg = vital.Loads.aggregate(ground, cg);
fprintf('\nPart C: parked. Nose gear %.0f N (%.1f %%), each main %.0f N (%.1f %%).\n', ...
    N(1), 100 * N(1) / W, N(2), 100 * N(2) / W);
fprintf('  total at the CG: F = [%.2e %.2e %.2e] N, M = [%.2e %.2e %.2e] N m  (zero: in equilibrium)\n', tg.F, tg.M);

%% Part D: the picture ----------------------------------------------------------------
Mp = vital.viz.displayMap();                  % (fwd, right, down) -> plot (x right, y fwd, z up)
P = @(v) Mp * v(:);
fig = figure('Name', 'Hypothetical F-16 axis tree and loads', 'Position', [60 60 1300 850], 'Color', 'w');
ax = axes(fig); hold(ax, 'on'); axis(ax, 'equal'); grid(ax, 'on'); view(ax, -135, 22);
xlabel(ax, 'right wing (m)'); ylabel(ax, 'nose (m)'); zlabel(ax, 'up (m)');
title(ax, {'HYPOTHETICAL F-16: every axis (x red, y green, z blue) and every load (black arrows, 1 m = 10 kN)', ...
    'Wing, tails and fuselage outline are sketches; loads are illustrative and not trimmed'});
% outline sketch
fus = [8.6 0 0.2; 6 0 -0.6; 4 0 -0.9; -4 0 -0.6; -6.4 0 0.1; -4 0 0.9; 3 0 1.0; 8.6 0 0.2];
Q = Mp * fus.'; plot3(ax, Q(1, :), Q(2, :), Q(3, :), 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
wing = [3.2 0 0; -0.9 -4.7 0; -2.3 -4.7 0; -2.6 0 0; -2.3 4.7 0; -0.9 4.7 0; 3.2 0 0];
Q = Mp * wing.'; fill3(ax, Q(1, :), Q(2, :), Q(3, :), [0.85 0.88 0.95], 'FaceAlpha', 0.35, 'EdgeColor', [0.5 0.5 0.6]);
ht = [-4.0 0 0.15; -5.6 -2.9 0.66; -6.3 -2.9 0.66; -6.3 0 0.15; -6.3 2.9 0.66; -5.6 2.9 0.66; -4.0 0 0.15];
Q = Mp * ht.'; fill3(ax, Q(1, :), Q(2, :), Q(3, :), [0.85 0.88 0.95], 'FaceAlpha', 0.35, 'EdgeColor', [0.5 0.5 0.6]);
vtl = [-3.4 0 -0.6; -5.4 0 -3.6; -6.3 0 -3.6; -6.0 0 -0.6; -3.4 0 -0.6];
Q = Mp * vtl.'; fill3(ax, Q(1, :), Q(2, :), Q(3, :), [0.85 0.88 0.95], 'FaceAlpha', 0.35, 'EdgeColor', [0.5 0.5 0.6]);
% axes
for k = 1:numel(axesAll)
    a = axesAll{k};
    len = 0.7; if any(strcmp(a.Name, {'wind', 'stability', 'station'})), len = 1.6; end
    a.triad(ax, 'Length', len);
end
bfrp.triad(ax, 'Length', 1.2);
% loads: force arrows at each reference point, drawn in bfrp components
s = 1 / 10000;
for k = 1:size(loads, 1)
    L = loads{k, 1};
    o = L.RefAxis.originIn(bfrp);
    Fr = L.RefAxis.dcmTo(bfrp) * L.F;          % force rotated into bfrp components
    o2 = P(o); f2 = P(Fr * s);
    quiver3(ax, o2(1), o2(2), o2(3), f2(1), f2(2), f2(3), 0, 'k', 'LineWidth', 1.6, 'MaxHeadSize', 0.6);
end
o2 = P(cg.originIn(bfrp)); f2 = P(weight.F * s);
quiver3(ax, o2(1), o2(2), o2(3), f2(1), f2(2), f2(3), 0, 'Color', [0.8 0.3 0], 'LineWidth', 2.2);
text(ax, o2(1) + 0.3, o2(2), o2(3) - 4.5, 'weight 91 kN', 'Color', [0.8 0.3 0]);
set(findobj(ax, 'Type', 'text'), 'Interpreter', 'none', 'FontSize', 8);   % names with '_'
outDir = fullfile(root, 'reports', 'examples');
if ~isfolder(outDir), mkdir(outDir); end
exportgraphics(fig, fullfile(outDir, 'f16_axes_example.png'), 'Resolution', 130);
fprintf('\nFigure saved: %s\n', fullfile(outDir, 'f16_axes_example.png'));
