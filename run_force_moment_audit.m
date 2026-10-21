%RUN_FORCE_MOMENT_AUDIT  Check that VITAL's forces and moments are right: the axis
%   transformations, the moment transfers, and the responses to the controls,
%   body rates and thrust.
%
%   Run:  run_force_moment_audit       (a SCRIPT; results in workspace variable FMA)
%   Writes reports/force_audit/force_moment_audit.md and three PNG figures.
%
%   METHOD (nothing is tuned to make it pass):
%   1. Trim the F-16 with the framework (vital.trim.solve) and take every load
%      from the plant itself (vital.plant.derivatives, the function that trim,
%      linearization and simulation all use).
%   2. Express lift, drag, side force, thrust and weight in four frames: body,
%      wind, stability and NED. Every rotation is computed twice: by hand from the
%      textbook DCM formulas, and by the Aerospace Toolbox (dcmbody2wind,
%      angle2dcm). The two must agree.
%   3. Check against physics that does not use the framework:
%        - vector lengths are the same in every frame (a rotation keeps length)
%        - every DCM is orthonormal with det = +1
%        - level-flight equilibrium in WIND axes, written independently:
%              T cos(a) - D - W sin(g) = 0,   L + T sin(a) - W cos(g) = 0
%        - sum of forces = 0 and sum of moments about the CG = 0 (that is what trim means)
%        - M_cg recomputed by hand from the MRC moments:  M_cg = M_mrc - (r_cg - r_mrc) x F
%   4. Effect analysis: hold the state, change ONE input, and report the change in
%      force, moment and angular acceleration (from the plant's own equations of
%      motion). The EXPECTED SIGN of each change is written down BEFORE the run,
%      from the sign conventions (docs/CONVENTIONS.md section 7) or from physics
%      (rate damping). It is never taken from the result.
%   5. Engine cases: (a) the real F-16 (one engine on the centreline): idle, and
%      thrust removed; (b) a HYPOTHETICAL twin with the same total thrust split
%      at +/- d. Its loads go through the framework's own sumLoadsAtCG and
%      rigidBodyDerivs; the analytic yaw moment N = +d*T/2 is the independent check.
%
%   Sign conventions: body x forward, y right wing, z down. Moments: L roll
%   (+ = right wing down), M pitch (+ = nose up), N yaw (+ = nose right,
%   clockwise seen from above).

% ============================== SETTINGS ====================================
V_ftps = 565.6854;  h_ft = 10013;  cg = 25;   % NASA README trim point
dDeg   = 5;          % control step, deg (each sign)
dRate  = [0.1 0.05 0.05];  % body-rate steps p, q, r (rad/s)
d_eng_m = 1.5;       % HYPOTHETICAL twin: lateral engine offset (m), illustrative only
% ============================================================================
addpath(fileparts(mfilename('fullpath'))); startup_vital;
k = vital.units.constants();
outDir = fullfile(fileparts(mfilename('fullpath')), 'reports', 'force_audit'); if ~exist(outDir, 'dir'), mkdir(outDir); end
AC  = vital.aircraft.f16.config('CG_PCT_MAC', cg);
env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
tr  = vital.trim.solve(AC, env, struct('type', 'level', 'V', V_ftps * k.ft, 'h', h_ft * k.ft, 'gamma', 0, 'psi', 0));
assert(strcmp(tr.status, 'OK'), 'trim failed: %s', tr.status);
x0 = tr.x; u0 = tr.u;
[xd0, y0] = vital.plant.derivatives(x0, u0, AC, env);

FMA = struct('checks', struct('id', {}, 'what', {}, 'actual', {}, 'expected', {}, 'tol', {}, 'pass', {}));
chk = @(FMA, id, what, act, exp, tol) addCheck(FMA, id, what, act, exp, tol);

