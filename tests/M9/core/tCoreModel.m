classdef (TestTags = {'M9', 'CORE'}) tCoreModel < vital.test.VitalTestCase
%TCOREMODEL  0.9.1-CORE: Component, AeroTableComponent, PropulsorComponent,
%   FlightContext, AircraftModel and the F-16 rebuilt with them
%   (docs/PLAN_CORE_FRAMES.md sections 2.5, 2.8-2.10, 4, 5).
%   PRE-REGISTERED (written before the classes existed):
%   1. EQUIVALENCE GATE. f16 = vital.aircraft.f16.model(opts) (compiled) and
%      AC = vital.aircraft.f16.config(opts) with the same opts; over 1,100 seeded
%      states and controls (rng 91001; 11 configurations x 100: default, each of
%      the 8 AeroScale multipliers alone, all 8 together, CG 30 % with
%      BfrpOffset [0.5 -0.1 0.2] m and Cm_q 0.5), including out-of-envelope
%      points (alpha to 60 deg, beta to 35 deg, de to 30 deg, throttle -0.05..1.05,
%      wind, DeltaT): e = max_i |xdot_model - xdot_plant| / max_i |xdot_plant|
%      <= 1e-12 for every state (REG, PLAN 4); y.F_b, y.M_cg within 1e-12 of their
%      scale; y.alpha, beta, V, qbar, mach, nz equal to 1e-12 rel/abs; y.outOfEnvelope
%      identical on every state; at least 100 states out of the data envelope
%      (non-vacuous).
%   2. The compiled path equals the object path (derivativesObject: Loads objects,
%      Loads.aggregate, weightLoads) on 60 states of the F-16 and the twin:
%      e <= 1e-12 as above (REG, PLAN 2.10).
%   3. README TRIM UNCHANGED: vital.trim.solve(f16.toRuntime(), env, README cond)
%      equals vital.trim.solve(vital.aircraft.f16.config(), ...) to 1e-12 abs in
%      x and u, both status OK (REG).
%   4. FORCE AUDIT through the model at the README trim (run_force_moment_audit
%      F5, F8-F12, E1-E10; signs registered there from CONVENTIONS 7 and physics):
%      wind-axis equilibrium (ANALYTIC, 1e-6 W), sum of forces and of moments about
%      the CG zero (1e-6 W, 1e-6 W cbar), M_cg by hand from the MRC moments (1e-9 W),
%      aero force length the same in body and wind axes (1e-9 rel), weight in NED
%      [0 0 W] (1e-9 W), control and rate effect signs, centreline idle no roll/yaw.
%   5. HYPOTHETICAL TWIN (tests/reference/coreTwinFixture.m, d = 1.5 m, each
%      engine half the F-16 thrust): both engines = F-16 single engine
%      (|dM_cg| <= 1e-9 W); right engine out (enabled = false): dN = +d T/2,
%      dFx = -T/2 (1e-9 T), dL = 0, nose-right yaw acceleration; left out: mirror.
%      Asymmetric throttles 0.2 / 0.9: engine yaw moment about the CG
%      = d (T_le - T_re) (ANALYTIC with T from vital.models.f16.prop, 1e-9 T).
%   6. GUARD: d'Alembert loads are never part of loadsTotal. At a state with
%      p, q, r ~ 0.5 rad/s, loadsTotal(cg) equals the component loads moved by
%      vital.loads.transferLoad and summed by vital.loads.sumLoadsAtCG with gravity
%      (INDEP, 1e-9 of the load scale), while the d'Alembert moment there is
%      > 100 N m (so the check discriminates).
%   7. compile() is never stale: two twins with the SAME axis names and different
%      engine offsets (1 m and 2 m), and a twin with the right engine disabled,
%      each compiled in the same session: compiled path = object path (e <= 1e-12).
%   8. Errors: a component reading a control the model does not have:
%      vital:model:unknownControl; a component axis not in the model's tree:
%      vital:model:axisOutsideTree; two axes with one name: vital:model:duplicateAxis;
%      wrong number of controls: vital:badInput; flight.control('nope'):
%      vital:model:unknownControl.
%   9. run_core_example.m runs and prints the axes, the loads per component, the
%      total at the BFRP and at the CG, and the twin engine-out yaw moment.

    properties
        AC
        env
        tr
        f16
        cond
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            k = vital.units.constants();
            tc.AC = vital.aircraft.f16.config();
            tc.env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tc.cond = struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, tc.cond);
            tc.assertEqual(tc.tr.status, 'OK');
            tc.f16 = vital.aircraft.f16.model();
        end
    end

    methods (Test)
        function f16EquivalenceGate(tc)
            rng(91001);
            cfgs = configurations();
            nPer = 100;
            emax = 0; nOut = 0; nTot = 0; oeSame = true; ymax = 0;
            for c = 1:numel(cfgs)
                o = cfgs{c};
                AC = vital.aircraft.f16.config(o{:});
                m = vital.aircraft.f16.model(o{:});
                for i = 1:nPer
                    [x, u, env] = randomPoint();
                    [xp, yp] = vital.plant.derivatives(x, u, AC, env);
                    [xm, ym] = m.derivatives(x, u, env);
                    e = max(abs(xm - xp)) / max(abs(xp));
                    emax = max(emax, e);
                    sF = max(abs([yp.F_b; yp.M_cg]));
                    ey = max([max(abs([ym.F_b; ym.M_cg] - [yp.F_b; yp.M_cg])) / sF, ...
                        abs(ym.alpha - yp.alpha), abs(ym.beta - yp.beta), abs(ym.V - yp.V) / yp.V, ...
                        abs(ym.qbar - yp.qbar) / yp.qbar, abs(ym.mach - yp.mach) / yp.mach, abs(ym.nz - yp.nz) / max(1, abs(yp.nz))]);
                    ymax = max(ymax, ey);
                    oeSame = oeSame && isequal(ym.outOfEnvelope, yp.outOfEnvelope);
                    nOut = nOut + yp.outOfEnvelope; nTot = nTot + 1;
                end
            end
            fprintf('[tCoreModel] equivalence: %d states, %d out of envelope, max e(xdot) = %.3g, max e(y) = %.3g\n', ...
                nTot, nOut, emax, ymax);
            tc.verifyWithin(nTot, 1000, Inf, 'REG', 'PLAN 4: at least 1,000 seeded states', 'Quantity', 'states');
            tc.verifyWithin(emax, 0, 1e-12, 'REG', 'PLAN 4 equivalence gate: model vs vital.plant.derivatives', ...
                'Quantity', 'max relative xdot difference');
            tc.verifyWithin(ymax, 0, 1e-12, 'REG', 'PLAN 4: diagnostics F_b, M_cg, alpha, beta, V, qbar, mach, nz', ...
                'Quantity', 'max relative y difference');
            tc.verifyTrue(oeSame, 'outOfEnvelope identical on every state');
            tc.verifyWithin(nOut, 100, Inf, 'REG', 'non-vacuous: at least 100 out-of-envelope states', 'Quantity', 'out-of-envelope states');
        end

        function compiledEqualsObjectPath(tc)
            rng(91002);
            twin = coreTwinFixture(1.5);
            emax = 0;
            for i = 1:30
                [x, u, env] = randomPoint();
                [a, ya] = tc.f16.derivatives(x, u, env);
                [b, yb] = tc.f16.derivativesObject(x, u, env);
                emax = max([emax, max(abs(a - b)) / max(abs(a)), max(abs([ya.F_b; ya.M_cg] - [yb.F_b; yb.M_cg])) / max(abs([ya.F_b; ya.M_cg]))]);
                ut = [u(1:3); u(4); min(1, u(4) + 0.3)];
                a = twin.derivatives(x, ut, env);
                b = twin.derivativesObject(x, ut, env);
                emax = max(emax, max(abs(a - b)) / max(abs(a)));
            end
            tc.verifyWithin(emax, 0, 1e-12, 'REG', 'PLAN 2.10: the compiled path equals the object path', ...
                'Quantity', 'max relative difference compiled vs object');
        end

        function readmeTrimUnchanged(tc)
            t2 = vital.trim.solve(tc.f16.toRuntime(), tc.env, tc.cond);
            tc.verifyEqual(t2.status, 'OK');
            tc.verifyTol(t2.x, tc.tr.x, 1e-12, 'abs', 'REG', 'README trim through the model = the existing trim', 'Quantity', 'trim x');
            tc.verifyTol(t2.u, tc.tr.u, 1e-12, 'abs', 'REG', 'README trim through the model = the existing trim', 'Quantity', 'trim u');
        end

        function forceAuditThroughModel(tc)
            k = vital.units.constants();
            m = tc.f16; x0 = tc.tr.x; u0 = tc.tr.u; env = tc.env;
            W = m.MassProps.Mass * env.g;
            cg = m.axis('cg');
            [~, y0] = m.derivatives(x0, u0, env);
            a = y0.alpha; b = y0.beta; gam = y0.theta - a;
            Ls = m.componentLoads(x0, u0, env);
            La = Ls{1}; Le = Ls{2};
            wind = vital.Axis.wind(a, b, cg);
            Fw = La.transform(wind).F;
            D = -Fw(1); L = -Fw(3); T = Le.F(1);
            tc.verifyTol(T * cos(a) * cos(b) - D - W * sin(gam), 0, 1e-6 * W, 'abs', 'ANALYTIC', ...
                'audit F8: T cos(a) - D - W sin(g) = 0 in wind axes', 'Quantity', 'along-path equilibrium', 'Unit', 'N');
            tc.verifyTol(L + T * sin(a) - W * cos(gam), 0, 1e-6 * W, 'abs', 'ANALYTIC', ...
                'audit F8: L + T sin(a) - W cos(g) = 0', 'Quantity', 'normal equilibrium', 'Unit', 'N');
            tc.verifyTol(norm(Fw), norm(La.F), 1e-9, 'rel', 'ANALYTIC', 'audit F5: rotation keeps length', 'Quantity', 'aero force length');
            Lt = m.loadsTotal(x0, u0, env, 'cg');
            tc.verifyTol(norm(Lt.F), 0, 1e-6 * W, 'abs', 'ANALYTIC', 'audit F9: trim means sum of forces = 0', 'Quantity', 'total force', 'Unit', 'N');
            tc.verifyTol(norm(Lt.M), 0, 1e-6 * W * tc.AC.cbar, 'abs', 'ANALYTIC', 'audit F11: sum of moments about CG = 0', ...
                'Quantity', 'total moment about CG', 'Unit', 'N m');
            rcg = cg.originIn(m.axis('mrc'));
            Mhand = La.M + Le.M - cross(rcg, La.F + Le.F);       % both components are at the MRC (body axes)
            tc.verifyTol(Lt.M, Mhand, 1e-9 * W, 'abs', 'ANALYTIC', 'audit F10: M_cg = M_mrc - (r_cg - r_mrc) x F', ...
                'Quantity', 'M_cg by hand', 'Unit', 'N m');
            ned = vital.Axis.root('ned');
            bodyN = vital.Axis.bodyInNed(x0, ned);
            Wn = vital.Vector(m.MassProps.weightLoads(vital.frames.quat2dcm(x0(7:10)), env.g).F, bodyN, 'Quantity', "force").expressIn(ned);
            tc.verifyTol(Wn.V, [0; 0; W], 1e-9 * W, 'abs', 'ANALYTIC', 'audit F12: weight points down in NED', 'Quantity', 'weight in NED', 'Unit', 'N');
            % effects (signs registered in run_force_moment_audit from CONVENTIONS 7 / physics)
            base = m.loadsTotal(x0, u0, env, 'cg').M;
            d5 = deg2rad(5);
            cases = {'u', 1, -d5, [0 1 0]; 'u', 1, d5, [0 -1 0]; 'u', 2, -d5, [1 0 0]; 'u', 2, d5, [-1 0 0]; ...
                'u', 3, -d5, [0 0 1]; 'u', 3, d5, [0 0 -1]; 'x', 4, 0.1, [-1 0 0]; 'x', 5, 0.05, [0 -1 0]; 'x', 6, 0.05, [0 0 -1]};
            for c = 1:size(cases, 1)
                x = x0; u = u0;
                if cases{c, 1} == 'u', u(cases{c, 2}) = u(cases{c, 2}) + cases{c, 3}; else, x(cases{c, 2}) = x(cases{c, 2}) + cases{c, 3}; end
                dM = m.loadsTotal(x, u, env, 'cg').M - base;
                ax = find(cases{c, 4});
                tc.verifyExact(sign(dM(ax)), cases{c, 4}(ax), 'ANALYTIC', ...
                    'run_force_moment_audit E1-E9 (CONVENTIONS 7, rate damping)', 'Quantity', sprintf('effect %d sign', c));
            end
            u = u0; u(4) = 0;
            dM = m.loadsTotal(x0, u, env, 'cg').M - base;
            tc.verifyTol(dM([1 3]), [0; 0], 1e-9 * W, 'abs', 'ANALYTIC', 'audit E10: centreline idle, no roll or yaw', ...
                'Quantity', 'idle dL dN', 'Unit', 'N m');
            tc.verifyTrue(k.ft > 0);
        end

        function twinEngineOut(tc)
            k = vital.units.constants();
            d = 1.5;
            twin = coreTwinFixture(d);
            x0 = tc.tr.x; u0 = tc.tr.u; env = tc.env;
            [~, yp] = vital.plant.derivatives(x0, u0, tc.AC, env);
            T = yp.thrust_lbf * k.lbf;
            W = tc.AC.mass * env.g;
            ut = [u0(1:3); u0(4); u0(4)];
            both = twin.loadsTotal(x0, ut, env, 'cg');
            single = tc.f16.loadsTotal(x0, u0, env, 'cg');
            tc.verifyTol(norm(both.M - single.M), 0, 1e-9 * W, 'abs', 'ANALYTIC', 'audit T1: twin = centreline engine', ...
                'Quantity', 'twin vs single dM_cg', 'Unit', 'N m');
            ro = twin.withComponentEnabled('engine_re', false).compile();
            lo = twin.withComponentEnabled('engine_le', false).compile();
            R = ro.loadsTotal(x0, ut, env, 'cg'); Lf = lo.loadsTotal(x0, ut, env, 'cg');
            tc.verifyTol(R.M(3) - both.M(3), d * T / 2, 1e-9 * T, 'abs', 'ANALYTIC', 'audit T2: right engine out dN = +d T/2', ...
                'Quantity', 'dN right out', 'Unit', 'N m');
            tc.verifyTol(R.F(1) - both.F(1), -T / 2, 1e-9 * T, 'abs', 'ANALYTIC', 'audit T2: dFx = -T/2', 'Quantity', 'dFx right out', 'Unit', 'N');
            tc.verifyTol(R.M(1) - both.M(1), 0, 1e-9 * W, 'abs', 'ANALYTIC', 'audit T2: no roll moment', 'Quantity', 'dL right out', 'Unit', 'N m');
            tc.verifyTol((Lf.M(3) - both.M(3)) + (R.M(3) - both.M(3)), 0, 1e-9 * T, 'abs', 'ANALYTIC', 'audit T3: mirror image', ...
                'Quantity', 'dN left + right', 'Unit', 'N m');
            xdR = ro.derivatives(x0, ut, env); xdB = twin.derivatives(x0, ut, env);
            tc.verifyWithin(xdR(6) - xdB(6), 0, Inf, 'ANALYTIC', 'nose yaws right after the right engine fails', ...
                'Quantity', 'd rdot', 'Unit', 'rad/s2');
            % asymmetric throttles: each engine reads its own channel
            ua = [u0(1:3); 0.2; 0.9];
            Ls = twin.componentLoads(x0, ua, env);
            names = cellfun(@(c) c.Name, twin.Components, 'UniformOutput', false);
            ie = find(startsWith(names, 'engine_'));
            Lsum = vital.Loads.aggregate([Ls{ie}], twin.axis('cg'));
            h = -x0(13);
            ad = vital.airdata.airData(x0(1:3), x0(4:6), vital.frames.quat2dcm(x0(7:10)), env.wind_n, ...
                vital.env.atmosphere(h), struct('b', tc.AC.b, 'cbar', tc.AC.cbar));
            Tle = 0.5 * vital.models.f16.prop(struct('PWR', 20, 'ALT', h / k.ft, 'RMACH', ad.mach)).FEX * k.lbf;
            Tre = 0.5 * vital.models.f16.prop(struct('PWR', 90, 'ALT', h / k.ft, 'RMACH', ad.mach)).FEX * k.lbf;
            tc.verifyTol(Lsum.M(3), d * (Tle - Tre), 1e-9 * T, 'abs', 'ANALYTIC', ...
                'N = d (T_le - T_re); T from vital.models.f16.prop at each engine''s own throttle', ...
                'Quantity', 'asymmetric-throttle yaw moment', 'Unit', 'N m');
        end

        function dAlembertNeverInTotal(tc)
            m = tc.f16; env = tc.env;
            x = tc.tr.x; x(4:6) = [0.5; -0.4; 0.6]; u = tc.tr.u;
            Lt = m.loadsTotal(x, u, env, 'cg');
            Ls = m.componentLoads(x, u, env);
            bfrp = m.axis('bfrp');
            FR = zeros(3, numel(Ls)); MR = FR;
            for i = 1:numel(Ls)
                a = Ls{i}.RefAxis;
                [FR(:, i), MR(:, i)] = vital.loads.transferLoad(Ls{i}.F, Ls{i}.M, bfrp.originIn(a), a.dcmTo(bfrp));
            end
            C = vital.frames.quat2dcm(x(7:10));
            [Fb, Mcg] = vital.loads.sumLoadsAtCG(FR, MR, m.axis('cg').originIn(bfrp), m.MassProps.Mass, C, [0; 0; env.g]);
            s = max(abs([FR(:); MR(:)]));
            tc.verifyTol([Lt.F; Lt.M], [Fb; Mcg], 1e-9 * s, 'abs', 'INDEP', ...
                'components + weight only (vital.loads.sumLoadsAtCG; CONVENTIONS 6: no d''Alembert terms)', 'Quantity', 'loadsTotal at CG');
            D = m.MassProps.dAlembertLoads([0; 0; 0], x(4:6), [0; 0; 0]);
            tc.verifyWithin(norm(D.M), 100, Inf, 'ANALYTIC', 'the guard discriminates: -w x J w is large here', ...
                'Quantity', 'dAlembert moment', 'Unit', 'N m');
        end

        function compileIsNotStale(tc)
            rng(91003);
            A = coreTwinFixture(1.0);
            B = coreTwinFixture(2.0);
            Bo = B.withComponentEnabled('engine_re', false).compile();
            [x, u, env] = randomPoint();
            ut = [u(1:3); 0.3; 0.8];
            emax = 0;
            for mm = {A, B, Bo}
                a = mm{1}.derivatives(x, ut, env);
                b = mm{1}.derivativesObject(x, ut, env);
                emax = max(emax, max(abs(a - b)) / max(abs(a)));
            end
            tc.verifyWithin(emax, 0, 1e-12, 'REG', 'compile() rebuilds every chain; same names, different geometry', ...
                'Quantity', 'compiled vs object, three models');
            tc.verifyTol(B.Compiled.r(:, strcmp(B.Compiled.names, 'engine_re')), B.axis('engine_re').originIn(B.axis('bfrp')), 0, 'abs', ...
                'ANALYTIC', 'compiled offset = the axis chain', 'Quantity', 'compiled engine_re offset', 'Unit', 'm');
        end

        function modelErrors(tc)
            bfrp = vital.Axis.root('bfrp');
            cg = vital.Axis([0.3 0 0], eye(3), bfrp, 'Name', 'cg');
            eng = vital.Axis([0 0 0], eye(3), bfrp, 'Name', 'engine');
            mp = vital.MassProperties(1000, cg, diag([100 200 250]));
            th = @(fl, t) deal(1000 * t, 0, struct('outOfEnvelope', false));
            p = vital.PropulsorComponent('engine', eng, th, 'throttle_x');
            tc.verifyError(@() vital.AircraftModel('bad', [bfrp cg eng], {p}, mp, {'throttle'}), 'vital:model:unknownControl');
            stray = vital.Axis([0 0 0], eye(3), bfrp, 'Name', 'stray');
            p2 = vital.PropulsorComponent('engine', stray, th, 'throttle');
            tc.verifyError(@() vital.AircraftModel('bad', [bfrp cg eng], {p2}, mp, {'throttle'}), 'vital:model:axisOutsideTree');
            other = vital.Axis([0 0 0], eye(3), vital.Axis.root('elsewhere'), 'Name', 'engine2');
            p3 = vital.PropulsorComponent('engine', other, th, 'throttle');
            tc.verifyError(@() vital.AircraftModel('bad', [bfrp cg eng other], {p3}, mp, {'throttle'}), 'vital:model:axisOutsideTree');
            dup = vital.Axis([1 0 0], eye(3), bfrp, 'Name', 'engine');
            tc.verifyError(@() vital.AircraftModel('bad', [bfrp cg eng dup], {}, mp, {'throttle'}), 'vital:model:duplicateAxis');
            tc.verifyError(@() tc.f16.derivatives(tc.tr.x, [0; 0; 0], tc.env), 'vital:badInput');
            fl = vital.FlightContext(tc.tr.x, tc.tr.u, tc.env, tc.f16.Controls, tc.f16.Ref);
            tc.verifyError(@() fl.control('nope'), 'vital:model:unknownControl');
            tc.verifyTol(fl.control('throttle'), tc.tr.u(4), 0, 'abs', 'ANALYTIC', 'controls by name', 'Quantity', 'throttle by name');
        end

        function exampleScriptRuns(tc)
            out = evalc('run_core_example');
            tc.verifyTrue(contains(out, 'loads_total'), 'prints loads_total');
            tc.verifyTrue(contains(out, 'about the CG'), 'prints the total about the CG');
            tc.verifyTrue(contains(out, 'engine out'), 'prints the twin engine-out case');
            tc.verifyTrue(contains(out, 'axis_cg') || contains(out, 'cg'), 'prints the axes');
        end
    end
