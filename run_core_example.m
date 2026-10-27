%RUN_CORE_EXAMPLE  The object core in use: axes, vectors, loads and mass properties
%   (0.9.1-CORE; docs/PLAN_CORE_FRAMES.md, FRAMEWORK_GUIDE 12c).
%
%   Run:  run_core_example        (a SCRIPT; prints only, no files, no figures)
%
%   1. Builds the F-16 as a vital.AircraftModel (vital.aircraft.f16.model) and trims
%      it at the NASA README point through the model (f16.toRuntime()).
%   2. Prints its axes, the loads of each component in its own axis and at the
%      BFRP, the weight, and the total at the BFRP and at the CG (zero at trim).
%   3. Builds a left-engine thrust by hand, in the whiteboard's style
%      (axis_le, force_thrust_le, loads_le).
%   4. Runs the HYPOTHETICAL twin-engine example (tests/reference/coreTwinFixture.m;
%      not a real aircraft): right engine out gives dN = +d T/2, nose right.

root = fileparts(mfilename('fullpath'));
addpath(root);
if ~exist('coreTwinFixture', 'file'), addpath(fullfile(root, 'tests', 'reference')); end
k = vital.units.constants();

%% 1. the F-16 model and its trim
f16 = vital.aircraft.f16.model();
env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
cond = struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0);
tr = vital.trim.solve(f16.toRuntime(), env, cond);
x = tr.x; u = tr.u;
fprintf('F-16 model: %s\n', f16.Name);
fprintf('README trim through the model: %s, alpha %.4f deg, de %.4f deg, throttle %.4f\n\n', ...
    tr.status, rad2deg(tr.alpha), rad2deg(u(1)), u(4));

%% 2. axes and loads
axis_bfrp = f16.axis('bfrp');
axis_cg = f16.axis('cg');
fprintf('Axes (origin in the parent, m; 3-2-1 Euler, deg):\n');
disp(f16.Axes);
Ls = f16.componentLoads(x, u, env);
loads_aero = Ls{1};
loads_engine = Ls{2};
fprintf('\nloads_aero (component ''%s'', in its own axis):\n', f16.Components{1}.Name); disp(loads_aero);
fprintf('loads_aero moved to the BFRP:\n'); disp(loads_aero.transform(axis_bfrp));
fprintf('loads_engine (component ''%s'', in its own axis):\n', f16.Components{2}.Name); disp(loads_engine);
loads_weight = f16.MassProps.weightLoads(vital.frames.quat2dcm(x(7:10)), env.g);
fprintf('loads_weight (at the CG):\n'); disp(loads_weight);
loads_total = vital.Loads.aggregate({loads_aero, loads_engine, loads_weight}, axis_bfrp);
fprintf('loads_total about the BFRP:\n'); disp(loads_total);
loads_total_cg = loads_total.transform(axis_cg);
fprintf('loads_total about the CG (zero at trim: that is what trim means):\n'); disp(loads_total_cg);
fprintf('  same from the model: |F| = %.3g N, |M| = %.3g N m\n\n', ...
    norm(f16.loadsTotal(x, u, env, 'cg').F), norm(f16.loadsTotal(x, u, env, 'cg').M));

%% 3. the whiteboard: a left engine 1.5 m to the left of the MRC
d = 1.5;
T = loads_engine.F(1);
axis_le = vital.Axis([0 -d 0], eye(3), f16.axis('mrc'), 'Name', 'axis_le');
force_thrust_le = vital.Vector([T/2 0 0], axis_le, 'Quantity', "force");
loads_le = vital.Loads(force_thrust_le, vital.Vector([0 0 0], axis_le, 'Quantity', "moment"));
fprintf('Whiteboard: force_thrust_le in axis_le, then loads_le about the CG:\n');
disp(loads_le.transform(axis_cg));

%% 4. HYPOTHETICAL twin, right engine out
twin = coreTwinFixture(d);
ut = [u(1:3); u(4); u(4)];
both = twin.loadsTotal(x, ut, env, 'cg');
right_out = twin.withComponentEnabled('engine_re', false).compile();
L_out = right_out.loadsTotal(x, ut, env, 'cg');
dN = L_out.M(3) - both.M(3);
xd_both = twin.derivatives(x, ut, env);
xd_out = right_out.derivatives(x, ut, env);
fprintf('HYPOTHETICAL twin (d = %.2f m), right engine out:\n', d);
fprintf('  dN = %+.1f N m (analytic +d T/2 = %+.1f N m): nose RIGHT\n', dN, d * T / 2);
fprintf('  dFx = %+.1f N (-T/2 = %+.1f N), d(rdot) = %+.4f rad/s^2\n', L_out.F(1) - both.F(1), -T / 2, xd_out(6) - xd_both(6));