%% ---------- 1. Nominal flight case: forces in four frames -------------------
a = y0.alpha; b = y0.beta; th = y0.theta; ph = y0.phi; ps = y0.psi; gam = th - a;
W = AC.mass * env.g;
C_bn = vital.frames.quat2dcm(x0(7:10) / norm(x0(7:10)));         % framework
C_bn_tbx = angle2dcm(ps, th, ph, 'ZYX');                          % Aerospace Toolbox
ca = cos(a); sa = sin(a); cb = cos(b); sb = sin(b);
C_wb = [ca*cb, sb, sa*cb; -ca*sb, cb, -sa*sb; -sa, 0, ca];        % by hand (Etkin)
C_wb_tbx = dcmbody2wind(a, b);                                     % Aerospace Toolbox
C_sb = [ca 0 sa; 0 1 0; -sa 0 ca];                                 % body -> stability, by hand

F_aero_b = y0.F_aero; F_prop_b = y0.F_prop; F_grav_b = C_bn * [0; 0; W];
F_aero_w = C_wb * F_aero_b;
D = -F_aero_w(1); Y = F_aero_w(2); L = -F_aero_w(3); T = F_prop_b(1);

FMA = chk(FMA, 'F1', 'C_bn: framework quaternion vs toolbox angle2dcm (max abs diff)', max(abs(C_bn(:) - C_bn_tbx(:))), 0, 1e-12);
FMA = chk(FMA, 'F2', 'C_wb: hand formula vs toolbox dcmbody2wind (max abs diff)', max(abs(C_wb(:) - C_wb_tbx(:))), 0, 1e-14);
for M = {C_bn, C_wb, C_sb}
    FMA = chk(FMA, 'F3', 'DCM orthonormal: max |C C'' - I|', max(max(abs(M{1} * M{1}' - eye(3)))), 0, 1e-12);
    FMA = chk(FMA, 'F3', 'DCM det = +1 (right-handed)', det(M{1}), 1, 1e-12);
end
FMA = chk(FMA, 'F4', 'weight in body = [-W sin(theta); W sin(phi)cos(theta); W cos(phi)cos(theta)] (analytic)', ...
    max(abs(F_grav_b - W * [-sin(th); sin(ph)*cos(th); cos(ph)*cos(th)])), 0, 1e-9 * W);
FMA = chk(FMA, 'F5', '|aero force| same in body and wind axes', norm(F_aero_w) - norm(F_aero_b), 0, 1e-9 * norm(F_aero_b));
FMA = chk(FMA, 'F6', 'lift positive (aero force points up off the flight path)', double(L > 0), 1, 0);
FMA = chk(FMA, 'F6', 'drag positive (aero force opposes the airflow)', double(D > 0), 1, 0);
FMA = chk(FMA, 'F7', 'thrust along +x body only (F_prop y, z = 0)', max(abs(F_prop_b(2:3))), 0, 0);
FMA = chk(FMA, 'F8', 'equilibrium along flight path: T cos(a) - D - W sin(g) (N)', T*ca*cb - D - W*sin(gam), 0, 1e-6 * W);
FMA = chk(FMA, 'F8', 'equilibrium normal to path: L + T sin(a) - W cos(g) (N)', L + T*sa - W*cos(gam), 0, 1e-6 * W);
FMA = chk(FMA, 'F9', 'plant total force at trim |F_b| (N)', norm(y0.F_b), 0, 1e-6 * W);
Mcg_hand = y0.M_aero + y0.M_prop - cross(AC.r_cg - AC.r_mrc, F_aero_b + F_prop_b);
FMA = chk(FMA, 'F10', 'M_cg recomputed by hand from MRC moments vs plant (N m)', max(abs(Mcg_hand - y0.M_cg)), 0, 1e-9 * W);
FMA = chk(FMA, 'F11', 'plant moment about CG at trim |M_cg| (N m)', norm(y0.M_cg), 0, 1e-6 * W * AC.cbar);
F_n = C_bn' * [F_aero_b, F_prop_b, F_grav_b];
FMA = chk(FMA, 'F12', 'weight in NED = [0 0 +W] (points down)', max(abs(F_n(:,3) - [0; 0; W])), 0, 1e-9 * W);
FMA = chk(FMA, 'F12', 'NED: aero + thrust balance weight (sum of NED z) (N)', sum(F_n(3, :)), 0, 1e-6 * W);

frames.body = [F_aero_b, F_prop_b, F_grav_b];
frames.wind = C_wb * frames.body;
frames.stability = C_sb * frames.body;
frames.ned = F_n;

%% ---------- 2-4. Effect analysis: one input changed, state held ------------
base = effects(x0, u0, AC, env);
cases = {};
% expected sign of [dL dM dN] (0 = no prediction); from CONVENTIONS 7 / physics
cases(end+1, :) = {'elevator TE up (de = -5 deg)',   'u', 1, -dDeg,  [0 +1 0], 'nose-up pitch (Cm_de < 0, de < 0)'};
cases(end+1, :) = {'elevator TE down (de = +5 deg)', 'u', 1, +dDeg,  [0 -1 0], 'nose-down pitch'};
cases(end+1, :) = {'aileron, roll right (da = -5 deg)', 'u', 2, -dDeg, [+1 0 0], 'right wing down (Cl_da < 0, da < 0)'};
cases(end+1, :) = {'aileron, roll left (da = +5 deg)',  'u', 2, +dDeg, [-1 0 0], 'left wing down'};
cases(end+1, :) = {'rudder, yaw right (dr = -5 deg)', 'u', 3, -dDeg, [0 0 +1], 'nose right (Cn_dr < 0, dr < 0)'};
cases(end+1, :) = {'rudder, yaw left (dr = +5 deg)',  'u', 3, +dDeg, [0 0 -1], 'nose left'};
cases(end+1, :) = {sprintf('roll rate p = +%.2f rad/s', dRate(1)),  'x', 4, dRate(1), [-1 0 0], 'roll damping opposes p (Cl_p < 0)'};
cases(end+1, :) = {sprintf('pitch rate q = +%.2f rad/s', dRate(2)), 'x', 5, dRate(2), [0 -1 0], 'pitch damping opposes q (Cm_q < 0)'};
cases(end+1, :) = {sprintf('yaw rate r = +%.2f rad/s', dRate(3)),   'x', 6, dRate(3), [0 0 -1], 'yaw damping opposes r (Cn_r < 0)'};
cases(end+1, :) = {'throttle to idle (real F-16)', 'u', 4, -u0(4), [0 0 0], 'centreline thrust: no roll/yaw moment expected'};
nC = size(cases, 1); E = struct([]); axL = 'LMN'; axR = 'pqr';
for c = 1:nC
    x = x0; u = u0;
    if cases{c, 2} == 'u', u(cases{c, 3}) = u(cases{c, 3}) + deg2rad(cases{c, 4}) * (cases{c, 3} < 4) + cases{c, 4} * (cases{c, 3} == 4);
    else, x(cases{c, 3}) = x(cases{c, 3}) + cases{c, 4}; end
    r = effects(x, u, AC, env);
    E(c).name = cases{c, 1}; E(c).dF = r.F - base.F; E(c).dM = r.M - base.M;
    E(c).dWdot = r.wdot - base.wdot; E(c).dLDY = r.LDY - base.LDY; E(c).why = cases{c, 6};
    sgn = cases{c, 5};
    for ax = find(sgn ~= 0)
        FMA = chk(FMA, sprintf('E%d', c), sprintf('%s: sign of d%s', cases{c, 1}, axL(ax)), sign(E(c).dM(ax)), sgn(ax), 0);
        FMA = chk(FMA, sprintf('E%d', c), sprintf('%s: sign of angular accel d%sdot', cases{c, 1}, axR(ax)), sign(E(c).dWdot(ax)), sgn(ax), 0);
    end
    if c == nC   % centreline thrust change: no roll or yaw moment, no side force
        FMA = chk(FMA, 'E10', 'idle: |dL|, |dN| (N m) zero for a centreline engine', max(abs(E(c).dM([1 3]))), 0, 1e-9 * W);
        FMA = chk(FMA, 'E10', 'idle: thrust decreases (dFx < 0)', double(E(c).dF(1) < 0), 1, 0);
    end
end

%% ---------- 5. Engine-out: real F-16 and hypothetical twin ------------------
% (a) real F-16, thrust removed entirely (aero only + gravity)
[Fb_off, Mcg_off] = vital.loads.sumLoadsAtCG(y0.F_aero, y0.M_aero, AC.r_cg, AC.mass, C_bn, [0; 0; env.g]);
eng.single_off.dF = Fb_off - y0.F_b; eng.single_off.dM = Mcg_off - y0.M_cg;
% (b) HYPOTHETICAL twin: same total thrust T, split at y = -d (left) and +d (right),
% same x and z as the MRC; loads about the BFRP are r x F (CONVENTIONS 6)
rL = AC.r_mrc + [0; -d_eng_m; 0]; rR = AC.r_mrc + [0; d_eng_m; 0];
FL = [T/2; 0; 0]; FR = [T/2; 0; 0];
twin = @(useL, useR) twinLoads(y0, AC, C_bn, env, rL, rR, FL * useL, FR * useR, x0);
[Fb2, Mc2, wd2] = twin(1, 1); [FbR, McR, wdR] = twin(1, 0); [FbL, McL, wdL] = twin(0, 1);
FMA = chk(FMA, 'T1', 'twin, both engines = single centreline engine: |dM_cg| (N m)', norm(Mc2 - y0.M_cg), 0, 1e-9 * W);
FMA = chk(FMA, 'T2', 'right engine out: dN = +d T/2 (analytic, N m)', McR(3) - Mc2(3), +d_eng_m * T / 2, 1e-9 * abs(T));
FMA = chk(FMA, 'T2', 'right engine out: nose yaws RIGHT (clockwise from above), sign dN', sign(McR(3) - Mc2(3)), +1, 0);
FMA = chk(FMA, 'T2', 'right engine out: dFx = -T/2 (N)', FbR(1) - Fb2(1), -T / 2, 1e-9 * abs(T));
FMA = chk(FMA, 'T2', 'right engine out: no roll moment (engines on the y axis of the MRC)', McR(1) - Mc2(1), 0, 1e-9 * W);
FMA = chk(FMA, 'T3', 'left engine out: mirror image, dN(left out) = -dN(right out)', (McL(3) - Mc2(3)) + (McR(3) - Mc2(3)), 0, 1e-9 * abs(T));
eng.twin_right_out.dF = FbR - Fb2; eng.twin_right_out.dM = McR - Mc2; eng.twin_right_out.dWdot = wdR - wd2;
eng.twin_left_out.dM = McL - Mc2;
% rudder needed to hold the heading after the right engine fails (framework's own rudder power)
dN_ddr = (E(5).dM(3)) / deg2rad(-dDeg);                 % N m per rad, from the -5 deg rudder case
eng.dr_required_deg = rad2deg(-(McR(3) - Mc2(3)) / dN_ddr);
eng.dr_limit_deg = AC.limits.dr_deg(2);

%% ---------- report -----------------------------------------------------------
FMA.trim = tr; FMA.frames = frames; FMA.LDTW = struct('L', L, 'D', D, 'Y', Y, 'T', T, 'W', W);
FMA.effects = E; FMA.engine = eng; FMA.dcm = struct('C_bn', C_bn, 'C_wb', C_wb, 'C_sb', C_sb);
nPass = sum([FMA.checks.pass]); nAll = numel(FMA.checks);
writeReport(FMA, outDir, V_ftps, h_ft, cg, a, th, d_eng_m, nPass, nAll);
makeFigures(FMA, outDir, a, th);
fprintf('\nFORCE/MOMENT AUDIT: %d of %d checks pass. Report: %s\n', nPass, nAll, fullfile(outDir, 'force_moment_audit.md'));
for c = find(~[FMA.checks.pass]), fprintf('  FAIL %s  %s  actual %g expected %g\n', FMA.checks(c).id, FMA.checks(c).what, FMA.checks(c).actual, FMA.checks(c).expected); end
clear a b th ph ps gam W ca sa cb sb c x u r sgn ax M k env AC tr x0 u0 xd0 y0 base cases nC chk twin

%% ============================ local functions ================================
function FMA = addCheck(FMA, id, what, act, exp, tol)
FMA.checks(end+1) = struct('id', id, 'what', what, 'actual', act, 'expected', exp, 'tol', tol, ...
    'pass', isfinite(act) && abs(act - exp) <= tol);
end

function r = effects(x, u, AC, env)
% loads and angular acceleration from the plant itself
[xd, y] = vital.plant.derivatives(x, u, AC, env);
r.F = y.F_b; r.M = y.M_cg; r.wdot = xd(4:6);
ca = cos(y.alpha); sa = sin(y.alpha); cb = cos(y.beta); sb = sin(y.beta);
Fw = [ca*cb, sb, sa*cb; -ca*sb, cb, -sa*sb; -sa, 0, ca] * y.F_aero;
r.LDY = [-Fw(3); -Fw(1); Fw(2)];      % lift, drag, side force
end

function [F_b, M_cg, wdot] = twinLoads(y0, AC, C_bn, env, rL, rR, FL, FR, x0)
% aero column (about the BFRP) + two engine columns; framework sum and EOM
F_R = [y0.F_aero, FL, FR];
M_R = [y0.M_aero + cross(AC.r_mrc, y0.F_aero), cross(rL, FL), cross(rR, FR)];
[F_b, M_cg] = vital.loads.sumLoadsAtCG(F_R, M_R, AC.r_cg, AC.mass, C_bn, [0; 0; env.g]);
xd = vital.eom.rigidBodyDerivs(x0(1:3), x0(4:6), x0(7:10), F_b, M_cg, AC.mass, AC.J);
wdot = xd(4:6);
end

function writeReport(FMA, outDir, V, h, cg, a, th, d, nPass, nAll)
f = fopen(fullfile(outDir, 'force_moment_audit.md'), 'w'); c = onCleanup(@() fclose(f));
p = @(varargin) fprintf(f, varargin{:});
p('# Force and moment audit (VITAL %s)\n\n', vital.version());
p('**%d of %d checks pass.** Trim: %.4f ft/s, %.0f ft, CG %g %% MAC; alpha %.4f deg, theta %.4f deg.\n\n', nPass, nAll, V, h, cg, rad2deg(a), rad2deg(th));
p('Axes: body x forward, y right, z down. L roll (+ right wing down), M pitch (+ nose up), N yaw (+ nose right). SI units (N, N m, rad/s^2).\n\n');
p('## 1. The four forces in four frames (N)\n\nColumns: aero (lift+drag+side), thrust, weight.\n\n');
fr = {'body', 'wind', 'stability', 'ned'}; xyz = 'xyz';
for i = 1:4
    B = FMA.frames.(fr{i}); p('**%s**\n\n| | aero | thrust | weight | sum |\n|---|---|---|---|---|\n', fr{i});
    for j = 1:3, p('| %s | %.1f | %.1f | %.1f | %.3g |\n', xyz(j), B(j,1), B(j,2), B(j,3), sum(B(j,:))); end
    p('\n');
end
s = FMA.LDTW; p('Wind axes give: **lift %.1f N, drag %.1f N, side %.3g N, thrust %.1f N, weight %.1f N** (L/D %.2f).\n\n', s.L, s.D, s.Y, s.T, s.W, s.L / s.D);
p('DCMs used (body->wind C_wb, NED->body C_bn):\n\n```\nC_wb =\n%s\nC_bn =\n%s```\n\n', mat2str4(FMA.dcm.C_wb), mat2str4(FMA.dcm.C_bn));
p('## 2. Effect of one input (state held), change from trim\n\n| case | dFx | dFy | dFz | dL | dM | dN | dp_dot | dq_dot | dr_dot | expected |\n|---|---|---|---|---|---|---|---|---|---|---|\n');
for e = FMA.effects
    p('| %s | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.4f | %.4f | %.4f | %s |\n', e.name, e.dF, e.dM, e.dWdot, e.why);
end
g = FMA.engine;
p('\n## 3. Engine cases\n\nReal F-16 (one centreline engine), thrust removed: dF = [%.1f %.1f %.1f] N, dM = [%.3g %.3g %.3g] N m: thrust loss only, no roll or yaw moment.\n\n', g.single_off.dF, g.single_off.dM);
p('**HYPOTHETICAL twin** (same total thrust, engines at y = +/-%.2f m; the F-16 has no such engines; illustrative only). Right engine out:\n\n', d);
p('- dF = [%.1f %.1f %.1f] N, dM = [%.1f %.1f %.1f] N m, angular accel change [%.4f %.4f %.4f] rad/s^2\n', g.twin_right_out.dF, g.twin_right_out.dM, g.twin_right_out.dWdot);
p('- dN > 0: the nose yaws **right** (clockwise seen from above), toward the dead engine: the live left engine pushes its side forward.\n');
p('- Rudder to hold heading (framework rudder power): **%.2f deg** (limit +/-%g deg).\n\n', g.dr_required_deg, g.dr_limit_deg);
p('## 4. Every check\n\n| id | check | actual | expected | tol | result |\n|---|---|---|---|---|---|\n');
for k = FMA.checks, p('| %s | %s | %.6g | %.6g | %.3g | %s |\n', k.id, k.what, k.actual, k.expected, k.tol, ternary(k.pass)); end
end

function s = ternary(b), if b, s = 'PASS'; else, s = '**FAIL**'; end, end
function s = mat2str4(M), s = sprintf('%10.6f %10.6f %10.6f\n', M'); end

function makeFigures(FMA, outDir, a, th)
s = FMA.LDTW; fig = figure('Visible', 'off', 'Position', [100 100 760 560]); hold on; axis equal; grid on;
% side view, nose to the right, up = -z_b; vectors scaled by weight
B = FMA.frames.body; sc = 1 / s.W; lab = {'aero (L+D)', 'thrust', 'weight'}; col = lines(3);
for i = 1:3
    quiver(0, 0, B(1, i) * sc, -B(3, i) * sc, 0, 'LineWidth', 2, 'Color', col(i, :), 'MaxHeadSize', 0.4);
    text(B(1, i) * sc * 1.08, -B(3, i) * sc * 1.08, lab{i}, 'Color', col(i, :));
end
Lb = s.L * [sin(a); cos(a)] * sc; Db = s.D * [-cos(a); sin(a)] * sc;   % lift, drag in body x / up
quiver(0, 0, Lb(1), Lb(2), 0, '--', 'Color', [.4 .4 .4]); text(Lb(1), Lb(2), ' lift');
quiver(0, 0, Db(1), Db(2), 0, '--', 'Color', [.4 .4 .4]); text(Db(1), Db(2), ' drag');
plot([-cos(a) cos(a)] * 0.3, [sin(a) -sin(a)] * 0.3, ':k'); text(0.3 * cos(a), -0.3 * sin(a), ' airflow / flight path');
xlabel('x_b (nose), force / weight'); ylabel('-z_b (up), force / weight');
title(sprintf('Trim force balance in body axes (alpha %.2f deg, theta %.2f deg)', rad2deg(a), rad2deg(th)));
exportgraphics(fig, fullfile(outDir, 'force_balance_body.png')); close(fig);

E = FMA.effects; fig = figure('Visible', 'off', 'Position', [100 100 1100 520]);
dM = reshape([E.dM], 3, [])'; names = {E.name};
barh(dM / 1e3); set(gca, 'YTick', 1:numel(names), 'YTickLabel', names, 'YDir', 'reverse'); grid on;
legend({'dL roll (+ right wing down)', 'dM pitch (+ nose up)', 'dN yaw (+ nose right)'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
xlabel('change in moment about the CG (kN m)'); title('Moment change from trim, one input at a time');
exportgraphics(fig, fullfile(outDir, 'moment_changes.png')); close(fig);

g = FMA.engine; fig = figure('Visible', 'off', 'Position', [100 100 700 420]);
bar(categorical({'L roll', 'M pitch', 'N yaw'}), [g.single_off.dM, g.twin_right_out.dM, g.twin_left_out.dM] / 1e3); grid on;
legend({'F-16 thrust removed (centreline)', 'HYPOTHETICAL twin: right engine out', 'HYPOTHETICAL twin: left engine out'}, 'Location', 'southoutside');
ylabel('change in moment about the CG (kN m)'); title('Engine-out moments');
exportgraphics(fig, fullfile(outDir, 'engine_out.png')); close(fig);
end
