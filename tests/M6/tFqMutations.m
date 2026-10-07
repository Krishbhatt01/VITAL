classdef (TestTags = {'M6'}) tFqMutations < vital.test.VitalTestCase
%TFQMUTATIONS  M6: pre-registered aircraft mutations (REG) through the full
%   chain trim -> linearize -> modes -> metrics -> vital.fq.assess.
%
%   Mutations (from the approved plan): CG aft; Cm_q x 0.3; Cn_beta x 0.2;
%   Cl_p x 0.4 (vital.aircraft.f16.config 'AeroScale'; what each multiplier
%   scales is stated in tests/M6/tAeroScale.m).
%   NOTE 2026-10-05 (review R2 M5, M6): the 'Cn_beta' knob was renamed
%   'Cnt_table' (it scales the MRC table cnt; the effective body N_beta at the
%   CG falls to 0.335, not 0.2); only the name in the call changed below. The
%   post-hoc sharpened values and Level changes are registered separately in
%   tests/M6/tF16FqR2.m (mutationOutcomesPinned). Disclosure for R2 M6: the
%   only edit to this file between RED (2026-09-29) and R2 was the 14-line
%   OUTCOMES block at the end of this header (the RED report places
%   requireDeliverable at line 71; it was at line 85 after that block, +14).
%   Grid 'mutation' of rules/mil_f_8785c/conditions_f16.json: h = 10,013 ft,
%   V = 565.6854 and 700 ft/s (true), CG 25 % MAC, level flight, g = 32.174
%   ft/s^2. Point 1 is the NESC README condition, point 2 the 700 ft/s one.
%
%   Basis of the numbers below: the M5-A REG mode table
%   (reports/fragments/linear/CHANGELOG.md): at the README condition, CG 25 %:
%   SP wn 2.503 rad/s, zeta 0.452; DR wn 3.318, zeta 0.117; roll tau 0.338 s;
%   n_alpha (alpha-only) 14.90 g/rad; CG 30 %: SP wn 1.777, zeta 0.564, roll tau
%   0.337 s; 700 ft/s: SP wn 3.095, roll tau 0.264 s.
%
%   PRE-REGISTERED (written before the mutations were run):
%   M1  CG 25 -> 30 % MAC (grid cg axis replaced by 30):
%       a. omega_nsp_rad_s and CAP decrease at both points.
%       b. the minimum margin of MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA decreases.
%       c. Level change, derived: at the README point the Category A thumbprint
%          (3.2.2.1.1-CatA) is Level 1 at CG 25 % and Level 2 at CG 30 %. Derivation:
%          the steady-state n/alpha (6.2 definition, with the elevator's own lift,
%          which REDUCES n/alpha for a nose-up command) is <= the alpha-only 14.90
%          and above 13.1 (the Z_de term is < 12 % of Z_alpha for |de/alpha| <= 1:
%          CZ_de = -0.19/25 per deg vs CZ_alpha ~ -0.063 per deg). CG 25 %: CAP >=
%          2.503^2/14.90 = 0.42, inside [0.28, 3.6], omega 2.50 >= 1.0 -> Level 1.
%          CG 30 %: CAP in [1.777^2/14.90, 1.777^2/13.1] = [0.21, 0.24], outside the
%          Level 1 band [0.28, 3.6] but inside Level 2 [0.16, 10.0], omega >= 0.6
%          -> Level 2.
%       d. must hold: tau_R_s at the README point within +/-5 % of the CG 25 %
%          value (M5-A 0.338 -> 0.337 s); 3.2.2.1.2-CatB stays Level 1 at the
%          README point (zeta 0.564 in [0.30, 2.00]).
%   M2  Cm_q x 0.3:
%       a. zeta_sp decreases at both points.
%       b. the minimum margin of MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA decreases.
%       c. no Level change is registered: the hand estimate (Cm_q,cg = cmq +
%          0.1 czq ~ -5.2 - 3.0; 0.3 cmq leaves 0.56 of it) gives zeta_sp ~ 0.34,
%          too close to the 0.35 boundary to predict.
%       d. must hold: the trim is identical (q = 0 at trim, so the scaled term is
%          zero) and the lateral metrics zeta_d, omega_nd_rad_s, tau_R_s are equal
%          to 1e-10 relative, spiral_T2_s equal (lon/lat decoupled at a symmetric
%          trim, tF16Linearize/lonLatDecoupledAtSymmetricTrim).
%   M3  Cn_beta x 0.2:
%       a. omega_nd_rad_s decreases at both points (omega_nd^2 ~ N_beta).
%       b. the minimum margin of MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatA-other
%          decreases.
%       c. no Level change registered.
%       d. must hold: identical trim (cnt = 0 at beta = 0); zeta_sp,
%          omega_nsp_rad_s, n_alpha_g_per_rad, CAP and zeta_p equal to 1e-10 rel.
%   M4  Cl_p x 0.4:
%       a. tau_R_s increases at both points, by a factor in [1.8, 2.8] (tau_R ~
%          -1/L_p gives 1/0.4 = 2.5; the band allows for the Ixz and Dutch-roll
%          coupling terms).
%       b. the minimum margin of MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA decreases.
%       c. must hold: identical trim; zeta_sp, omega_nsp_rad_s, CAP, zeta_p equal to
%          1e-10 rel ("Cl_p must not change the short-period metrics"); 3.3.1.2-CatB
%          stays Level 1 at both points (tau_R <= 0.338 x 2.8 = 0.95 s < 1.4 s).
%   All runs: every point trims, linearizes and has OK modes (M5-A), so no
%   point is excluded.
%
%   OUTCOMES of the first GREEN run (recorded after it; nothing above changed):
%   M1  all registered checks held (Level 1 -> 2, CAP 0.424 -> 0.205). FAILED
%       SUB-HYPOTHESIS in the derivation of c: its premise "n/alpha(6.2) <= the
%       alpha-only 14.90" held at CG 25 % (14.77) but NOT at CG 30 % (15.37): at
%       the aft CG the elevator increment of a steady pull-up adds lift instead of
%       removing it. The derived sub-interval CAP in [0.21, 0.24] therefore does
%       not hold (0.205); the registered check [0.16, 0.28] and the Level did.
%   M2  held; zeta_sp 0.452 -> 0.341 (the unregistered hand estimate 0.34 was
%       right, and the Cat A Level does go 1 -> 2, which was deliberately not
%       registered).
%   M3  held; omega_nd 3.32 -> 2.04 rad/s, and zeta_d rises 0.117 -> 0.193, so
%       3.3.1.1-CatA-other improves from Level 2 to Level 1 (not registered).
%   M4  held; tau_R ratio 2.44 and 2.55.

    properties
        File
        R
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.File = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
            vital.io.requireDeliverable(tc.File);
            tc.R = vital.fq.loadRules();
        end
    end

    methods (Access = private)
        function [res0, res1] = runPair(tc, scale, cgAft)
            C0 = vital.fq.loadConditions(tc.File, 'Grid', 'mutation');
            res0 = vital.fq.assess(tc.R, vital.fq.f16Factory(), C0);
            C1 = C0;
            if cgAft
                C1 = vital.fq.loadConditions(tc.File, 'Grid', 'mutation', ...
                    'Axes', struct('h_ft', 10013, 'V_ftps', [565.6854 700], 'cg_pct_mac', 30));
            end
            res1 = vital.fq.assess(tc.R, vital.fq.f16Factory('AeroScale', scale), C1);
            for r = {res0, res1}
                tc.assertNumElements(r{1}.points, 2);
                tc.assertEqual({r{1}.points.status}, {'OK', 'OK'}, 'every point OK (registered)');
            end
        end
    end

    methods (Static, Access = private)
        function v = val(res, i, name)
            v = res.points(i).metrics.(name).value;
        end

        function r = rul(res, id)
            r = res.rules(strcmp({res.rules.id}, id));
        end

        function g = grp(res, name)
            g = res.groups(strcmp({res.groups.group}, name));
        end

        function t = trimOf(res, i)
            t = res.points(i).info.trimxu;
        end
    end

    methods (Test)
        function cgAft(tc)
            [b, m] = tc.runPair(struct(), true);
            V = @tFqMutations.val;
            c = 'REG: M1 (class header)';
            for i = 1:2
                tc.verifyLessThan(V(m, i, 'omega_nsp_rad_s'), V(b, i, 'omega_nsp_rad_s'), sprintf('M1a omega_nsp point %d', i));
                tc.verifyLessThan(V(m, i, 'CAP'), V(b, i, 'CAP'), sprintf('M1a CAP point %d', i));
            end
            id = 'MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA';
            tc.verifyLessThan(tFqMutations.rul(m, id).minMargin, tFqMutations.rul(b, id).minMargin, 'M1b CAP L1 margin decreases');
            tc.verifyExact(tFqMutations.grp(b, '3.2.2.1.1-CatA').levelAtPoint(1), 1, 'REG', [c ' c: CG 25 %'], 'Quantity', 'thumbprint Cat A Level');
            tc.verifyExact(tFqMutations.grp(m, '3.2.2.1.1-CatA').levelAtPoint(1), 2, 'REG', [c ' c: CG 30 %'], 'Quantity', 'thumbprint Cat A Level');
            tc.verifyWithin(V(m, 1, 'CAP'), 0.16, 0.28, 'REG', [c ' c: CAP between the Level 2 and Level 1 lower lines'], 'Quantity', 'CAP CG 30 %');
            tc.verifyTol(V(m, 1, 'tau_R_s'), V(b, 1, 'tau_R_s'), 0.05, 'rel', 'REG', [c ' d'], 'Quantity', 'tau_R CG 30 % vs 25 %', 'Unit', 's');
            tc.verifyExact(tFqMutations.grp(m, '3.2.2.1.2-CatB').levelAtPoint(1), 1, 'REG', [c ' d'], 'Quantity', 'zeta_sp Cat B Level');
        end

        function pitchDampingReduced(tc)
            [b, m] = tc.runPair(struct('Cm_q', 0.3), false);
            V = @tFqMutations.val;
            c = 'REG: M2 (class header)';
            for i = 1:2
                tc.verifyLessThan(V(m, i, 'zeta_sp'), V(b, i, 'zeta_sp'), sprintf('M2a zeta_sp point %d', i));
                tc.verifyExact(tFqMutations.trimOf(m, i), tFqMutations.trimOf(b, i), 'REG', [c ' d'], 'Quantity', 'trim');
                for f = {'zeta_d', 'omega_nd_rad_s', 'tau_R_s'}
                    tc.verifyTol(V(m, i, f{1}), V(b, i, f{1}), 1e-10, 'rel', 'REG', [c ' d'], 'Quantity', f{1});
                end
                tc.verifyExact(V(m, i, 'spiral_T2_s'), V(b, i, 'spiral_T2_s'), 'REG', [c ' d'], 'Quantity', 'spiral T2');
            end
            id = 'MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA';
            tc.verifyLessThan(tFqMutations.rul(m, id).minMargin, tFqMutations.rul(b, id).minMargin, 'M2b zeta_sp L1 margin decreases');
        end

        function directionalStiffnessReduced(tc)
            [b, m] = tc.runPair(struct('Cnt_table', 0.2), false);
            V = @tFqMutations.val;
            c = 'REG: M3 (class header)';
            for i = 1:2
                tc.verifyLessThan(V(m, i, 'omega_nd_rad_s'), V(b, i, 'omega_nd_rad_s'), sprintf('M3a omega_nd point %d', i));
                tc.verifyExact(tFqMutations.trimOf(m, i), tFqMutations.trimOf(b, i), 'REG', [c ' d'], 'Quantity', 'trim');
                for f = {'zeta_sp', 'omega_nsp_rad_s', 'n_alpha_g_per_rad', 'CAP', 'zeta_p'}
                    tc.verifyTol(V(m, i, f{1}), V(b, i, f{1}), 1e-10, 'rel', 'REG', [c ' d'], 'Quantity', f{1});
                end
            end
            id = 'MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatA-other';
            tc.verifyLessThan(tFqMutations.rul(m, id).minMargin, tFqMutations.rul(b, id).minMargin, 'M3b omega_nd L1 margin decreases');
        end

        function rollDampingReduced(tc)
            [b, m] = tc.runPair(struct('Cl_p', 0.4), false);
            V = @tFqMutations.val;
            c = 'REG: M4 (class header)';
            for i = 1:2
                tc.verifyWithin(V(m, i, 'tau_R_s') / V(b, i, 'tau_R_s'), 1.8, 2.8, 'REG', [c ' a'], ...
                    'Quantity', sprintf('tau_R ratio point %d', i));
                tc.verifyExact(tFqMutations.trimOf(m, i), tFqMutations.trimOf(b, i), 'REG', [c ' c'], 'Quantity', 'trim');
                for f = {'zeta_sp', 'omega_nsp_rad_s', 'CAP', 'zeta_p'}
                    tc.verifyTol(V(m, i, f{1}), V(b, i, f{1}), 1e-10, 'rel', 'REG', [c ' c'], 'Quantity', f{1});
                end
                tc.verifyExact(tFqMutations.grp(m, '3.3.1.2-CatB').levelAtPoint(i), 1, 'REG', [c ' c'], 'Quantity', 'tau_R Cat B Level');
            end
            id = 'MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA';
            tc.verifyLessThan(tFqMutations.rul(m, id).minMargin, tFqMutations.rul(b, id).minMargin, 'M4b tau_R L1 margin decreases');
        end
    end
end