end

function cfgs = configurations()
names = {'Cm_q', 'Cl_p', 'Cnt_table', 'Cm_table', 'Cl_table', 'Cn_r', 'Cm_basic', 'Cm_de'};
cfgs = {{}};
for i = 1:numel(names)
    cfgs{end+1} = {'AeroScale', struct(names{i}, 0.3 + 1.7 * rand)}; %#ok<AGROW>
end
s = struct();
for i = 1:numel(names), s.(names{i}) = 0.3 + 1.7 * rand; end
cfgs{end+1} = {'AeroScale', s};
cfgs{end+1} = {'CG_PCT_MAC', 30, 'BfrpOffset', [0.5; -0.1; 0.2], 'AeroScale', struct('Cm_q', 0.5)};
end

function [x, u, env] = randomPoint()
V = 60 + 290 * rand;
a = deg2rad(-20 + 80 * rand); b = deg2rad(-35 + 70 * rand);
v = V * [cos(a) * cos(b); sin(b); sin(a) * cos(b)];
q = randn(4, 1); q = q / norm(q);
w = (rand(3, 1) - 0.5) * 3;
h = 15000 * rand;
x = [v; w; q; (rand(2, 1) - 0.5) * 2e4; -h];
u = [deg2rad(-30 + 60 * rand); deg2rad(-25 + 50 * rand); deg2rad(-35 + 70 * rand); -0.05 + 1.1 * rand];
env = struct('g', 9.80665, 'wind_n', (rand(3, 1) - 0.5) * 20, 'deltaT', (rand - 0.5) * 30);
end
