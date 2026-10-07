function R = axisChecks(opts)
%AXISCHECKS  Visual axis checks: vector plots of VITAL's frames, rotations,
%   translations and CG bookkeeping, each with numeric checks against an
%   INDEPENDENT reference (docs/CONVENTIONS.md sections 2-7).
%   R = vital.viz.axisChecks('Plot', true, 'Visible', true, 'SaveDir', d, 'Cases', {...})
%
%   Every plotted vector is produced by VITAL's own functions. Every check
%   compares it with a value built a different way: a hand-written closed form
%   in this file (ANALYTIC) or the MATLAB Aerospace Toolbox (INDEP). A check
%   never compares a function with itself.
%
%   Cases (id: what it shows)
%     yaw       yaw 30 deg: nose turns from North towards East, z stays Down
%     pitch     pitch 20 deg nose-up: nose rises, belly axis tilts aft
%     roll      roll 40 deg: right wing goes DOWN (positive bank)
%     combined  yaw 30, pitch 20, roll 40 applied in the 3-2-1 order, with the
%               intermediate frames; DCM, quaternion and Euler routes agree
%     level     F-16 README trim: body velocity turned into NED is horizontal;
%               alpha = atan2(w, u) = pitch angle
%     climb     F-16 trim in a 5 deg climb: NED velocity climbs at 5 deg;
%               pitch = alpha + gamma
%     sideslip  body velocity with alpha 5, beta 10 deg; a 10 m/s headwind adds
%               10 m/s of airspeed
%     gravity   gravity (always NED Down) seen in body axes at three attitudes
%     cg        F-16 side view in BFRP axes: MRC (35 % MAC), CG at 25 and 30 %,
%               the lift arrow and the moment it makes about the CG; moving the
%               BFRP origin changes no physics
%     station   NASA station coordinates (x aft, z up) turned into body axes
%     control   moment vectors from +1 deg elevator, aileron, rudder at trim:
%               each is negative about its own axis (CONVENTIONS 7)
%     path      simulated 2 deg aileron step: flight path with body axes drawn
%               along it; the path follows C_bn' v_b and the aircraft rolls left
%     earth     local NED axes on the WGS-84 Earth at 36 N, 75 W: Down along the
%               geodetic normal, North towards the pole
%
%   R.cases(k): id, title, checks (struct array from vital.viz.checkItem),
%   figure (handle, or [] without plotting). R.allPass.
%   Colours: x red, y green, z blue. Ground NED axes dashed grey. 3-D plots use
%   North, East, UP axes (NED z down is drawn as -Up) so pictures read naturally.
arguments
    opts.Cases = {}
    opts.Plot (1,1) logical = false
    opts.Visible (1,1) logical = true
    opts.SaveDir (1,:) char = ''
end
catalog = {'yaw', @caseYaw; 'pitch', @casePitch; 'roll', @caseRoll; 'combined', @caseCombined; ...
       'level', @caseLevel; 'climb', @caseClimb; 'sideslip', @caseSideslip; 'gravity', @caseGravity; ...
       'cg', @caseCg; 'station', @caseStation; 'control', @caseControl; 'path', @casePath; 'earth', @caseEarth};
sel = true(size(catalog, 1), 1);
if ~isempty(opts.Cases)
    want = cellstr(opts.Cases);
    bad = setdiff(want, catalog(:, 1));
    if ~isempty(bad), error('vital:badInput', 'unknown case(s): %s', strjoin(bad, ', ')); end
    sel = ismember(catalog(:, 1), want);
end
if ~isempty(opts.SaveDir) && ~isfolder(opts.SaveDir), mkdir(opts.SaveDir); end
cases = struct('id', {}, 'title', {}, 'checks', {}, 'figure', {});
for k = find(sel).'
    [title_, checks, draw] = catalog{k, 2}();
    fig = [];
    if opts.Plot
        fig = figure('Visible', onoff(opts.Visible), 'Color', 'w', 'Position', [100 100 1150 620], ...
            'Name', ['VITAL axis check: ' catalog{k, 1}]);
        ax = axes(fig, 'Position', [0.05 0.08 0.55 0.82]);
        hold(ax, 'on'); grid(ax, 'on');
        draw(ax);
        ok = all_([checks.pass]);
        if ok, verdict = 'PASS'; col = [0 0.5 0]; else, verdict = 'FAIL'; col = [0.8 0 0]; end
        title(ax, sprintf('%s   [%s]', title_, verdict), 'Color', col, 'FontSize', 12, 'Interpreter', 'none');
        annotation(fig, 'textbox', [0.62 0.08 0.36 0.82], 'String', checkText(checks), ...
            'FontName', 'Consolas', 'FontSize', 8, 'EdgeColor', [0.7 0.7 0.7], 'Interpreter', 'none', ...
            'VerticalAlignment', 'top');
        if ~isempty(opts.SaveDir)
            exportgraphics(fig, fullfile(opts.SaveDir, sprintf('%02d_%s.png', k, catalog{k, 1})), 'Resolution', 110);
        end
    end
    cases(end+1) = struct('id', catalog{k, 1}, 'title', title_, 'checks', checks, 'figure', fig); %#ok<AGROW>
