classdef (TestTags = {'M4'}) tF16LoadsReport < vital.test.VitalTestCase
%TF16LOADSREPORT  M4: the force and moment breakdown of the F-16 shown to users
%   (vital.aircraft.f16.loadsReport, run_f16_loads).
%
%   The report splits the plant's total load into aero, thrust and gravity
%   rows (body axes, moments about the CG, lbf and ft lbf), plus aero lift,
%   drag and side force in wind axes. Every number must be traceable to the
%   plant: the rows must add up to the plant's own total, and at a trim that
%   total must be zero. A specified (untrimmed) state must never be labelled
%   a trim.
%   Checks (written before the implementation):
%     rows add to the plant total, and the total is ~0 at a trim
%     gravity row = W [-sin(theta) 0 cos(theta)], no moment (ANALYTIC)
%     aero row    = qbar S [CX CY CZ] and qbar S [b Cl, cbar Cm, b Cn] moved
%                   from the MRC (35 % MAC) to the CG (ANALYTIC)
%     wind-axis balance in level flight and in a climb (ANALYTIC)
%     specified state: accelerations = F/m and J\M at zero body rates (ANALYTIC)
%     status and reason of a failed trim are carried; bad input is refused

    properties
        AC
        Ft = 0.3048
        V = 565.6854
        H = 10013
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
        end
    end

    methods (Access = private)
        function W = weightLbf(tc, g_ftps2)
            k = vital.units.constants();
            W = tc.AC.mass / k.slug * g_ftps2;
        end
    end

    methods (Test)
        function rowsAddUpToPlantTotalAndTrimIsBalanced(tc)
            r = vital.aircraft.f16.loadsReport(tc.V, tc.H);
            tc.assertEqual(r.status, 'OK');
            tc.verifyTrue(r.trimmed, 'a solved trim is labelled trimmed');
            L = r.loads;
            parts = L{'Aero', :} + L{'Thrust', :} + L{'Gravity', :};
            W = tc.weightLbf(32.174); cbarFt = 11.32;
            tc.verifyTol(parts, L{'Total', :}, 1e-9 * W * cbarFt, 'abs', 'ANALYTIC', ...
                'aero + thrust + gravity = total', 'Quantity', 'load rows', 'Unit', 'lbf, ft lbf');
            k = vital.units.constants();
            tc.verifyTol(L{'Total', 1:3}.', r.si.F_b / k.lbf, 1e-9 * W, 'abs', 'ANALYTIC', ...
                'report total force = plant F_b', 'Quantity', 'total force', 'Unit', 'lbf');
            tc.verifyTol(L{'Total', 4:6}.', r.si.M_cg / (k.lbf * k.ft), 1e-9 * W * cbarFt, 'abs', 'ANALYTIC', ...
                'report total moment = plant M_cg', 'Quantity', 'total moment', 'Unit', 'ft lbf');
            tc.verifyTol(L{'Total', 1:3}, [0 0 0], 1e-6 * W, 'abs', 'ANALYTIC', ...
                'trim: forces balance', 'Quantity', 'total force at trim', 'Unit', 'lbf');
            tc.verifyTol(L{'Total', 4:6}, [0 0 0], 1e-6 * W * cbarFt, 'abs', 'ANALYTIC', ...
                'trim: moments about the CG balance', 'Quantity', 'total moment at trim', 'Unit', 'ft lbf');
        end

        function gravityRowIsTheWeight(tc)
            r = vital.aircraft.f16.loadsReport(tc.V, tc.H);
            W = tc.weightLbf(32.174);   % 637.1595 slug x 32.174 ft/s^2 (F16_inertia.dml)
            th = deg2rad(r.theta_deg);
            tc.verifyTol(r.weight_lbf, W, 1e-9 * W, 'abs', 'ANALYTIC', 'W = m g', 'Quantity', 'weight', 'Unit', 'lbf');
            tc.verifyTol(r.loads{'Gravity', 1:3}, W * [-sin(th) 0 cos(th)], 1e-9 * W, 'abs', 'ANALYTIC', ...
                'gravity in body axes, wings level', 'Quantity', 'gravity force', 'Unit', 'lbf');
            tc.verifyExact(r.loads{'Gravity', 4:6}, [0 0 0], 'ANALYTIC', 'gravity acts at the CG', ...
                'Quantity', 'gravity moment', 'Unit', 'ft lbf');
        end

        function aeroRowIsCoefficientsTimesQbarS(tc)
            r = vital.aircraft.f16.loadsReport(tc.V, tc.H);
            c = r.coeff; qS = r.qbar_psf * 300; b = 30; cbar = 11.32;
            F = qS * [c.CX c.CY c.CZ];
            M_mrc = qS * [b * c.Cl, cbar * c.Cm, b * c.Cn];
            d = (tc.AC.r_mrc - tc.AC.r_cg).' / tc.Ft;          % MRC relative to the CG, ft
            M_cg = M_mrc + cross(d, F);
            W = tc.weightLbf(32.174);
            tc.verifyTol(r.loads{'Aero', 1:3}, F, 1e-9 * W, 'abs', 'ANALYTIC', ...
                'F = qbar S C (F16_aero.dml)', 'Quantity', 'aero force', 'Unit', 'lbf');
            tc.verifyTol(r.loads{'Aero', 4:6}, M_cg, 1e-9 * W * cbar, 'abs', 'ANALYTIC', ...
                'M_cg = M_mrc + (r_mrc - r_cg) x F; MRC at 35 % MAC', 'Quantity', 'aero moment about CG', 'Unit', 'ft lbf');
            tc.verifyGreaterThan(abs(M_mrc(2) - M_cg(2)), 1, ...
                'the MRC-to-CG transfer is not negligible at 25 % MAC (a missing transfer must be visible)');
        end

        function windAxisBalanceLevelAndClimb(tc)
            for gam = [0 5]
                r = vital.aircraft.f16.loadsReport(600, tc.H, 'gamma_deg', gam);
                tc.assertEqual(r.status, 'OK');
                a = deg2rad(r.alpha_deg); g = deg2rad(gam);
                T = r.loads{'Thrust', 1:3};
                Tx_w = T(1) * cos(a) + T(3) * sin(a);            % thrust along the wind x axis
                Tz_w = -T(1) * sin(a) + T(3) * cos(a);           % thrust along the wind z axis
                W = r.weight_lbf;
                tc.verifyTol(r.drag_lbf, Tx_w - W * sin(g), 1e-6 * W, 'abs', 'ANALYTIC', ...
                    'steady flight: D = T_xw - W sin(gamma)', 'Quantity', sprintf('drag, gamma %g', gam), 'Unit', 'lbf');
                tc.verifyTol(r.lift_lbf, W * cos(g) + Tz_w, 1e-6 * W, 'abs', 'ANALYTIC', ...
                    'steady flight: L = W cos(gamma) + T_zw', 'Quantity', sprintf('lift, gamma %g', gam), 'Unit', 'lbf');
                tc.verifyTol(r.side_lbf, 0, 1e-6 * W, 'abs', 'ANALYTIC', 'symmetric flight: no side force', ...
                    'Quantity', 'side force', 'Unit', 'lbf');
            end
        end

        function specifiedStateGivesAccelerations(tc)
            r = vital.aircraft.f16.loadsReport(tc.V, tc.H, 'alpha_deg', 8, 'elevator_deg', 0, 'throttle_pct', 50);
            tc.verifyEqual(r.status, 'SPECIFIED');
            tc.verifyFalse(r.trimmed, 'a specified state is never labelled a trim');
            tc.verifyTol(r.alpha_deg, 8, 1e-12, 'abs', 'ANALYTIC', 'state as specified', 'Quantity', 'alpha', 'Unit', 'deg');
            k = vital.units.constants();
            F = r.loads{'Total', 1:3}.' * k.lbf; M = r.loads{'Total', 4:6}.' * k.lbf * k.ft;
            tc.verifyGreaterThan(norm(F) / k.lbf, 100, 'off-trim: forces do not balance');
            % zero body rates: vdot_b = F/m, J wdot = M exactly
            a = r.accel;
            tc.verifyTol([a.udot a.vdot a.wdot], (F / tc.AC.mass / tc.Ft).', 1e-9, 'abs', 'ANALYTIC', ...
                'v_b dot = F/m at omega = 0', 'Quantity', 'linear acceleration', 'Unit', 'ft/s2');
            tc.verifyTol([a.pdot a.qdot a.rdot], rad2deg(tc.AC.J \ M).', 1e-9, 'abs', 'ANALYTIC', ...
                'J omega dot = M at omega = 0', 'Quantity', 'angular acceleration', 'Unit', 'deg/s2');
        end

        function failedTrimIsReportedNotHidden(tc)
            r = vital.aircraft.f16.loadsReport(150, tc.H);
            tc.verifyEqual(r.status, 'INFEASIBLE');
            tc.verifyFalse(r.trimmed, 'an infeasible trim is not a trim');
            tc.verifySubstring(r.reason, 'stall-limited');
        end

        function printsBreakdownWithoutOutput(tc)
            txt = evalc('run_f16_loads');
            for s = {'Aero', 'Thrust', 'Gravity', 'Total', 'Lift', 'Drag', 'about the CG', 'status'}
                tc.verifySubstring(txt, s{1});
            end
            txt = evalc('run_f16_loads(565.6854, 10013, ''alpha_deg'', 8, ''elevator_deg'', 0, ''throttle_pct'', 50)');
            tc.verifySubstring(txt, 'NOT a trim');
        end

        function badInputRefused(tc)
            tc.verifyError(@() vital.aircraft.f16.loadsReport(-5, tc.H), 'vital:trim:badCondition');
            tc.verifyError(@() vital.aircraft.f16.loadsReport(tc.V, tc.H, 'alpha_deg', 5), 'vital:badInput');
            tc.verifyError(@() vital.aircraft.f16.loadsReport(tc.V, tc.H, 'alpha_deg', NaN, ...
                'elevator_deg', 0, 'throttle_pct', 50), 'vital:badInput');
        end
    end
end
