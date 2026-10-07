classdef (TestTags = {'M5'}) tF16Modes < vital.test.VitalTestCase
%TF16MODES  M5-A: flight modes of the NESC F-16 and the user entry point
%   run_f16_modes.
%
%   There is NO published F-16 eigenvalue source available to VITAL, so every
%   F-16 mode value here is REG (a pre-registered expectation), never PUB.
%
%   PRE-REGISTERED expectations (written BEFORE any F-16 mode was computed):
%   1. NESC README trim (565.6854 ft/s, 10,013 ft, CG 25 % MAC, g = 32.174
%      ft/s^2): all five classic modes, each exactly once with status OK:
%      short_period (pair), phugoid (pair), dutch_roll (pair), roll (real),
%      spiral (real).
%   2. Participation structure (participation factors over u v w p q r phi theta):
%        short period  p_w + p_q >= 0.7        phugoid  p_u + p_theta >= 0.7
%        Dutch roll    p_v + p_r > p_p + p_phi roll     p_p is the largest
%        spiral        p_phi is the largest
%   3. Plausibility bands (REG: hand estimates from the NESC tables at this
%      trim, e.g. M_alpha ~ -6 1/s^2, Z_alpha/V ~ -0.85 1/s -> SP wn ~ 2.6 rad/s,
%      zeta ~ 0.35; N_beta ~ 8 1/s^2 -> DR wn ~ 2.9 rad/s; L_p ~ -3 1/s; phugoid
%      period ~ pi sqrt(2) V/g ~ 78 s; widened to allow for the terms omitted):
%        SP  wn in [1.5, 8] rad/s, zeta in [0.2, 1.0]
%        phugoid period in [20, 200] s, |zeta| <= 0.3
%        DR  wn in [1, 6] rad/s, zeta in [0, 0.5]
%        roll tau in [0.1, 1.5] s;   spiral |lambda| <= 0.1 1/s
%   4. Trends: CG aft (25 -> 30 % MAC, same V and h) lowers the SP natural
%      frequency, or makes the SP non-oscillatory; higher speed at the same
%      altitude (565.6854 -> 700 ft/s) raises it.
%   5. n_alpha > 0 and in [5, 30] per rad (REG: qbar S CL_alpha / W ~ 13/rad).
%   6. run_f16_modes prints a table with every mode name, wn, zeta and the
%      statuses; a non-OK trim (150 ft/s, stall-limited INFEASIBLE) is reported
%      and NOT linearized (no modes returned).

    properties
        Ft = 0.3048
    end

    methods (Access = private)
        function [m, lin] = f16Modes(tc, V_ftps, cg)
            r = run_f16_modes(V_ftps, 10013, 'CG', cg);
            tc.assertEqual(r.status, 'OK', r.reason);
            m = r.modes; lin = r.lin;
        end
    end

    methods (Static, Access = private)
        function e = byName(m, name)
            e = m(strcmp({m.name}, name));
        end

        function i = idx(name)
            i = find(strcmp({'u','v','w','p','q','r','phi','theta'}, name));
        end
    end

    methods (Test)
        function readmeTrimHasFiveClassicModes(tc)
            [m, lin] = tc.f16Modes(565.6854, 25);
            c = 'REG: pre-registered expectation 1 (class header); no published F-16 eigenvalues';
            tc.verifyExact(sort({m.name}), sort({'short_period','phugoid','dutch_roll','roll','spiral'}), 'REG', c, ...
                'Quantity', 'mode names');
            tc.verifyExact(unique({m.status}), {'OK'}, 'REG', c, 'Quantity', 'mode statuses');
            tc.verifyExact([tF16Modes.byName(m, 'short_period').oscillatory, tF16Modes.byName(m, 'phugoid').oscillatory, ...
                tF16Modes.byName(m, 'dutch_roll').oscillatory], [true true true], 'REG', c, 'Quantity', 'pairs');
            tc.verifyTrue(lin.n_alpha > 0, 'n_alpha > 0');
            tc.verifyWithin(lin.n_alpha, 5, 30, 'REG', 'expectation 5: qbar S CL_alpha / W ~ 13 /rad', ...
                'Quantity', 'n_alpha', 'Unit', '1/rad');
        end

        function participationStructure(tc)
            m = tc.f16Modes(565.6854, 25);
            P = @(n, s) sum(tF16Modes.byName(m, n).participation(cellfun(@tF16Modes.idx, s)));
            c = 'REG: pre-registered expectation 2 (class header)';
            tc.verifyWithin(P('short_period', {'w','q'}), 0.7, 1, 'REG', c, 'Quantity', 'SP p_w + p_q');
            tc.verifyWithin(P('phugoid', {'u','theta'}), 0.7, 1, 'REG', c, 'Quantity', 'phugoid p_u + p_theta');
            tc.verifyWithin(P('dutch_roll', {'v','r'}) - P('dutch_roll', {'p','phi'}), 0, 1, 'REG', c, ...
                'Quantity', 'DR (p_v + p_r) - (p_p + p_phi)');
            r = tF16Modes.byName(m, 'roll'); [~, k] = max(r.participation);
            tc.verifyExact(k, tF16Modes.idx('p'), 'REG', c, 'Quantity', 'roll: largest participation state');
            s = tF16Modes.byName(m, 'spiral'); [~, k] = max(s.participation);
            tc.verifyExact(k, tF16Modes.idx('phi'), 'REG', c, 'Quantity', 'spiral: largest participation state');
        end

        function plausibilityBands(tc)
            m = tc.f16Modes(565.6854, 25);
            c = 'REG: pre-registered expectation 3 (hand estimates from the NESC tables, class header)';
            sp = tF16Modes.byName(m, 'short_period'); ph = tF16Modes.byName(m, 'phugoid');
            dr = tF16Modes.byName(m, 'dutch_roll'); ro = tF16Modes.byName(m, 'roll'); spi = tF16Modes.byName(m, 'spiral');
            tc.verifyWithin(sp.wn, 1.5, 8, 'REG', c, 'Quantity', 'SP wn', 'Unit', 'rad/s');
            tc.verifyWithin(sp.zeta, 0.2, 1.0, 'REG', c, 'Quantity', 'SP zeta');
            tc.verifyWithin(ph.period, 20, 200, 'REG', c, 'Quantity', 'phugoid period', 'Unit', 's');
            tc.verifyWithin(ph.zeta, -0.3, 0.3, 'REG', c, 'Quantity', 'phugoid zeta');
            tc.verifyWithin(dr.wn, 1, 6, 'REG', c, 'Quantity', 'DR wn', 'Unit', 'rad/s');
            tc.verifyWithin(dr.zeta, 0, 0.5, 'REG', c, 'Quantity', 'DR zeta');
            tc.verifyWithin(ro.tau, 0.1, 1.5, 'REG', c, 'Quantity', 'roll tau', 'Unit', 's');
            tc.verifyWithin(abs(spi.eigenvalue), 0, 0.1, 'REG', c, 'Quantity', 'spiral |lambda|', 'Unit', '1/s');
        end

        function aftCgLowersShortPeriodFrequency(tc)
            m25 = tc.f16Modes(565.6854, 25);
            m30 = tc.f16Modes(565.6854, 30);
            sp25 = tF16Modes.byName(m25, 'short_period'); sp30 = tF16Modes.byName(m30, 'short_period');
            if all(strcmp({sp30.status}, 'NOT_OSCILLATORY'))
                % split short period (allowed by expectation 4). Review R1 MINOR 2: this
                % branch used to be vacuous (verifyTrue(true)); it now checks that the
                % split carries two real roots and no frequency.
                tc.verifyNumElements(sp30, 2, 'CG 30 %: a split short period is two real roots');
                tc.verifyTrue(all(isnan([sp30.wn])), 'CG 30 %: a split short period has no frequency');
            else
                tc.assertNumElements(sp30, 1);
                tc.verifyWithin(sp30.wn, 0, sp25.wn, 'REG', 'expectation 4: CG aft lowers the SP frequency', ...
                    'Quantity', 'SP wn at CG 30 % vs 25 %', 'Unit', 'rad/s');
                tc.verifyLessThan(sp30.wn, sp25.wn);
            end
        end

        function higherSpeedRaisesShortPeriodFrequency(tc)
            m1 = tc.f16Modes(565.6854, 25);
            m2 = tc.f16Modes(700, 25);
            sp1 = tF16Modes.byName(m1, 'short_period'); sp2 = tF16Modes.byName(m2, 'short_period');
            tc.assertNumElements(sp2, 1);
            tc.verifyGreaterThan(sp2.wn, sp1.wn, 'expectation 4: higher speed raises the SP frequency (REG)');
        end

        function entryPointPrintsModeTable(tc)
            txt = evalc('run_f16_modes');
            for s = {'short_period', 'phugoid', 'dutch_roll', 'roll', 'spiral', 'wn', 'zeta', 'status', 'OK'}
                tc.verifySubstring(txt, s{1});
            end
            r = run_f16_modes();
            tc.verifyEqual(r.status, 'OK');
            tc.verifyClass(r.table, 'table');
            tc.verifyEqual(height(r.table), numel(r.modes));
        end

        function nonOkTrimIsReportedNotLinearized(tc)
            r = run_f16_modes(150, 10013);
            tc.verifyEqual(r.status, 'INFEASIBLE');
            tc.verifySubstring(r.reason, 'stall-limited');
            tc.verifyEmpty(r.modes, 'no modes from a failed trim');
            tc.verifyEmpty(r.lin, 'no linear model from a failed trim');
            txt = evalc('run_f16_modes(150, 10013)');
            tc.verifySubstring(txt, 'INFEASIBLE');
            tc.verifySubstring(txt, 'not linearized');
        end
    end
end