end
R.cases = cases;
R.allPass = all_(arrayfun(@(c) all_([c.checks.pass]), cases));
end

% =========================================================================
% Cases. Each returns [title, checks, draw]; draw(ax) plots on an axes.
% =========================================================================
function [t, C, draw] = caseYaw()
t = 'Yaw 30 deg: nose turns from North to East';
psi = deg2rad(30);
Cbn = vital.frames.dcm321(0, 0, psi);
xb = Cbn' * [1; 0; 0]; zb = Cbn' * [0; 0; 1];
C = [chk('body x (nose) in NED = [cos30 sin30 0]', xb, [cosd(30); sind(30); 0], 1e-14, 'ANALYTIC')
     chk('body z stays NED Down', zb, [0; 0; 1], 1e-14, 'ANALYTIC')
     chk('C_bn = angle2dcm(psi,0,0)', Cbn, angle2dcm(psi, 0, 0, 'ZYX'), 1e-14, 'INDEP')];
draw = @(ax) drawAttitude(ax, Cbn, {'psi = 30 deg'});
end

function [t, C, draw] = casePitch()
t = 'Pitch 20 deg nose-up: nose rises above the horizon';
th = deg2rad(20);
Cbn = vital.frames.dcm321(0, th, 0);
xb = Cbn' * [1; 0; 0]; zb = Cbn' * [0; 0; 1];
C = [chk('body x in NED = [cos20 0 -sin20] (Down < 0 = up)', xb, [cosd(20); 0; -sind(20)], 1e-14, 'ANALYTIC')
     chk('body z in NED = [sin20 0 cos20] (belly tilts aft)', zb, [sind(20); 0; cosd(20)], 1e-14, 'ANALYTIC')
     chk('C_bn = angle2dcm(0,theta,0)', Cbn, angle2dcm(0, th, 0, 'ZYX'), 1e-14, 'INDEP')];
draw = @(ax) drawAttitude(ax, Cbn, {'theta = 20 deg'});
end

function [t, C, draw] = caseRoll()
t = 'Roll 40 deg: right wing goes down (positive bank)';
ph = deg2rad(40);
Cbn = vital.frames.dcm321(ph, 0, 0);
yb = Cbn' * [0; 1; 0];
C = [chk('body y (right wing) in NED = [0 cos40 sin40]', yb, [0; cosd(40); sind(40)], 1e-14, 'ANALYTIC')
     chk('right wing points down (NED Down component > 0)', yb(3) > 0, true, 0, 'ANALYTIC')
     chk('C_bn = angle2dcm(0,0,phi)', Cbn, angle2dcm(0, 0, ph, 'ZYX'), 1e-14, 'INDEP')];
draw = @(ax) drawAttitude(ax, Cbn, {'phi = 40 deg'});
end

