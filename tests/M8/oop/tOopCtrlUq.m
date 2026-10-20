classdef (TestTags = {'M8', 'OOP'}) tOopCtrlUq < vital.test.VitalTestCase
%TOOPCTRLUQ  0.8.1-OOP: vital.ctrl.ControlLaw (wrapping the M7 laws), the
%   vital.atmos.Atmosphere abstraction and vital.uq.Study (ADR-037).
%   PRE-REGISTERED (written before the classes existed):
%   1. PitchSasLaw / YawDamperLaw / NescLqrLaw .build(AC, env, tr) give a
%      controller whose step output at a perturbed state and whose info equal
%      (isequal) those of vital.ctrl.pitchSas / yawDamper / nescLqr with the same
%      gains; CombinedLaw equals vital.ctrl.combine. law.builder() is a handle
%      accepted by vital.fq.f16Factory('Controller', ...).
%   2. ControlLaw is abstract (cannot be instantiated); non-finite gains ->
%      vital:badInput (from the core law, at build time) .
%   3. IsaAtmosphere('DeltaT', dT).at(h) equals vital.env.atmosphere(h, 'DeltaT', dT)
%      (isequal); Atmosphere is abstract.
%   4. vital.uq.Study forwards its options to run_f16_uq unchanged (an injected
%      entry point receives exactly the name-value list); an unknown option errors.

    properties
        AC
        Env
        Tr
        X
        Y
        Uref
    end

    methods (TestClassSetup)
        function trimReadme(tc)
            a = vital.Aircraft();
            fc = vital.FlightCondition.fromFeet(565.6854, 10013);
            tc.AC = a.toRuntime(); tc.Env = fc.toEnv();
            tc.Tr = vital.trim.solve(tc.AC, tc.Env, fc.toTrimCond());
            x = tc.Tr.x; x(3) = x(3) + 0.5; x(5) = x(5) + 0.02; x(2) = x(2) + 0.4; x(6) = x(6) + 0.03;
            tc.X = x; tc.Uref = tc.Tr.u + [0; 0.01; 0; 0];
            [~, tc.Y] = vital.plant.derivatives(x, tc.Uref, tc.AC, tc.Env);
        end
    end

    methods (Test)
        function lawsEqualFunctional(tc)
            pairs = {vital.ctrl.PitchSasLaw('Kq', 0.2, 'Ka', 0.5), @(A, e, t) vital.ctrl.pitchSas(A, e, t, 'Kq', 0.2, 'Ka', 0.5); ...
                     vital.ctrl.YawDamperLaw('Kr', 0.5, 'Kari', 0.1), @(A, e, t) vital.ctrl.yawDamper(A, e, t, 'Kr', 0.5, 'Kari', 0.1); ...
                     vital.ctrl.NescLqrLaw(), @(A, e, t) vital.ctrl.nescLqr(A, e, t)};
            for k = 1:size(pairs, 1)
                law = pairs{k, 1};
                tc.verifyTrue(isa(law, 'vital.ctrl.ControlLaw'));
                c = law.build(tc.AC, tc.Env, tc.Tr);
                c0 = pairs{k, 2}(tc.AC, tc.Env, tc.Tr);
                tc.verifyEqual(c.info, c0.info);
                tc.verifyEqual(c.rate_hz, c0.rate_hz);
                u = c.step(0, tc.X, tc.Y, tc.Uref, c.init);
                u0 = c0.step(0, tc.X, tc.Y, tc.Uref, c0.init);
                tc.verifyExact(u, u0, 'ANALYTIC', 'delegation to the M7 law', 'Quantity', [class(law) ' step']);
            end
            comb = vital.ctrl.CombinedLaw(pairs{1, 1}, pairs{2, 1});
            c = comb.build(tc.AC, tc.Env, tc.Tr);
            c0 = vital.ctrl.combine(pairs{1, 2}(tc.AC, tc.Env, tc.Tr), pairs{2, 2}(tc.AC, tc.Env, tc.Tr));
            u = c.step(0, tc.X, tc.Y, tc.Uref, c.init);
            u0 = c0.step(0, tc.X, tc.Y, tc.Uref, c0.init);
            tc.verifyExact(u, u0, 'ANALYTIC', 'delegation to vital.ctrl.combine', 'Quantity', 'combined step');
            b = pairs{1, 1}.builder();
            tc.verifyClass(b, 'function_handle');
            fac = vital.fq.f16Factory('Controller', b);
            ac = fac(struct('h_ft', 10013, 'V_ftps', 565.6854, 'cg_pct_mac', 25));
            tc.verifyTrue(isfield(ac, 'controllerFcn'));
        end

        function lawValidation(tc)
            tc.verifyError(@() vital.ctrl.ControlLaw(), 'MATLAB:class:abstract');
            law = vital.ctrl.PitchSasLaw('Kq', NaN);
            tc.verifyError(@() law.build(tc.AC, tc.Env, tc.Tr), 'vital:badInput');
        end

        function atmosphereObjects(tc)
            h = [0 3000 11000];
            A = vital.atmos.IsaAtmosphere('DeltaT', 10);
            tc.verifyTrue(isa(A, 'vital.atmos.Atmosphere'));
            tc.verifyEqual(A.at(h), vital.env.atmosphere(h, 'DeltaT', 10));
            tc.verifyEqual(vital.atmos.IsaAtmosphere().at(h), vital.env.atmosphere(h));
            tc.verifyError(@() vital.atmos.Atmosphere(), 'MATLAB:class:abstract');
            tc.verifyError(@() vital.atmos.IsaAtmosphere().at(1e6), 'vital:env:altitudeOutOfRange');
        end

        function studyForwardsOptions(tc)
            s = vital.uq.Study('Label', 'oop', 'NumLHS', 8, 'Groups', {'3.2.2.1.2-CatA'});
            tc.verifyEqual(s.Options.NumLHS, 8);
            s.EntryPoint = @(varargin) varargin;
            out = s.run();
            tc.verifyEqual(out, {'Label', 'oop', 'NumLHS', 8, 'Groups', {'3.2.2.1.2-CatA'}});
            tc.verifyEqual(func2str(vital.uq.Study().EntryPoint), 'run_f16_uq');
            tc.verifyError(@() vital.uq.Study('NotAnOption', 1), 'vital:badInput');
        end
    end
end
