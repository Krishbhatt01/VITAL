classdef (TestTags = {'M6'}) tAeroScale < vital.test.VitalTestCase
%TAEROSCALE  M6: the 'AeroScale' option of vital.aircraft.f16.config, applied in
%   vital.aircraft.f16.loads, used by the pre-registered M6 mutations.
%
%   What each multiplier scales (terms of the generated NESC model
%   vital.models.f16.aero, F16_aero.dml; coefficients about the MRC at 35 % MAC):
%     Cm_q     the pitch-damping term of Cm only:  cm = cmt + cq2v*(Cm_q*cmq),
%              cq2v = cbar q/(2V). The q-dependent normal force (czq) and its
%              moment about the CG (arm 0.35 - CG fraction of cbar) are NOT scaled.
%     Cl_p     the roll-damping term of Cl only:   cl = cl1 + b2v*(Cl_p*clp*p + clr*r),
%              b2v = b/(2V).
%     Cnt_table  (named 'Cn_beta' until 2026-10-05) the static sideslip
%              yawing-moment table about the MRC only:
%              cn = Cnt_table*cnt + dcnda*dail + dcndr*drdr + b2v*(cnp*p + cnr*r),
%              cnt = sign(beta) absCn0(|beta|, alpha) (zero at beta = 0), i.e. the
%              whole beta dependence of Cn ABOUT THE MRC; the control and rate
%              terms are NOT scaled.
%   CORRECTION 2026-10-05 (review R2 M5): this header used to call the knob
%   "Cn_beta". It is not the airplane's directional stiffness: the moment about
%   the CG also contains the side-force transfer (cy0 = -0.02 beta(deg), arm
%   0.345 m at CG 25 %), so Cnt_table x 0.2 gives body N_beta x 0.335 at the
%   README trim, and Cm_q x 0.3 gives M_q,cg x 0.556 (the czq transfer).
%   These effective ratios are registered in tests/M6/tF16FqR2.m
%   (aeroScaleEffectiveDerivatives). The knob was renamed; the old name is
%   vital:badInput.
%   Default: all three equal 1, and loads must then be bit-identical to the
%   unscaled model (the existing M3-M5 tests are the wider guard).
%
%   PRE-REGISTERED expectations:
%   1. config() and config('AeroScale', struct('Cm_q',1,'Cl_p',1,'Cnt_table',1))
%      give bit-identical loads (isequal) at a general state (alpha 7 deg, beta
%      3 deg, p q r non-zero, all controls deflected), identical to a
%      configuration without the aeroScale field, and identical trims and
%      linearizations at the NESC README condition.
%   2. With s ~= 1, the coefficient changes are exactly (ANALYTIC, 1e-15 abs):
%      dCm = (s-1) cq2v cmq, dCl = (s-1) b2v clp p, dCn = (s-1) cnt, and every
%      other coefficient is unchanged (isequal).
%   3. An unknown multiplier name, a negative, a NaN or a non-scalar value is
%      vital:badInput.

    properties
        Ft = 0.3048
    end

    methods (Access = private)
        function [ad, u, h, atm] = generalState(tc)
            V = 180; al = deg2rad(7); be = deg2rad(3);
            v = V * [cos(al) * cos(be); sin(be); sin(al) * cos(be)];
            w = [0.4; -0.15; 0.25];
            h = 3000;
            atm = vital.env.atmosphereUS76(h);
            AC = vital.aircraft.f16.config();
            ad = vital.airdata.airData(v, w, eye(3), [0; 0; 0], atm, struct('b', AC.b, 'cbar', AC.cbar));
            u = [deg2rad(-2.5); deg2rad(4); deg2rad(-6); 0.4];
        end
    end

    methods (Test)
        function defaultIsBitIdentical(tc)
            ones3 = struct('Cm_q', 1, 'Cl_p', 1, 'Cnt_table', 1);
            AC1 = vital.aircraft.f16.config('AeroScale', ones3);
            AC = vital.aircraft.f16.config();
            [ad, u, h, atm] = tc.generalState();
            [F, M, I] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
            [F1, M1, I1] = vital.aircraft.f16.loads(ad, u, h, atm, AC1);
            AC0 = rmfield(AC, 'aeroScale');
            [F0, M0, I0] = vital.aircraft.f16.loads(ad, u, h, atm, AC0);
            c = 'ANALYTIC: pre-registration 1 (default AeroScale leaves the model unchanged)';
            tc.verifyExact({F1, M1, I1.coeff}, {F, M, I.coeff}, 'ANALYTIC', c, 'Quantity', 'loads, explicit ones vs default');
            tc.verifyExact({F0, M0, I0.coeff}, {F, M, I.coeff}, 'ANALYTIC', c, 'Quantity', 'loads, no aeroScale field vs default');
            env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            t = vital.trim.solve(AC, env, cond);
            t1 = vital.trim.solve(AC1, env, cond);
            tc.verifyExact([t1.x; t1.u], [t.x; t.u], 'ANALYTIC', c, 'Quantity', 'README trim');
            l = vital.linear.linearize(AC, env, t);
            l1 = vital.linear.linearize(AC1, env, t1);
            tc.verifyExact({l1.A, l1.B}, {l.A, l.B}, 'ANALYTIC', c, 'Quantity', 'README linearization');
        end

        function eachMultiplierScalesOnlyItsTerm(tc)
            [ad, u, h, atm] = tc.generalState();
            base = vital.aircraft.f16.config();
            [~, ~, I] = vital.aircraft.f16.loads(ad, u, h, atm, base);
            k = vital.units.constants();
            a = vital.models.f16.aero(struct('vt', ad.V / k.ft, 'alpha', rad2deg(ad.alpha), 'beta', rad2deg(ad.beta), ...
                'p', ad.w_air(1), 'q', ad.w_air(2), 'r', ad.w_air(3), 'el', rad2deg(u(1)), 'ail', rad2deg(u(2)), 'rdr', rad2deg(u(3))));
            tc.assertGreaterThan(abs(a.cnt), 1e-4, 'the state has a sideslip yawing moment');
            cases = {'Cm_q', 0.3, 5, (0.3 - 1) * a.cq2v * a.cmq; ...
                     'Cl_p', 0.4, 4, (0.4 - 1) * a.b2v * a.clp * a.p; ...
                     'Cnt_table', 0.2, 6, (0.2 - 1) * a.cnt};
            for j = 1:size(cases, 1)
                AC = vital.aircraft.f16.config('AeroScale', struct(cases{j, 1}, cases{j, 2}));
                [~, ~, Is] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
                d = Is.coeff - I.coeff;
                tc.verifyTol(d(cases{j, 3}), cases{j, 4}, 1e-15, 'abs', 'ANALYTIC', ...
                    sprintf('pre-registration 2: %s x %g scales only its own term of the NESC aero model', cases{j, 1}, cases{j, 2}), ...
                    'Quantity', ['coefficient change, ' cases{j, 1}]);
                others = setdiff(1:6, cases{j, 3});
                tc.verifyExact(Is.coeff(others), I.coeff(others), 'ANALYTIC', 'pre-registration 2: other coefficients unchanged', ...
                    'Quantity', ['other coefficients, ' cases{j, 1}]);
            end
        end

        function badAeroScaleRejected(tc)
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cn_r', 0.5)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cm_q', -0.3)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cl_p', NaN)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cl_p', [1 2])), 'vital:badInput');
        end
    end
end
