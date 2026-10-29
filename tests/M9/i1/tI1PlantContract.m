classdef (TestTags = {'M9', 'I1'}) tI1PlantContract < vital.test.VitalTestCase
%TI1PLANTCONTRACT  Increment I1 (ADR-043): the plant contract by name.
%   vital.plant.derivatives(x, u, aircraft, env) takes a vital.AircraftModel (the
%   aircraft itself; dispatch to its compiled path) or an AC struct (the legacy /
%   bridge format: nu = numel(AC.controlNames), default 4 = [de da dr throttle]);
%   u is a vector in the declared order or a struct by control name.
%
%   PRE-REGISTERED (written before the implementation):
%   1. f16ModelBitwiseOver1100States (REG, E = 0): f16 = vital.AircraftModel.fromData(
%      vital.aircraft.f16.data(...)) over the 1,100-state equivalence set (rng 91001,
%      the 11 configurations and random points of tests/M9/core/tCoreModel.m, copied
%      below): vital.plant.derivatives(x, u, f16, env) and
%      vital.plant.derivatives(x, u, f16.toRuntime(), env) equal
%      vital.plant.derivatives(x, u, vital.aircraft.f16.config(...), env) BIT FOR BIT
%      (isequal) in xdot and in every y field the struct path gives (V alpha beta mach
%      qbar h F_b M_cg outOfEnvelope F_aero M_aero F_prop M_prop coeff thrust_lbf
%      quatNorm phi theta psi p q r specificForce_b nz): max |difference| = 0. Every
%      struct-path y field must be PRESENT on the model path (finding F-8).
%   2. twinThroughPlant (REG, E = 0): the HYPOTHETICAL twin (tests/reference/
%      coreTwinFixture.m, 5 controls) on 40 seeded states: the plant with the model,
%      with twin.toRuntime() and with u as a struct by name all equal
%      twin.derivatives(x, u, env) bit for bit (xdot and every y field).
%   3. twinRefusesFourControls: a 4-wide u for the twin (model and toRuntime struct)
%      is vital:badInput and the message names the channels (throttle_le).
%   4. structWidthByControlNames: for vital.aircraft.f16.config() (controlNames
%      {de da dr throttle}) a 5-wide u is vital:badInput naming the channels; an AC
%      without controlNames takes exactly 4 (3 and 5 refused, 4 runs); u as a struct
%      by name equals the vector bit for bit; a struct with an unknown or a missing
%      name is vital:model:unknownControl.
%   5. uncompiledModelIsCompiled: an UNCOMPILED model (withComponentEnabled returns
%      one) through the plant equals the compiled model bit for bit (the plant
%      compiles; it never falls back to the object path).
%   6. rotatingPlantWidth: vital.plant.derivativesRotating with an AC that declares
%      controlNames refuses a u of another width (vital:badInput); the NESC vehicle
%      (controlNames {}) runs with u = []; a struct WITHOUT controlNames passes u
%      unchanged to its loadsFcn (the legacy contract, documented); a
%      vital.AircraftModel is accepted and equals its toRuntime struct bit for bit.

    properties
        Env
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            tc.Env = struct('g', 9.80665, 'wind_n', [1; -2; 0.5], 'deltaT', 5);
        end
    end

    methods (Test)
        function f16ModelBitwiseOver1100States(tc)
            rng(91001);
            cfgs = configurations();
            worst = 0; nTot = 0; nOut = 0; missing = {};
            for c = 1:numel(cfgs)
                o = cfgs{c};
                [dOpts, aOpts] = splitOpts(o);
                AC = vital.aircraft.f16.config(o{:});
                m = vital.AircraftModel.fromData(vital.aircraft.f16.data(dOpts{:}), aOpts{:});
                R = m.toRuntime();
                for i = 1:100
                    [x, u, env] = randomPoint();
                    [xs, ys] = vital.plant.derivatives(x, u, AC, env);
                    [xm, ym] = vital.plant.derivatives(x, u, m, env);
                    [xr, yr] = vital.plant.derivatives(x, u, R, env);
                    d = max(abs([xm - xs; xr - xs]));
                    if ~(isequal(xm, xs) && isequal(xr, xs)), d = max(d, realmin); end
                    for f = fieldnames(ys).'
                        if ~isfield(ym, f{1}) || ~isfield(yr, f{1})
                            missing{end+1} = f{1}; %#ok<AGROW>
                            continue
                        end
                        if ~(isequal(ym.(f{1}), ys.(f{1})) && isequal(yr.(f{1}), ys.(f{1})))
                            d = max([d; realmin; abs(double(ym.(f{1})(:)) - double(ys.(f{1})(:))); ...
                                abs(double(yr.(f{1})(:)) - double(ys.(f{1})(:)))]);
                        end
                    end
                    worst = max(worst, d);
                    nTot = nTot + 1; nOut = nOut + ys.outOfEnvelope;
                end
            end
            missing = unique(missing);
            fprintf('[tI1PlantContract] %d states (%d out of envelope): max |plant(model) - plant(config)| = %.3g; missing y: {%s}\n', ...
                nTot, nOut, worst, strjoin(missing, ', '));
            tc.verifyEmpty(missing, 'every y field of the struct path is present on the model path (F-8)');
            tc.verifyExact(worst, 0, 'REG', 'ADR-043 / I1 criterion: the model through the plant is the F-16 bit for bit', ...
                'Quantity', 'max |difference| over xdot and the shared y fields');
            tc.verifyExact(nTot, 1100, 'REG', 'the 1,100-state set', 'Quantity', 'states');
            tc.verifyWithin(nOut, 100, Inf, 'REG', 'non-vacuous: out-of-envelope states', 'Quantity', 'out-of-envelope states');
        end

        function twinThroughPlant(tc)
            rng(91101);
            twin = coreTwinFixture(1.5);
            R = twin.toRuntime();
            worst = 0;
            for i = 1:40
                [x, u4, env] = randomPoint();
                u = [u4; min(1.05, u4(4) + 0.3)];
                us = cell2struct(num2cell(u), twin.Controls(:), 1);
                [x0, y0] = twin.derivatives(x, u, env);
                [x1, y1] = vital.plant.derivatives(x, u, twin, env);
                [x2, y2] = vital.plant.derivatives(x, u, R, env);
                [x3, y3] = vital.plant.derivatives(x, us, twin, env);
                d = max(abs([x1 - x0; x2 - x0; x3 - x0]));
                if ~(isequal(x1, x0) && isequal(x2, x0) && isequal(x3, x0)), d = max(d, realmin); end
                if ~(isequal(y1, y0) && isequal(y2, y0) && isequal(y3, y0)), d = max(d, realmin); end
                worst = max(worst, d);
            end
            tc.verifyExact(worst, 0, 'REG', 'ADR-043: plant(model) = plant(toRuntime) = plant(u by name) = twin.derivatives', ...
                'Quantity', 'max |difference| over xdot and y (twin, 5 controls)');
        end

        function twinRefusesFourControls(tc)
            twin = coreTwinFixture(1.5);
            [x, u] = trimLikePoint();
            for a = {twin, twin.toRuntime()}
                ex = captureError(@() vital.plant.derivatives(x, u(1:4), a{1}, tc.Env));
                tc.verifyEqual(ex.identifier, 'vital:badInput');
                tc.verifyTrue(contains(ex.message, 'throttle_le'), ['the message names the channels: ' ex.message]);
            end
        end

        function structWidthByControlNames(tc)
            AC = vital.aircraft.f16.config();
            [x, u] = trimLikePoint();
            ex = captureError(@() vital.plant.derivatives(x, [u(1:4); 0], AC, tc.Env));
            tc.verifyEqual(ex.identifier, 'vital:badInput');
            tc.verifyTrue(contains(ex.message, 'throttle'), ['the message names the channels: ' ex.message]);
            A0 = rmfield(AC, 'controlNames');
            tc.verifyError(@() vital.plant.derivatives(x, u(1:3), A0, tc.Env), 'vital:badInput');
            tc.verifyError(@() vital.plant.derivatives(x, [u(1:4); 0], A0, tc.Env), 'vital:badInput');
            xa = vital.plant.derivatives(x, u(1:4), A0, tc.Env);
            [xb, yb] = vital.plant.derivatives(x, u(1:4), AC, tc.Env);
            us = struct('throttle', u(4), 'dr', u(3), 'de', u(1), 'da', u(2));
            [xc, yc] = vital.plant.derivatives(x, us, AC, tc.Env);
            xd = vital.plant.derivatives(x, us, A0, tc.Env);
            tc.verifyExact(xa, xb, 'REG', 'default nu = 4 (legacy [de da dr throttle])', 'Quantity', 'xdot without controlNames');
            tc.verifyExact(xc, xb, 'REG', 'u by name = u by position', 'Quantity', 'xdot, u as a struct');
            tc.verifyTrue(isequal(yc, yb), 'y with u as a struct = y with u as a vector');
            tc.verifyExact(xd, xb, 'REG', 'u by name with the legacy default names', 'Quantity', 'xdot, u struct, no controlNames');
            bad = us; bad.flaps = 0;
            tc.verifyError(@() vital.plant.derivatives(x, bad, AC, tc.Env), 'vital:model:unknownControl');
            tc.verifyError(@() vital.plant.derivatives(x, rmfield(us, 'dr'), AC, tc.Env), 'vital:model:unknownControl');
        end

        function uncompiledModelIsCompiled(tc)
            twin = coreTwinFixture(1.5);
            un = twin.withComponentEnabled('engine_re', true);
            tc.assertFalse(un.isCompiled(), 'withComponentEnabled returns an uncompiled model');
            rng(91102);
            worst = 0;
            for i = 1:10
                [x, u4, env] = randomPoint();
                u = [u4; 0.6];
                [xa, ya] = vital.plant.derivatives(x, u, un, env);
                [xb, yb] = twin.derivatives(x, u, env);
                d = max(abs(xa - xb));
                if ~isequal(xa, xb) || ~isequal(ya, yb), d = max(d, realmin); end
                worst = max(worst, d);
            end
            tc.verifyExact(worst, 0, 'REG', 'ADR-043: the plant compiles an uncompiled model (never the object path)', ...
                'Quantity', 'max |plant(uncompiled) - compiled|');
        end

        function rotatingPlantWidth(tc)
            K = vital.geo.constants('wgs84');
            envR = struct('earth', 'wgs84', 'rotation', true, 'gravity', 'J2', 'wind_n', [0; 0; 0], ...
                'windGradient_n', [0; 0; 0], 'deltaT', 0);
            x = vital.eom.rotatingState(0.6, -1.2, 3000, [150; 10; -3], [0.05; 0.04; 0.3], [0.01; 0.02; -0.01], K);
            AC = vital.aircraft.f16.config();
            u = [-0.03; 0.01; 0.0; 0.4];
            tc.verifyError(@() vital.plant.derivativesRotating(x, [u; 0], AC, envR), 'vital:badInput');
            tc.verifyError(@() vital.plant.derivativesRotating(x, u(1:3), AC, envR), 'vital:badInput');
            xd = vital.plant.derivativesRotating(x, u, AC, envR);
            tc.verifyTrue(all(isfinite(xd)), 'a 4-wide u runs for the F-16 config');
            V = vital.nesc.vehicle('cannonball');
            tc.verifyTrue(all(isfinite(vital.plant.derivativesRotating(x, [], V, envR))), 'NESC vehicle, u = []');
            L = rmfield(V, 'controlNames');
            L.loadsFcn = @(ad, uu, h, atm, A) recordU(uu);
            vital.plant.derivativesRotating(x, [7; 8; 9], L, envR);
            got = recordU();
            tc.verifyExact(got, [7; 8; 9], 'REG', 'legacy: no controlNames, u passed unchanged', 'Quantity', 'u seen by loadsFcn');
            f16 = vital.aircraft.f16.model();
            [xa, ya] = vital.plant.derivativesRotating(x, u, f16, envR);
            [xb, yb] = vital.plant.derivativesRotating(x, u, f16.toRuntime(), envR);
            [xc, yc] = vital.plant.derivativesRotating(x, u, AC, envR);
            tc.verifyExact(xa, xb, 'REG', 'model = its toRuntime struct (rotating plant)', 'Quantity', 'xdot rotating');
            tc.verifyTrue(isequal(ya, yb), 'y model = y toRuntime (rotating plant)');
            tc.verifyExact(xa, xc, 'REG', 'model = config (rotating plant; same arithmetic)', 'Quantity', 'xdot rotating vs config');
            tc.verifyExact([ya.F_aero; ya.M_aero_cg], [yc.F_aero; yc.M_aero_cg], 'REG', 'aero diagnostics, rotating plant', ...
                'Quantity', 'F_aero, M_aero_cg model vs config');
        end
    end
