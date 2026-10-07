classdef (TestTags = {'M1'}) tAirData < vital.test.VitalTestCase
%TAIRDATA  M1: air-relative velocity, alpha/beta, dynamic pressure, Mach,
%   vane kinematics and CAS/EAS/TAS (CONVENTIONS.md section 5).

    properties
        Ref = struct('b', 10, 'cbar', 2)
    end

    methods (Test)
        function alphaBetaQbarMach(tc)
            atm = vital.env.atmosphereUS76(0);
            v = [100; 5; 10];
            ad = vital.airdata.airData(v, [0;0;0], eye(3), [0;0;0], atm, tc.Ref);
            V = norm(v);
            tc.verifyTol(ad.V, V, 1e-12, 'abs', 'ANALYTIC', '|v_air|', 'Quantity', 'V', 'Unit', 'm/s');
            tc.verifyTol(ad.alpha, atan2(10, 100), 1e-15, 'abs', 'ANALYTIC', 'alpha = atan2(w,u)', 'Quantity', 'alpha', 'Unit', 'rad');
            tc.verifyTol(ad.beta, asin(5/V), 1e-15, 'abs', 'ANALYTIC', 'beta = asin(v/V)', 'Quantity', 'beta', 'Unit', 'rad');
            tc.verifyTol(ad.qbar, 0.5*atm.rho*V^2, 1e-12, 'rel', 'ANALYTIC', 'qbar = rho V^2 / 2', 'Quantity', 'qbar', 'Unit', 'Pa');
            tc.verifyTol(ad.mach, V/atm.a, 1e-12, 'rel', 'ANALYTIC', 'M = V/a', 'Quantity', 'Mach');
        end

        function nondimensionalRates(tc)
            atm = vital.env.atmosphereUS76(0);
            ad = vital.airdata.airData([50;0;0], [0.1;0.2;0.3], eye(3), [0;0;0], atm, tc.Ref);
            tc.verifyTol([ad.phat; ad.qhat; ad.rhat], [0.1*10/100; 0.2*2/100; 0.3*10/100], 1e-15, 'abs', 'ANALYTIC', ...
                'phat = pb/2V, qhat = q cbar/2V, rhat = rb/2V', 'Quantity', '[phat qhat rhat]');
        end

        function tailwindReducesAirspeedExactly(tc)
            atm = vital.env.atmosphereUS76(0);
            ad = vital.airdata.airData([100;0;0], [0;0;0], eye(3), [10;0;0], atm, tc.Ref);   % heading north, wind toward north
            tc.verifyTol(ad.V, 90, 1e-12, 'abs', 'ANALYTIC', 'v_air = v - C_bn w_n: 10 m/s tailwind', 'Quantity', 'V', 'Unit', 'm/s');
        end

        function windIsRotatedIntoBodyAxes(tc)
            atm = vital.env.atmosphereUS76(0);
            C = vital.frames.dcm321(0, 0, pi/2);                      % heading east
            ad = vital.airdata.airData([100;0;0], [0;0;0], C, [0;-20;0], atm, tc.Ref);  % wind toward west = headwind
            tc.verifyTol(ad.v_air, [120;0;0], 1e-12, 'abs', 'ANALYTIC', 'headwind adds to airspeed after rotation into body axes', ...
                'Quantity', 'v_air', 'Unit', 'm/s');
        end

        function vaneAnglesAreExactKinematics(tc)
            % Arbitrary flow and rates: vaneAngles equals the flow angles of v + w x r computed by hand.
            v = [60*cos(0.05)*cos(0.02); 60*sin(0.02); 60*sin(0.05)*cos(0.02)];
            w = [0.2; 0.25; -0.15];  r = [3; 0; 2];
            vl = v + [w(2)*r(3) - w(3)*r(2); w(3)*r(1) - w(1)*r(3); w(1)*r(2) - w(2)*r(1)];
            [av, bv] = vital.airdata.vaneAngles(v, w, r);
            tc.verifyTol(av, atan2(vl(3), vl(1)), 1e-15, 'abs', 'ANALYTIC', 'local velocity v + w x r', 'Quantity', 'alpha_v', 'Unit', 'rad');
            tc.verifyTol(bv, asin(vl(2)/norm(vl)), 1e-15, 'abs', 'ANALYTIC', 'local velocity v + w x r', 'Quantity', 'beta_v', 'Unit', 'rad');
        end

        function vaneCorrectionSignsE1(tc)
            % Sign convention of the linear vane corrections (CONVENTIONS 5, correction E1).
            % The linear forms are the first-order expansion ABOUT alpha = beta = 0; away from
            % zero they omit terms of order alpha*q*z_v/V, so the sign check is made at
            % alpha = beta = 0 with small rates, where the residual is second order,
            % (q x_v/V)^2 ~ 1e-6.
            V = 60; v = [V; 0; 0];
            w = [0.02; 0.025; -0.015];  r = [3; 0; 2];
            [av, bv] = vital.airdata.vaneAngles(v, w, r);
            linA = -w(2)*r(1)/V;                  linB = w(3)*r(1)/V - w(1)*r(3)/V;
            guideA = +w(2)*r(1)/V;                guideB = -w(3)*r(1)/V + w(1)*r(3)/V;
            tc.verifyTol(av, linA, 1e-5, 'abs', 'ANALYTIC', 'alpha_v = alpha - q x_v / V (corrected E1), second-order residual', 'Quantity', 'alpha_v', 'Unit', 'rad');
            tc.verifyTol(bv, linB, 1e-5, 'abs', 'ANALYTIC', 'beta_v = beta + r x_v / V - p z_v / V (corrected E1), second-order residual', 'Quantity', 'beta_v', 'Unit', 'rad');
            tc.verifyGreaterThan(abs(av - guideA), 100*abs(av - linA), 'the guide v2 alpha-vane sign must be rejected');
            tc.verifyGreaterThan(abs(bv - guideB), 100*abs(bv - linB), 'the guide v2 beta-vane sign must be rejected');
        end

        function seaLevelCasEqualsTas(tc)
            atm = vital.env.atmosphereUS76(0);
            [cas, eas] = vital.airdata.tasToCasEas(150, atm);
            tc.verifyTol(cas, 150, 1e-12, 'rel', 'ANALYTIC', 'CAS = TAS at sea level ISA', 'Quantity', 'CAS', 'Unit', 'm/s');
            tc.verifyTol(eas, 150, 1e-12, 'rel', 'ANALYTIC', 'EAS = TAS at sea level ISA', 'Quantity', 'EAS', 'Unit', 'm/s');
        end

        function casEasMatchCorrectairspeed(tc)
            h = [0 3000 6000 10000]; tas = [60 120 180 240];
            worstC = 0; worstE = 0;
            for i = 1:numel(h)
                atm = vital.env.atmosphereUS76(h(i));
                for v = tas
                    if v/atm.a >= 0.95, continue; end
                    [cas, eas] = vital.airdata.tasToCasEas(v, atm);
                    ct = correctairspeed(v, atm.a, atm.p, 'TAS', 'CAS', 'Equation');
                    et = correctairspeed(v, atm.a, atm.p, 'TAS', 'EAS', 'Equation');
                    worstC = max(worstC, abs(cas/ct - 1)); worstE = max(worstE, abs(eas/et - 1));
                end
            end
            c = 'Aerospace Toolbox correctairspeed(...,''Equation'')';
            tc.verifyTol(worstC, 0, 1e-6, 'abs', 'INDEP', c, 'Quantity', 'max relative CAS error');
            tc.verifyTol(worstE, 0, 1e-6, 'abs', 'INDEP', c, 'Quantity', 'max relative EAS error');
        end
    end
end