function [t, C, draw] = caseCombined()
t = 'Yaw 30, pitch 20, roll 40 in the 3-2-1 order';
ph = deg2rad(40); th = deg2rad(20); ps = deg2rad(30);
Cbn = vital.frames.dcm321(ph, th, ps);
% hand-built elementary rotations (passive), written out independently here
Rz = [cos(ps) sin(ps) 0; -sin(ps) cos(ps) 0; 0 0 1];
Ry = [cos(th) 0 -sin(th); 0 1 0; sin(th) 0 cos(th)];
Rx = [1 0 0; 0 cos(ph) sin(ph); 0 -sin(ph) cos(ph)];
q = vital.frames.eul2quat(ph, th, ps);
e = vital.frames.dcm2eul(Cbn);
C = [chk('C_bn = Rx(phi) Ry(theta) Rz(psi), hand-built', Cbn, Rx * Ry * Rz, 1e-14, 'ANALYTIC')
     chk('C_bn = angle2dcm(psi,theta,phi,ZYX)', Cbn, angle2dcm(ps, th, ph, 'ZYX'), 1e-14, 'INDEP')
     chk('quaternion route = Aerospace Toolbox quat2dcm', vital.frames.quat2dcm(q), quat2dcm(q(:)'), 1e-14, 'INDEP')
     chk('C_bn orthonormal: C C'' = I', Cbn * Cbn', eye(3), 1e-14, 'ANALYTIC')
     chk('det C_bn = +1 (right-handed)', det(Cbn), 1, 1e-14, 'ANALYTIC')
     chk('Euler round trip [phi theta psi]', e(:), [ph; th; ps], 1e-12, 'ANALYTIC')];
draw = @(ax) drawCombined(ax, Rz, Ry * Rz, Cbn);
end

function [t, C, draw] = caseLevel()
t = 'F-16 level trim: velocity is horizontal, alpha = pitch';
r = vital.aircraft.f16.trimLevel(565.6854, 10013);
x = r.trim.x; v = x(1:3); Cbn = vital.frames.quat2dcm(x(7:10));
vn = Cbn' * v;
th = deg2rad(r.theta_deg);
C = [chk('trim status OK', strcmp(r.status, 'OK'), true, 0, 'ANALYTIC')
     chk('NED velocity has no vertical part (level)', vn(3), 0, 1e-9, 'ANALYTIC')
     chk('|v_n| = |v_b| = trim airspeed (m/s)', norm(vn), 565.6854 * 0.3048, 1e-9, 'ANALYTIC')
     chk('alpha = atan2(w, u) (deg)', rad2deg(atan2(v(3), v(1))), r.alpha_deg, 1e-9, 'ANALYTIC')
     chk('pitch = alpha in level flight (deg)', r.theta_deg, r.alpha_deg, 1e-9, 'ANALYTIC')
     chk('v_n with Aerospace Toolbox DCM', angle2dcm(0, th, 0, 'ZYX')' * v, vn, 1e-9, 'INDEP')];
draw = @(ax) drawVelocity(ax, Cbn, v, sprintf('alpha = theta = %.3f deg', r.alpha_deg));
end

function [t, C, draw] = caseClimb()
t = 'F-16 trim in a 5 deg climb: path climbs at gamma';
r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'gamma_deg', 5);
x = r.trim.x; v = x(1:3); Cbn = vital.frames.quat2dcm(x(7:10));
vn = Cbn' * v;
C = [chk('trim status OK', strcmp(r.status, 'OK'), true, 0, 'ANALYTIC')
     chk('climb angle asin(-vn_D / V) = 5 deg', rad2deg(asin(-vn(3) / norm(vn))), 5, 1e-9, 'ANALYTIC')
     chk('pitch - alpha = gamma = 5 deg', r.theta_deg - r.alpha_deg, 5, 1e-9, 'ANALYTIC')
     chk('climbing: NED Down velocity < 0', vn(3) < 0, true, 0, 'ANALYTIC')];
draw = @(ax) drawVelocity(ax, Cbn, v, sprintf('theta %.2f = alpha %.2f + gamma 5', r.theta_deg, r.alpha_deg));
end

function [t, C, draw] = caseSideslip()
t = 'Alpha 5, beta 10 deg; a 10 m/s headwind adds airspeed';
V = 200; a = deg2rad(5); b = deg2rad(10);
vb = V * [cos(a) * cos(b); sin(b); sin(a) * cos(b)];       % hand-built wind-to-body
atm = vital.env.atmosphereUS76(3000); ref = struct('b', 9.144, 'cbar', 3.45);
ad = vital.airdata.airData(vb, [0; 0; 0], eye(3), [0; 0; 0], atm, ref);
adw = vital.airdata.airData([200; 0; 0], [0; 0; 0], eye(3), [-10; 0; 0], atm, ref);   % heading North, wind blowing South
C = [chk('alpha recovered (deg)', rad2deg(ad.alpha), 5, 1e-12, 'ANALYTIC')
     chk('beta recovered (deg)', rad2deg(ad.beta), 10, 1e-12, 'ANALYTIC')
     chk('airspeed V (m/s)', ad.V, V, 1e-12, 'ANALYTIC')
     chk('headwind 10 m/s: airspeed = ground speed + 10', adw.V, 210, 1e-12, 'ANALYTIC')];
draw = @(ax) drawSideslip(ax, vb);
end

function [t, C, draw] = caseGravity()
t = 'Gravity (always NED Down) seen in body axes';
g = 9.80665;
C1 = vital.frames.dcm321(0, deg2rad(30), 0);
C2 = vital.frames.dcm321(deg2rad(60), 0, 0);
C3 = vital.frames.dcm321(deg2rad(40), deg2rad(20), deg2rad(30));
g1 = C1 * [0; 0; g]; g2 = C2 * [0; 0; g]; g3 = C3 * [0; 0; g];
C = [chk('pitch 30 up: g_b = g[-sin30 0 cos30] (pulls aft)', g1, g * [-sind(30); 0; cosd(30)], 1e-13, 'ANALYTIC')
     chk('roll 60 right: g_b = g[0 sin60 cos60] (pulls right)', g2, g * [0; sind(60); cosd(60)], 1e-13, 'ANALYTIC')
     chk('combined attitude vs Aerospace Toolbox', g3, angle2dcm(deg2rad(30), deg2rad(20), deg2rad(40), 'ZYX') * [0; 0; g], 1e-13, 'INDEP')
     chk('|g_b| = g at every attitude', [norm(g1) norm(g2) norm(g3)], [g g g], 1e-13, 'ANALYTIC')];
draw = @(ax) drawGravity(ax, {C1, C2, C3}, {'pitch 30', 'roll 60', 'yaw30 pitch20 roll40'});
end

function [t, C, draw] = caseCg()
t = 'CG and reference points (BFRP), side view';
ft = 0.3048; cbar = 11.32;
A25 = vital.aircraft.f16.config('CG_PCT_MAC', 25);
A30 = vital.aircraft.f16.config('CG_PCT_MAC', 30);
d = [3; 0.7; -1.2];
A25s = vital.aircraft.f16.config('CG_PCT_MAC', 25, 'BfrpOffset', d);
F = [0; 0; -91000];                                % about 20,500 lbf of lift (body z up = negative)
[~, M] = vital.loads.sumLoadsAtCG(F, [0; 0; 0], A25.r_cg, 0, eye(3), [0; 0; 0]);   % lift applied at the MRC (= BFRP origin)
arm = A25.r_mrc - A25.r_cg;                        % MRC relative to the CG
My_hand = arm(3) * F(1) - arm(1) * F(3);           % y-component of arm x F, written out
r = vital.aircraft.f16.trimLevel(565.6854, 10013);
env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
xd1 = vital.plant.derivatives(r.trim.x, r.trim.u, A25, env);
xd2 = vital.plant.derivatives(r.trim.x, r.trim.u, A25s, env);
C = [chk('CG 25 %: forward of MRC by 0.01 cbar (35-25) (ft)', A25.r_cg(1) / ft, 0.01 * cbar * 10, 1e-12, 'ANALYTIC')
     chk('CG 30 %: forward of MRC by 0.01 cbar (35-30) (ft)', A30.r_cg(1) / ft, 0.01 * cbar * 5, 1e-12, 'ANALYTIC')
     chk('moment about CG = (r_mrc - r_cg) x F, written out (N m)', M(2), My_hand, 1e-9, 'ANALYTIC')
     chk('lift behind the CG pitches nose DOWN (M_y < 0)', M(2) < 0, true, 0, 'ANALYTIC')
     chk('datum moved [3 0.7 -1.2] m: arm MRC-CG unchanged', A25s.r_mrc - A25s.r_cg, arm, 1e-15, 'ANALYTIC')
     chk('datum moved: aircraft accelerations unchanged', xd2, xd1, 1e-12, 'ANALYTIC')];
draw = @(ax) drawCg(ax, A25, A30, F);
end

function [t, C, draw] = caseStation()
t = 'NASA station coordinates (x aft, z up) into body axes (x forward, z down)';
datum = [100; 0; 20];                       % station coordinates of the BFRP (in)
pts = [60 0 25; 150 -40 20; 210 0 45]';     % nose probe, left wing point, fin tip (station, in)
rb = zeros(3, size(pts, 2));
for k = 1:size(pts, 2), rb(:, k) = vital.frames.stationToBody(pts(:, k), datum); end
hand = [-(pts(1, :) - datum(1)); pts(2, :) - datum(2); -(pts(3, :) - datum(3))];
C = [chk('flip x and z, keep y: hand formula', rb, hand, 1e-12, 'ANALYTIC')
     chk('point ahead of the datum has body x > 0', rb(1, 1) > 0, true, 0, 'ANALYTIC')
     chk('point above the datum has body z < 0', rb(3, 3) < 0, true, 0, 'ANALYTIC')
     chk('left wing point has body y < 0', rb(2, 2) < 0, true, 0, 'ANALYTIC')];
draw = @(ax) drawStation(ax, pts, datum, rb);
end

function [t, C, draw] = caseControl()
t = 'Control moments at trim: +1 deg gives a negative moment about its own axis';
ft = 0.3048;
AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
r = vital.aircraft.f16.trimLevel(565.6854, 10013);
x = r.trim.x; u = r.trim.u;
[~, y0] = vital.plant.derivatives(x, u, AC, env);
dM = zeros(3, 3);
for k = 1:3
    du = zeros(4, 1); du(k) = deg2rad(1);
    [~, yk] = vital.plant.derivatives(x, u + du, AC, env);
    dM(:, k) = yk.M_cg - y0.M_cg;
end
C = [chk('+elevator (TED): pitching moment < 0 (nose down)', dM(2, 1) < 0, true, 0, 'ANALYTIC')
     chk('+aileron (right TED): rolling moment < 0 (roll left)', dM(1, 2) < 0, true, 0, 'ANALYTIC')
     chk('+rudder (TEL): yawing moment < 0 (nose left)', dM(3, 3) < 0, true, 0, 'ANALYTIC')
     chk('elevator makes no roll or yaw (symmetric aircraft)', [dM(1, 1) dM(3, 1)], [0 0], 1e-6, 'ANALYTIC')];
draw = @(ax) drawControl(ax, dM);
end

function [t, C, draw] = casePath()
t = 'Simulated 2 deg aileron step: path and body axes along it';
out = run_f16_sim(565.6854, 10013, 'Input', 'step', 'Channel', 'aileron', 'Amplitude_deg', 2, ...
    'Start_s', 0.5, 'Duration_s', 5, 'Quiet', true);
X = out.x; if size(X, 1) ~= 13, X = X.'; end
tt = out.t(:).'; n = numel(tt);
pn = X(11:13, :);
pdot = zeros(3, n);
for k = 1:n
    Cbn = vital.frames.quat2dcm(X(7:10, k) / norm(X(7:10, k)));   % normalize as the plant does
    pdot(:, k) = Cbn' * X(1:3, k);
end
mid = 2:n-1;
fd = (pn(:, mid + 1) - pn(:, mid - 1)) ./ (tt(mid + 1) - tt(mid - 1));     % central difference of the path
phi = out.y.phi(:).'; h = out.y.h(:).';
C = [chk('run COMPLETED', strcmp(out.status, 'COMPLETED'), true, 0, 'ANALYTIC')
     chk('path slope = C_bn'' v_b (central difference, m/s)', fd, pdot(:, mid), 2e-2, 'ANALYTIC')
     chk('+aileron rolls LEFT: final bank < 0', phi(end) < 0, true, 0, 'ANALYTIC')
     chk('altitude h = -p_N(Down)', h, -pn(3, :), 1e-9, 'ANALYTIC')
     chk('attitude quaternion stays unit length', max(abs(vecnorm(X(7:10, :)) - 1)), 0, 1e-8, 'ANALYTIC')];
draw = @(ax) drawPath(ax, pn, X, tt);
end

function [t, C, draw] = caseEarth()
t = 'Local NED on the WGS-84 Earth at 36 N, 75 W';
K = vital.geo.constants('wgs84');
lat = deg2rad(36); lon = deg2rad(-75); h = 3000;
r = vital.geo.lla2ecef(lat, lon, h, K);
Cne = vital.geo.dcmEcefToNed(lat, lon);
down = Cne' * [0; 0; 1]; north = Cne' * [1; 0; 0]; east = Cne' * [0; 1; 0];
normal = [cos(lat) * cos(lon); cos(lat) * sin(lon); sin(lat)];   % geodetic outward normal
C = [chk('C_ne = Aerospace Toolbox dcmecef2ned', Cne, dcmecef2ned(36, -75), 1e-14, 'INDEP')
     chk('position = Aerospace Toolbox lla2ecef (m)', r, lla2ecef([36 -75 h])', 1e-6, 'INDEP')
     chk('Down = minus the geodetic normal', down, -normal, 1e-14, 'ANALYTIC')
     chk('North points towards the pole (ECEF z > 0)', north(3) > 0, true, 0, 'ANALYTIC')
     chk('East is horizontal (ECEF z = 0)', east(3), 0, 1e-15, 'ANALYTIC')
     chk('N x E = D (right-handed)', cross(north, east), down, 1e-14, 'ANALYTIC')];
draw = @(ax) drawEarth(ax, r, north, east, down);
end

% =========================================================================
% Drawing helpers. Plot coordinates: [North East Up] = [n1 n2 -n3].
% =========================================================================
function p = P(vn)
p = [vn(1, :); vn(2, :); -vn(3, :)];
end

function triad(ax, o, Rcols, s, lbl, solid)
cols = [0.85 0.1 0.1; 0.1 0.6 0.1; 0.1 0.2 0.85];
for k = 1:3
    d = P(Rcols(:, k)) * s;
    if solid
        quiver3(ax, o(1), o(2), o(3), d(1), d(2), d(3), 0, 'Color', cols(k, :), 'LineWidth', 2.2, 'MaxHeadSize', 0.4);
        text(ax, o(1) + 1.08 * d(1), o(2) + 1.08 * d(2), o(3) + 1.08 * d(3), lbl{k}, 'Color', cols(k, :), ...
            'FontWeight', 'bold', 'Interpreter', 'none');
    else
        quiver3(ax, o(1), o(2), o(3), d(1), d(2), d(3), 0, 'Color', [0.55 0.55 0.55], 'LineStyle', '--', ...
            'LineWidth', 1, 'MaxHeadSize', 0.3);
        text(ax, o(1) + 1.08 * d(1), o(2) + 1.08 * d(2), o(3) + 1.08 * d(3), lbl{k}, 'Color', [0.45 0.45 0.45], ...
            'Interpreter', 'none');
    end
end
end

function nedAxes(ax, s)
triad(ax, [0 0 0], eye(3), s, {'North', 'East', 'Down'}, false);
xlabel(ax, 'North'); ylabel(ax, 'East'); zlabel(ax, 'Up');
axis(ax, 'equal'); view(ax, -50, 22);
end

function drawAttitude(ax, Cbn, note)
nedAxes(ax, 1.2);
triad(ax, [0 0 0], Cbn', 1, {'x_b nose', 'y_b right wing', 'z_b belly'}, true);
[X, Y] = meshgrid([-1.2 1.2]); patch(ax, X([1 2 4 3]), Y([1 2 4 3]), [0 0 0 0], [0.85 0.92 1], ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');
subtitle(ax, note, 'Interpreter', 'none');
end

function drawCombined(ax, C1, C2, C3)
nedAxes(ax, 1.2);
triad(ax, [0 0 0], C1', 0.6, {'after yaw', '', ''}, false);
triad(ax, [0 0 0], C2', 0.8, {'after pitch', '', ''}, false);
triad(ax, [0 0 0], C3', 1, {'x_b nose', 'y_b right wing', 'z_b belly'}, true);
subtitle(ax, 'grey dashed: NED, then after yaw, after pitch; solid: final body', 'Interpreter', 'none');
end

function drawVelocity(ax, Cbn, vb, note)
nedAxes(ax, 1.2);
triad(ax, [0 0 0], Cbn', 1, {'x_b nose', 'y_b', 'z_b'}, true);
vn = Cbn' * vb; d = P(vn / norm(vn)) * 1.3;
quiver3(ax, 0, 0, 0, d(1), d(2), d(3), 0, 'k', 'LineWidth', 2.5, 'MaxHeadSize', 0.4);
text(ax, d(1), d(2), d(3) + 0.08, 'velocity', 'FontWeight', 'bold');
plot3(ax, [0 1.4], [0 0], [0 0], 'Color', [0.3 0.6 1], 'LineWidth', 1);
text(ax, 1.4, 0, -0.06, 'horizon', 'Color', [0.3 0.6 1]);
subtitle(ax, note, 'Interpreter', 'none');
end

function drawSideslip(ax, vb)
d = [vb(1); vb(2); -vb(3)] / norm(vb);
triad(ax, [0 0 0], diag([1 1 1]), 1, {'x_b nose', 'y_b right wing', 'z_b belly'}, true);
quiver3(ax, 0, 0, 0, 1.3 * d(1), 1.3 * d(2), 1.3 * d(3), 0, 'k', 'LineWidth', 2.5, 'MaxHeadSize', 0.4);
text(ax, 1.3 * d(1), 1.3 * d(2), 1.3 * d(3) + 0.06, 'air-relative velocity', 'FontWeight', 'bold');
plot3(ax, [0 1.3 * d(1)], [0 1.3 * d(2)], [0 0], 'k:');
xlabel(ax, 'x_b (nose)'); ylabel(ax, 'y_b (right)'); zlabel(ax, '-z_b (up)');
axis(ax, 'equal'); view(ax, -60, 20);
subtitle(ax, 'beta: velocity towards the right wing; alpha: velocity below the nose (w > 0)', 'Interpreter', 'none');
end

function drawGravity(ax, Cs, names)
g = 9.80665;
for k = 1:3
    o = [0; 3 * (k - 1); 0];
    gb = Cs{k} * [0; 0; g] / g;
    triad(ax, o, eye(3), 0.8, {'x_b', 'y_b', 'z_b'}, true);
    d = [gb(1); gb(2); -gb(3)] * 1.2;
    quiver3(ax, o(1), o(2), o(3), d(1), d(2), d(3), 0, 'm', 'LineWidth', 2.5, 'MaxHeadSize', 0.4);
    text(ax, o(1), o(2), 1.2, names{k}, 'Interpreter', 'none');
end
xlabel(ax, 'x_b'); ylabel(ax, 'y_b (cases side by side)'); zlabel(ax, '-z_b');
axis(ax, 'equal'); view(ax, -40, 15);
subtitle(ax, 'magenta = gravity in BODY axes (drawn in each aircraft''s own axes)', 'Interpreter', 'none');
end

function drawCg(ax, A25, A30, F)
ft = 0.3048;
plot(ax, [-30 25], [0 0], 'Color', [0.6 0.6 0.6], 'LineWidth', 6);           % fuselage line (ft), BFRP x
plot(ax, 0, 0, 'ks', 'MarkerSize', 12, 'MarkerFaceColor', 'k');
text(ax, 0.3, -1.6, 'MRC (35 % MAC) = BFRP origin', 'FontSize', 9);
plot(ax, A25.r_cg(1) / ft, 0, 'o', 'MarkerSize', 12, 'MarkerFaceColor', [0.1 0.5 0.1], 'Color', [0.1 0.5 0.1]);
text(ax, A25.r_cg(1) / ft, 1.6, 'CG 25 %', 'Color', [0.1 0.5 0.1], 'FontWeight', 'bold');
plot(ax, A30.r_cg(1) / ft, 0, 'o', 'MarkerSize', 10, 'Color', [0.3 0.3 0.8]);
text(ax, A30.r_cg(1) / ft - 0.2, -1.2, 'CG 30 %', 'Color', [0.3 0.3 0.8]);
quiver(ax, 0, 0, 0, -F(3) / 20000, 0, 'b', 'LineWidth', 2.5, 'MaxHeadSize', 0.6);
text(ax, 0.2, -F(3) / 20000 + 0.3, 'lift (body -z) at the MRC', 'Color', 'b');
quiver(ax, 0, -3, A25.r_cg(1) / ft, 0, 0, 'Color', [0.1 0.5 0.1], 'LineWidth', 1.5, 'MaxHeadSize', 2);
text(ax, 0, -3.6, sprintf('r_cg = %.3f ft forward', A25.r_cg(1) / ft), 'Color', [0.1 0.5 0.1], 'Interpreter', 'none');
th = linspace(0.2, 1.6, 30); xr = A25.r_cg(1) / ft + 2.2 * cos(th); yr = 2.2 * sin(th);
plot(ax, xr, yr, 'r', 'LineWidth', 1.5);
quiver(ax, xr(1), yr(1), xr(1) - xr(3), yr(1) - yr(3), 0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 3);
text(ax, A25.r_cg(1) / ft + 2.4, 2.5, 'nose-down moment about the CG', 'Color', 'r');
xlabel(ax, 'BFRP x (ft, forward)'); ylabel(ax, '-z (up)');
axis(ax, 'equal'); xlim(ax, [-8 8]); ylim(ax, [-5 6]);
subtitle(ax, 'side view; moving the BFRP origin changes coordinates, not the arm MRC - CG');
end

function drawStation(ax, pts, datum, rb)
plot(ax, pts(1, :), pts(3, :), 'ko', 'MarkerFaceColor', [0.8 0.8 0.8]);
plot(ax, datum(1), datum(3), 'ks', 'MarkerFaceColor', 'k');
names = {'nose probe', 'left wing pt', 'fin tip'};
for k = 1:3, text(ax, pts(1, k) + 3, pts(3, k) + 2, sprintf('%s  body [%.0f %.0f %.0f]', names{k}, rb(:, k)), 'FontSize', 8); end
text(ax, datum(1) + 3, datum(3) - 3, 'BFRP datum', 'FontSize', 8);
quiver(ax, datum(1), datum(3) - 15, -30, 0, 0, 'r', 'LineWidth', 2); text(ax, datum(1) - 30, datum(3) - 19, 'body x (forward)', 'Color', 'r');
quiver(ax, datum(1), datum(3) - 15, 0, -15, 0, 'b', 'LineWidth', 2); text(ax, datum(1) + 2, datum(3) - 30, 'body z (down)', 'Color', 'b');
quiver(ax, 40, 60, 30, 0, 0, 'Color', [0.5 0.5 0.5]); text(ax, 40, 64, 'station x (aft)', 'Color', [0.4 0.4 0.4]);
quiver(ax, 40, 60, 0, 15, 0, 'Color', [0.5 0.5 0.5]); text(ax, 30, 78, 'station z (up)', 'Color', [0.4 0.4 0.4]);
xlabel(ax, 'station x (in, aft)'); ylabel(ax, 'station z (in, up)'); axis(ax, 'equal'); grid(ax, 'on');
end

function drawControl(ax, dM)
n = dM ./ max(abs(dM(:)));
triad(ax, [0 0 0], eye(3), 1, {'x_b (roll axis)', 'y_b (pitch axis)', 'z_b (yaw axis)'}, true);
names = {'+1 deg elevator', '+1 deg aileron', '+1 deg rudder'}; cols = {'m', [0.9 0.5 0], 'c'};
for k = 1:3
    d = [n(1, k); n(2, k); -n(3, k)] * 1.2;
    quiver3(ax, 0, 0, 0, d(1), d(2), d(3), 0, 'Color', cols{k}, 'LineWidth', 3, 'MaxHeadSize', 0.4);
    text(ax, d(1) * 1.1, d(2) * 1.1, d(3) * 1.1, names{k}, 'Color', cols{k}, 'FontWeight', 'bold');
end
xlabel(ax, 'x_b'); ylabel(ax, 'y_b'); zlabel(ax, '-z_b (up)'); axis(ax, 'equal'); view(ax, -50, 25);
subtitle(ax, 'moment vectors (normalized); each points opposite its own axis', 'Interpreter', 'none');
end

function drawPath(ax, pn, X, tt)
p = P(pn - pn(:, 1));
plot3(ax, p(1, :), p(2, :), p(3, :), 'k', 'LineWidth', 1.5);
s = 250;
for k = round(linspace(1, numel(tt), 6))
    Cbn = vital.frames.quat2dcm(X(7:10, k) / norm(X(7:10, k)));   % normalize as the plant does
    triad(ax, p(:, k), Cbn', s, {'', '', ''}, true);
    text(ax, p(1, k), p(2, k), p(3, k) + 1.4 * s, sprintf('t = %.1f s', tt(k)), 'FontSize', 8);
end
xlabel(ax, 'North (m)'); ylabel(ax, 'East (m)'); zlabel(ax, 'Up (m)'); axis(ax, 'equal'); view(ax, -30, 25);
text(ax, p(1, 1), p(2, 1), p(3, 1) - 2 * s, 'red = nose, green = right wing, blue = belly', 'FontSize', 8);
end

function drawEarth(ax, r, north, east, down)
Re = 6378137; [sx, sy, sz] = sphere(24);
surf(ax, Re * sx, Re * sy, Re * sz, 'FaceAlpha', 0.08, 'EdgeColor', [0.75 0.75 0.85], 'FaceColor', [0.6 0.75 1]);
s = 3.5e6;
quiver3(ax, 0, 0, 0, 1.4 * Re, 0, 0, 0, 'Color', [0.5 0.5 0.5]); text(ax, 1.45 * Re, 0, 0, 'ECEF x (lon 0)');
quiver3(ax, 0, 0, 0, 0, 1.4 * Re, 0, 0, 'Color', [0.5 0.5 0.5]); text(ax, 0, 1.45 * Re, 0, 'ECEF y (lon 90E)');
quiver3(ax, 0, 0, 0, 0, 0, 1.4 * Re, 0, 'Color', [0.5 0.5 0.5]); text(ax, 0, 0, 1.45 * Re, 'ECEF z (pole)');
plot3(ax, [0 r(1)], [0 r(2)], [0 r(3)], 'k:');
cols = [0.85 0.1 0.1; 0.1 0.6 0.1; 0.1 0.2 0.85]; v = [north east down]; lb = {'North', 'East', 'Down'};
for k = 1:3
    quiver3(ax, r(1), r(2), r(3), s * v(1, k), s * v(2, k), s * v(3, k), 0, 'Color', cols(k, :), 'LineWidth', 2.5);
    text(ax, r(1) + 1.1 * s * v(1, k), r(2) + 1.1 * s * v(2, k), r(3) + 1.1 * s * v(3, k), lb{k}, 'Color', cols(k, :), 'FontWeight', 'bold');
end
xlabel(ax, 'ECEF x (m)'); ylabel(ax, 'ECEF y (m)'); zlabel(ax, 'ECEF z (m)'); axis(ax, 'equal'); view(ax, -120, 25);
end

% =========================================================================
function c = chk(varargin)
c = vital.viz.checkItem(varargin{:});
end

function s = checkText(checks)
s = {'Numeric checks (VITAL value vs independent reference):', ''};
for c = checks(:)'
    if c.pass, m = 'PASS'; else, m = 'FAIL'; end
    s{end+1} = sprintf('[%s] %s', m, c.what); %#ok<AGROW>
    if islogical(c.value)
        s{end+1} = sprintf('       ref %s', c.ref); %#ok<AGROW>
    else
        s{end+1} = sprintf('       max error %.2e  (tol %.0e, ref %s)', c.error, c.tol, c.ref); %#ok<AGROW>
    end
end
end

function tf = all_(v)
tf = ~isempty(v) && all(v);
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end