end

function [v, M, info] = recordU(u)
% with u: record it and return zero loads (a loadsFcn); without: the last u seen
persistent last
M = zeros(3, 1); info = struct('outOfEnvelope', false);
if nargin == 1
    last = u(:);
    v = zeros(3, 1);
    return
end
v = last;
end

function [x, u] = trimLikePoint()
x = [150; 2; 8; 0.01; 0.02; -0.01; vital.frames.eul2quat(0.05, 0.06, 0.4); 0; 0; -3000];
u = [-0.03; 0.01; 0.0; 0.4; 0.45];
end

function [dOpts, aOpts] = splitOpts(o)
% data options (CG, BFRP offset) and the model option (AeroScale)
dOpts = {}; aOpts = {};
for i = 1:2:numel(o)
    if strcmp(o{i}, 'AeroScale'), aOpts = [aOpts, o(i:i+1)]; else, dOpts = [dOpts, o(i:i+1)]; end %#ok<AGROW>
end
end

function cfgs = configurations()
% the 11 configurations of tests/M9/core/tCoreModel.m (copied; call after rng(91001))
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
% the random point of tests/M9/core/tCoreModel.m (copied)
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

function ex = captureError(fcn)
% the MException fcn raises (an 'i1:noError' one when it raises none)
try
    fcn();
    ex = MException('i1:noError', 'no error was raised');
catch ex
end
end
