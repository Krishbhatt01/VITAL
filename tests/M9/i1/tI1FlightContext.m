classdef (TestTags = {'M9', 'I1'}) tI1FlightContext < vital.test.VitalTestCase
%TI1FLIGHTCONTEXT  Increment I1 (ADR-043): ONE way to fill a vital.FlightContext.
%   Finding F-3 (I0): under toRuntime the context a component received had empty
%   X, C_bn and Env, so components could only read fl.Air.
%
%   PRE-REGISTERED (written before the implementation):
%   1. sameContextOnEveryFlatPath (REG, isequal): a model = the HYPOTHETICAL twin
%      plus a tests/reference/ContextProbeComponent (zero loads; it records the
%      context it is given). At 5 seeded states the context the probe receives
%      from (a) model.derivatives, (b) model.derivativesObject, (c)
%      vital.plant.derivatives(x, u, model, env), (d) vital.plant.derivatives(x, u,
%      model.toRuntime(), env) and (e) u given as a struct by name is isequal, field
%      by field (X, U, UVector, ControlNames, C_bn, H, Atm, Air, Env, StateLayout),
%      to vital.FlightContext(x, u, env, model.Controls, model.Ref); and
%      independently of the constructor: X = x(:), UVector = u(:), Env = env,
%      C_bn = vital.frames.quat2dcm(q/|q|), H = -x(13), StateLayout 'flat13' (so
%      a constructor that dropped X or C_bn is caught too).
%   2. rotatingContext (REG / ANALYTIC 1e-12): the probe in a zero-control model run
%      through vital.plant.derivativesRotating with the toRuntime struct receives a
%      context with X = the rotating state, StateLayout 'rotating13', Env = the
%      rotating env, H = y.h, Atm.rho = y.rho, Air.V = y.V and C_bn = the 3-2-1 DCM
%      of (y.phi, y.theta, y.psi) to 1e-12 (vital.frames.dcm321).
%   3. noSecondConstructionPath (REG): vital.FlightContext has no fromAirData, bridge
%      or setBridge method any more (metaclass), and a context built with a wrong
%      control width is vital:badInput naming the channels.

    properties
        Sink
        Model
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            tc.Sink = ContextSink();
            twin = coreTwinFixture(1.5);
            probe = ContextProbeComponent('probe', twin.axis('cg'), tc.Sink);
            m = vital.AircraftModel('twin + context probe (I1 test fixture)', twin.Axes, [twin.Components, {probe}], ...
                twin.MassProps, twin.Controls, 'Ref', twin.Ref, 'Limits', twin.Limits);
            tc.Model = m.compile();
        end
    end

    methods (Test)
        function sameContextOnEveryFlatPath(tc)
            m = tc.Model; R = m.toRuntime();
            rng(91103);
            props = {'X', 'U', 'UVector', 'ControlNames', 'C_bn', 'H', 'Atm', 'Air', 'Env', 'StateLayout'};
            nBad = 0; nChecked = 0;
            for i = 1:5
                [x, u, env] = point();
                us = cell2struct(num2cell(u), m.Controls(:), 1);
                ref = vital.FlightContext(x, u, env, m.Controls, m.Ref);
                paths = {@() m.derivatives(x, u, env), @() m.derivativesObject(x, u, env), ...
                    @() vital.plant.derivatives(x, u, m, env), @() vital.plant.derivatives(x, u, R, env), ...
                    @() vital.plant.derivatives(x, us, m, env)};
                for p = 1:numel(paths)
                    tc.Sink.clear();
                    paths{p}();
                    tc.assertNotEmpty(tc.Sink.Contexts, sprintf('path %d gave the probe no context', p));
                    for k = 1:numel(tc.Sink.Contexts)
                        fl = tc.Sink.Contexts{k};
                        for f = props
                            ok = isprop(fl, f{1}) && isprop(ref, f{1}) && isequal(fl.(f{1}), ref.(f{1}));
                            if ~ok
                                nBad = nBad + 1;
                                tc.verifyFail(sprintf('state %d path %d: context field %s differs from the direct constructor', i, p, f{1}));
                            end
                            nChecked = nChecked + 1;
                        end
                        q = x(7:10);
                        indep = isequal(fl.X, x(:)) && isequal(fl.UVector, u(:)) && isequal(fl.Env, env) && ...
                            isequal(fl.C_bn, vital.frames.quat2dcm(q / norm(q))) && isequal(fl.H, -x(13)) && ...
                            isprop(fl, 'StateLayout') && strcmp(fl.StateLayout, 'flat13');
                        if ~indep
                            nBad = nBad + 1;
                            tc.verifyFail(sprintf('state %d path %d: context X/U/Env/C_bn/H/StateLayout not those of the state', i, p));
                        end
                    end
                end
            end
            tc.verifyExact(nBad, 0, 'REG', 'ADR-043: one way to fill a FlightContext (F-3)', ...
                'Quantity', sprintf('context fields differing (%d checked)', nChecked));
        end

        function rotatingContext(tc)
            sink = ContextSink();
            nm = nescAircraftModel('cannonball', struct());
            probe = ContextProbeComponent('probe', nm.axis('cg'), sink);
            m = vital.AircraftModel('cannonball + probe (I1 test fixture)', nm.Axes, [nm.Components, {probe}], nm.MassProps, {}, ...
                'Ref', nm.Ref);
            m = m.compile();
            K = vital.geo.constants('wgs84');
            env = struct('earth', 'wgs84', 'rotation', true, 'gravity', 'J2', 'wind_n', [3; -1; 0], ...
                'windGradient_n', [0; 0; 0], 'deltaT', 4);
            x = vital.eom.rotatingState(0.5, 0.3, 4000, [120; -20; 5], [0.1; -0.05; 0.7], [0.02; -0.01; 0.03], K);
            [~, y] = vital.plant.derivativesRotating(x, [], m.toRuntime(), env);
            tc.assertNotEmpty(sink.Contexts, 'the probe received no context on the rotating plant');
            fl = sink.Contexts{end};
            tc.verifyTrue(isequal(fl.X, x(:)), 'X = the rotating state');
            tc.verifyTrue(isprop(fl, 'StateLayout') && strcmp(fl.StateLayout, 'rotating13'), 'StateLayout rotating13');
            tc.verifyTrue(isequal(fl.Env, env), 'Env = the rotating env');
            tc.verifyExact([fl.H; fl.Atm.rho; fl.Air.V], [y.h; y.rho; y.V], 'REG', 'the plant''s own h, rho, V', ...
                'Quantity', 'context H, rho, V');
            tc.assertNotEmpty(fl.C_bn, 'C_bn filled on the rotating plant');
            tc.verifyTol(fl.C_bn, vital.frames.dcm321(y.phi, y.theta, y.psi), 1e-12, 'abs', 'ANALYTIC', ...
                '3-2-1 DCM of the Euler angles the plant reports', 'Quantity', 'context C_bn (rotating)', 'Unit', '-');
        end

        function noSecondConstructionPath(tc)
            mc = ?vital.FlightContext;
            names = {mc.MethodList.Name};
            for b = {'fromAirData', 'bridge', 'setBridge'}
                tc.verifyFalse(any(strcmp(names, b{1})), sprintf('vital.FlightContext.%s must be retired (one construction path)', b{1}));
            end
            m = tc.Model;
            [x, u, env] = point();
            try
                vital.FlightContext(x, u(1:4), env, m.Controls, m.Ref);
                tc.verifyFail('a 4-wide u for 5 channels must be refused');
            catch ex
                tc.verifyEqual(ex.identifier, 'vital:badInput');
                tc.verifyTrue(contains(ex.message, 'throttle_re'), ex.message);
            end
        end
    end
end

function [x, u, env] = point()
V = 100 + 150 * rand;
a = deg2rad(-5 + 20 * rand); b = deg2rad(-5 + 10 * rand);
v = V * [cos(a) * cos(b); sin(b); sin(a) * cos(b)];
q = randn(4, 1); q = q / norm(q);
x = [v; (rand(3, 1) - 0.5); q; 100 * randn(2, 1); -1000 - 5000 * rand];
u = [deg2rad(-5 + 10 * rand); deg2rad(-5 + 10 * rand); deg2rad(-5 + 10 * rand); rand; rand];
env = struct('g', 9.80665, 'wind_n', (rand(3, 1) - 0.5) * 10, 'deltaT', (rand - 0.5) * 20);
end
