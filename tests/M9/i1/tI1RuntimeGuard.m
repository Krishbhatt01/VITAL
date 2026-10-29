classdef (TestTags = {'M9', 'I1'}) tI1RuntimeGuard < vital.test.VitalTestCase
%TI1RUNTIMEGUARD  Increment I1 (ADR-043): a struct made by AircraftModel.toRuntime()
%   is a BRIDGE to the model, never the place where truth lives. The plant
%   evaluates the model it came from, so an edit of one of its physical fields
%   would be silently ignored; the plant refuses it instead.
%
%   PRE-REGISTERED (written before the implementation):
%   1. editsRaiseStaleRuntime: on f16.toRuntime() (F-16, fromData) editing any of
%      S, b, cbar, mass, J, r_cg, r_mrc, aeroScale (one multiplier), controlNames
%      or loadsFcn makes vital.plant.derivatives raise vital:model:staleRuntime; the
%      same for the twin's toRuntime struct (S, mass, controlNames) and, for the
%      rotating plant, an edit of S or mass of the F-16 struct.
%   2. uneditedRuns: the unedited struct runs; an edit undone (field set back to
%      its value) runs again (a fingerprint comparison, not a one-way flag); an
%      edit of a NON-physical field (limits, name) is allowed and changes nothing
%      (xdot bit for bit).
%   3. configUnaffected: vital.aircraft.f16.config() (not made by toRuntime) has no
%      guard: AC.S edited runs, and the xdot changes (the legacy struct path
%      really reads AC.S).
%   4. noRuntimeAeroScaleField: a model without aeroScale (the twin's Meta has
%      none) refuses a struct to which an aeroScale field was ADDED (it would be
%      silently ignored).

    properties
        Env
        X
        U
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            tc.Env = struct('g', 9.80665, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tc.X = [150; 2; 8; 0.01; 0.02; -0.01; vital.frames.eul2quat(0.05, 0.06, 0.4); 0; 0; -3000];
            tc.U = [-0.03; 0.01; 0.0; 0.4];
        end
    end

    methods (Test)
        function editsRaiseStaleRuntime(tc)
            R = vital.aircraft.f16.model().toRuntime();
            edits = {
                'S',            @(A) setf(A, 'S', A.S * 1.01)
                'b',            @(A) setf(A, 'b', A.b + 0.1)
                'cbar',         @(A) setf(A, 'cbar', A.cbar * 0.99)
                'mass',         @(A) setf(A, 'mass', A.mass + 1)
                'J',            @(A) setf(A, 'J', A.J * 1.001)
                'r_cg',         @(A) setf(A, 'r_cg', A.r_cg + [0.01; 0; 0])
                'r_mrc',        @(A) setf(A, 'r_mrc', A.r_mrc + [0; 0; 0.01])
                'aeroScale',    @(A) setf(A, 'aeroScale', setf(A.aeroScale, 'Cm_q', 0.5))
                'controlNames', @(A) setf(A, 'controlNames', {'de', 'da', 'dr', 'thr'})
                'loadsFcn',     @(A) setf(A, 'loadsFcn', @vital.aircraft.f16.loads)};
            for k = 1:size(edits, 1)
                A = edits{k, 2}(R);
                tc.verifyError(@() vital.plant.derivatives(tc.X, tc.U, A, tc.Env), 'vital:model:staleRuntime', ...
                    ['F-16 toRuntime struct with ' edits{k, 1} ' edited']);
            end
            T = coreTwinFixture(1.5).toRuntime();
            u5 = [tc.U; 0.4];
            tc.verifyError(@() vital.plant.derivatives(tc.X, u5, setf(T, 'S', T.S + 1), tc.Env), 'vital:model:staleRuntime', 'twin S');
            tc.verifyError(@() vital.plant.derivatives(tc.X, u5, setf(T, 'mass', T.mass - 1), tc.Env), 'vital:model:staleRuntime', 'twin mass');
            tc.verifyError(@() vital.plant.derivatives(tc.X, u5, setf(T, 'controlNames', fliplr(T.controlNames)), tc.Env), ...
                'vital:model:staleRuntime', 'twin controlNames reordered');
            K = vital.geo.constants('wgs84');
            envR = struct('earth', 'wgs84', 'rotation', true, 'gravity', 'J2', 'wind_n', [0; 0; 0], ...
                'windGradient_n', [0; 0; 0], 'deltaT', 0);
            xr = vital.eom.rotatingState(0.6, -1.2, 3000, [150; 10; -3], [0.05; 0.04; 0.3], [0.01; 0.02; -0.01], K);
            tc.verifyError(@() vital.plant.derivativesRotating(xr, tc.U, setf(R, 'S', R.S * 2), envR), 'vital:model:staleRuntime', 'rotating S');
            tc.verifyError(@() vital.plant.derivativesRotating(xr, tc.U, setf(R, 'mass', R.mass * 2), envR), 'vital:model:staleRuntime', 'rotating mass');
        end

        function uneditedRuns(tc)
            R = vital.aircraft.f16.model().toRuntime();
            x0 = vital.plant.derivatives(tc.X, tc.U, R, tc.Env);
            A = setf(R, 'S', R.S * 1.5);
            A = setf(A, 'S', R.S);
            x1 = vital.plant.derivatives(tc.X, tc.U, A, tc.Env);
            tc.verifyExact(x1, x0, 'REG', 'an edit undone is no longer stale', 'Quantity', 'xdot after S restored');
            A = setf(R, 'limits', setf(R.limits, 'alpha_deg', [-5 20]));
            A = setf(A, 'name', 'renamed');
            x2 = vital.plant.derivatives(tc.X, tc.U, A, tc.Env);
            tc.verifyExact(x2, x0, 'REG', 'limits and name are not physics of the plant', 'Quantity', 'xdot after limits/name edit');
        end

        function configUnaffected(tc)
            AC = vital.aircraft.f16.config();
            x0 = vital.plant.derivatives(tc.X, tc.U, AC, tc.Env);
            x1 = vital.plant.derivatives(tc.X, tc.U, setf(AC, 'S', AC.S * 1.1), tc.Env);
            tc.verifyTrue(any(x1 ~= x0), 'the legacy struct path reads AC.S (no guard on config())');
        end

        function noRuntimeAeroScaleField(tc)
            T = coreTwinFixture(1.5).toRuntime();
            tc.assertFalse(isfield(T, 'aeroScale'), 'the twin model declares no aeroScale');
            u5 = [tc.U; 0.4];
            tc.verifyTrue(all(isfinite(vital.plant.derivatives(tc.X, u5, T, tc.Env))), 'unedited twin struct runs');
            tc.verifyError(@() vital.plant.derivatives(tc.X, u5, setf(T, 'aeroScale', struct('Cm_q', 0.5)), tc.Env), ...
                'vital:model:staleRuntime', 'aeroScale added to a struct whose model has none');
        end
    end
end

function s = setf(s, f, v)
s.(f) = v;
end
