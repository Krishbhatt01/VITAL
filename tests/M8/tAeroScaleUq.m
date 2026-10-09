classdef (TestTags = {'M8'}) tAeroScaleUq < vital.test.VitalTestCase
%TAEROSCALEUQ  M8: the AeroScale extension of vital.aircraft.f16.config /
%   vital.aircraft.f16.loads for the uncertainty analysis. New multipliers (each
%   scales ONE term of the generated NESC model, vital.models.f16.aero, about
%   the MRC at 35 % MAC, in the model's own order of operations):
%     Cm_table   the pitching-moment table cmt(el, alpha):
%                cm = Cm_table*cmt + cq2v*(Cm_q*cmq)
%     Cl_table   the static rolling-moment table clt(beta, alpha):
%                cl = (Cl_table*clt + dclda*dail + dcldr*drdr) + b2v*(Cl_p*clp*p + clr*r)
%     Cnr_table  the yaw-damping table cnr(alpha) (the plan's parameter "Cn_r";
%                the field name differs because tests/M6/tAeroScale.m uses
%                'Cn_r' as its unknown-name example; NOTES.md):
%                cn = (Cnt_table*cnt + dcnda*dail + dcndr*drdr) + b2v*(cnp*p + (Cnr_table*cnr)*r)
%   Every multiplier equal to 1 leaves the generated model untouched.
%
%   PRE-REGISTERED (with the stub, before any implementation):
%   1. DEFAULT PATH BIT-IDENTICAL (ANALYTIC/REG guard, as ADR ctrl-4):
%      config() equals config('AeroScale', all six = 1) (isequal), and both give
%      loads identical (isequal) to a configuration WITHOUT the aeroScale field
%      at a general state (alpha 7 deg, beta 3 deg, p q r non-zero, all
%      controls deflected), identical README trims and linearizations; the
%      augmented-aircraft evaluatePoint (vital.uq.augmentedBuilder) at the README
%      point is isequaln for f16Factory('Controller', b) and
%      f16Factory('AeroScale', all six = 1, 'Controller', b). config().aeroScale
%      has exactly the six fields Cm_q, Cl_p, Cnt_table, Cm_table, Cl_table,
%      Cnr_table, all 1.
%   2. EACH NEW MULTIPLIER SCALES ONLY ITS TERM (ANALYTIC, 1e-15 abs on the
%      coefficient change, every other coefficient isequal):
%      Cm_table s=1.13: dCm = (s-1) cmt;  Cl_table s=0.85: dCl = (s-1) clt;
%      Cnr_table s=0.7: dCn = (s-1) b2v cnr r.
%   3. MULTIPLIERS COMBINE (ANALYTIC, 1e-15 abs): Cm_q 0.8 with Cm_table 1.1:
%      cm = 1.1 cmt + cq2v 0.8 cmq; Cl_p 1.2 with Cl_table 0.9:
%      cl = (0.9 clt + dclda dail + dcldr drdr) + b2v (1.2 clp p + clr r);
%      Cnt_table 1.05 with Cnr_table 0.75: cn = (1.05 cnt + dcnda dail + dcndr drdr)
%      + b2v (cnp p + 0.75 cnr r). The old single multipliers keep their M6
%      meaning (tests/M6/tAeroScale.m is the guard).
%   4. FAILURE MODES: 'Cn_r' (still unknown), a negative Cm_table, a NaN
%      Cnr_table, a vector Cl_table -> vital:badInput.

    properties
        Ft = 0.3048
    end

    properties (Constant)
        ONES6 = struct('Cm_q', 1, 'Cl_p', 1, 'Cnt_table', 1, 'Cm_table', 1, 'Cl_table', 1, 'Cnr_table', 1)
    end

    methods (Access = private)
        function [ad, u, h, atm, a] = generalState(tc) %#ok<MANU>
            V = 180; al = deg2rad(7); be = deg2rad(3);
            v = V * [cos(al) * cos(be); sin(be); sin(al) * cos(be)];
            w = [0.4; -0.15; 0.25];
            h = 3000;
            atm = vital.env.atmosphereUS76(h);
            AC = vital.aircraft.f16.config();
            ad = vital.airdata.airData(v, w, eye(3), [0; 0; 0], atm, struct('b', AC.b, 'cbar', AC.cbar));
            u = [deg2rad(-2.5); deg2rad(4); deg2rad(-6); 0.4];
            k = vital.units.constants();
            a = vital.models.f16.aero(struct('vt', ad.V / k.ft, 'alpha', rad2deg(ad.alpha), 'beta', rad2deg(ad.beta), ...
                'p', ad.w_air(1), 'q', ad.w_air(2), 'r', ad.w_air(3), 'el', rad2deg(u(1)), 'ail', rad2deg(u(2)), 'rdr', rad2deg(u(3))));
        end
    end

    methods (Test)
        function defaultPathBitIdentical(tc)
            AC = vital.aircraft.f16.config();
            AC6 = vital.aircraft.f16.config('AeroScale', tc.ONES6);
            tc.verifyEqual(sort(fieldnames(AC.aeroScale)), sort(fieldnames(tc.ONES6)), 'six AeroScale fields');
            tc.verifyExact(AC6, AC, 'ANALYTIC', 'header 1: explicit ones = default', 'Quantity', 'AC');
            [ad, u, h, atm] = tc.generalState();
            [F, M, I] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
            [F0, M0, I0] = vital.aircraft.f16.loads(ad, u, h, atm, rmfield(AC, 'aeroScale'));
            tc.verifyExact({F, M, I.coeff}, {F0, M0, I0.coeff}, 'ANALYTIC', 'header 1: ones leave the model untouched', ...
                'Quantity', 'loads vs no aeroScale field');
            env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            t = vital.trim.solve(AC, env, cond);
            t0 = vital.trim.solve(rmfield(AC, 'aeroScale'), env, cond);
            tc.verifyExact([t.x; t.u], [t0.x; t0.u], 'ANALYTIC', 'header 1', 'Quantity', 'README trim');
            l = vital.linear.linearize(AC, env, t);
            l0 = vital.linear.linearize(rmfield(AC, 'aeroScale'), env, t0);
            tc.verifyExact({l.A, l.B}, {l0.A, l0.B}, 'ANALYTIC', 'header 1', 'Quantity', 'README linearization');
            b = vital.uq.augmentedBuilder();
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            c = vital.fq.gridPoints(Cr);
            f1 = vital.fq.f16Factory('Controller', b);
            f6 = vital.fq.f16Factory('AeroScale', tc.ONES6, 'Controller', b);
            P1 = vital.fq.evaluatePoint(f1(c), c);
            P6 = vital.fq.evaluatePoint(f6(c), c);
            tc.verifyEqual(P1.status, 'OK');
            tc.verifyTrue(isequaln(P6, P1), 'header 1: augmented evaluatePoint unchanged by unit multipliers');
        end

        function eachNewMultiplierScalesOnlyItsTerm(tc)
            [ad, u, h, atm, a] = tc.generalState();
            [~, ~, I] = vital.aircraft.f16.loads(ad, u, h, atm, vital.aircraft.f16.config());
            tc.assertGreaterThan(abs(a.clt), 1e-4, 'the state has a sideslip rolling moment');
            tc.assertGreaterThan(abs(a.cnr * a.r), 1e-5, 'the state has a yaw-damping moment');
            cases = {'Cm_table', 1.13, 5, (1.13 - 1) * a.cmt; ...
                     'Cl_table', 0.85, 4, (0.85 - 1) * a.clt; ...
                     'Cnr_table', 0.7, 6, (0.7 - 1) * a.b2v * a.cnr * a.r};
            for j = 1:size(cases, 1)
                AC = vital.aircraft.f16.config('AeroScale', struct(cases{j, 1}, cases{j, 2}));
                [~, ~, Is] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
                d = Is.coeff - I.coeff;
                tc.verifyTol(d(cases{j, 3}), cases{j, 4}, 1e-15, 'abs', 'ANALYTIC', ...
                    sprintf('header 2: %s x %g scales only its own term', cases{j, 1}, cases{j, 2}), ...
                    'Quantity', ['coefficient change, ' cases{j, 1}]);
                others = setdiff(1:6, cases{j, 3});
                tc.verifyExact(Is.coeff(others), I.coeff(others), 'ANALYTIC', 'header 2: other coefficients unchanged', ...
                    'Quantity', ['other coefficients, ' cases{j, 1}]);
            end
        end

        function multipliersCombine(tc)
            [ad, u, h, atm, a] = tc.generalState();
            AC = vital.aircraft.f16.config('AeroScale', struct('Cm_q', 0.8, 'Cm_table', 1.1, 'Cl_p', 1.2, 'Cl_table', 0.9, ...
                'Cnt_table', 1.05, 'Cnr_table', 0.75));
            [~, ~, I] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
            cm = 1.1 * a.cmt + a.cq2v * (0.8 * a.cmq);
            cl = (0.9 * a.clt + a.dclda * a.dail + a.dcldr * a.drdr) + a.b2v * (1.2 * a.clp * a.p + a.clr * a.r);
            cn = (1.05 * a.cnt + a.dcnda * a.dail + a.dcndr * a.drdr) + a.b2v * (a.cnp * a.p + 0.75 * a.cnr * a.r);
            tc.verifyTol(I.coeff(4:6), [cl cm cn], 1e-15, 'abs', 'ANALYTIC', 'header 3: combined multipliers', ...
                'Quantity', 'Cl Cm Cn');
            tc.verifyExact(I.coeff(1:3), [a.cx a.cy a.cz], 'ANALYTIC', 'header 3: forces unchanged', 'Quantity', 'CX CY CZ');
        end

        function badNewMultipliers(tc)
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cn_r', 0.5)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cm_table', -0.1)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cnr_table', NaN)), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cl_table', [1 2])), 'vital:badInput');
        end
    end
end
