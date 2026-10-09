classdef (TestTags = {'M8'}) tF16Uq < vital.test.VitalTestCase
%TF16UQ  M8 on the augmented NESC F-16 (bare airframe + vital.ctrl.pitchSas Kq 0.02,
%   Ka 0.14 + vital.ctrl.yawDamper Kr 0.82; reports/ctrl/f16_sas_suggestion.md):
%   vital.uq.analyze on two groups, 3.2.2.1.1-CatA (CAP / omega_nsp) and
%   3.3.1.1-CatA-other (Dutch roll), over the in-envelope conditions
%   (vital.ctrl.inEnvelopeConditions; only IN points count), widths x0.5, x1,
%   x1.5 of the JUDGMENT sigmas (uq/f16_uncertainty.json).
%   No published answer exists: the checks are STRUCTURAL INVARIANTS of the
%   method (plan M8) plus two labelled REG hypotheses.
%
%   REDUCED BUDGET (stated here, set before any run; the analysis runs ONCE in
%   TestClassSetup, about 8 minutes at ~0.3 s per closed-loop point): the plan's
%   centre and 2^6 = 64 corners, but NumLHS 8 (plan 32), NumStarts 1 (plan 2),
%   MaxEvals 20 (plan 60), NumCandidates 2 (plan 4), Monte Carlo N = 20 (plan
%   200). The invariants hold for any budget; the full plan budget is run by
%   run_f16_uq (reports/uq).
%
%   PRE-REGISTERED (with the stubs, before any implementation):
%   1. NOMINAL = M7 CONFIRMATION (REG, reports/ctrl/f16_sas_suggestion.json): the
%      augmented gains of vital.uq.augmentedBuilder equal the confirmed gains
%      [0.02 0.14 0.82]; both groups have nominal in-envelope Level 1 and
%      margins equal to the confirmation's achieved margins (1e-12 rel:
%      0.05125 and 1.218), with critical conditions 13,000 ft / Mach 0.45 /
%      CG 30 % and CG 20 %; the first candidate is the critical condition.
%   2. bound-worst <= nominal margin, for both groups and every width (exact: the
%      centre of the box is evaluated by the same chain, AeroScale all 1 being
%      bit-identical to the default path, tAeroScaleUq).
%   3. bound-worst is non-increasing with the width: value(x0.5) >=
%      value(x1) >= value(x1.5) (1e-9 abs: the step-study linearization noise
%      floor; the boxes are nested).
%   4. Every Monte Carlo sample inside the box (inBox) with status OK has a
%      margin (at the nominal critical condition) >= the bound-worst value of
%      the same width (1e-9 abs).
%   5. d margin(3.3.1.1-CatA-other)/d Cn_r > 0 at its nominal critical condition
%      (central difference, Cnr_table 1 +/- 0.02): more yaw damping, more
%      Dutch-roll damping (ANALYTIC sign: 2 zeta_d omega_nd ~ -(N_r + Y_beta/V)
%      in the Dutch-roll approximation, N_r ~ cnr < 0). Lon/lat decoupling of the
%      symmetric airframe at a wings-level trim (ANALYTIC): |d margin/d Cm_table|
%      <= 1e-6 for the same group.
%   FAILED HYPOTHESIS 5b (first GREEN-phase run, 2026-10-07; original kept above,
%   tolerance unchanged): |d margin/d Cm_table| <= 1e-6 failed: 0.0298. The
%   decoupling argument holds for a FIXED trim (as for the M7 gains), but
%   Cm_table scales the whole MRC pitching-moment table cmt(el, alpha), which is
%   not zero at the trim (it balances the normal-force moment about the CG,
%   arm 0.35 - CG fraction of cbar). Scaling it moves the trim alpha and
%   elevator, and the lateral derivatives depend on alpha, so the Dutch roll
%   changes. CORRECTED (ANALYTIC, independent): Cm_q scales cq2v*cmq, which is
%   zero at a trim with q = 0, so it leaves the trim untouched and only the
%   longitudinal rows of the linear model change: |d margin/d Cm_q| <= 1e-6.
%   6. The confirmation is real: a fresh vital.fq.assess run by THIS test at the
%      x1 arg-min parameters gives exactly (isequaln) bw.confirmation.margin for
%      both groups; bw.confirmation.evaluated is true everywhere.
%   7. REG hypotheses (bare-derivative reasoning, written before any run):
%      H1 3.2.2.1.1-CatA at x1 is VIOLATED and its verdict NOT_ROBUST: its
%         margin 0.051 means CAP is 5 % above 0.28, and Cm_table x (1 - 0.129)
%         scales the whole pitching-moment table (M_alpha and the SAS's
%         M_de Ka), so omega_sp^2 and CAP fall by ~10 %.
%      H2 3.3.1.1-CatA-other at x1 keeps a positive bound-worst margin: its
%         nominal margin 1.22 (zeta_d ~ 0.42 against 0.19) is dominated by the
%         yaw damper; -30 % of the airframe's cnr and clp cannot halve zeta_d.
%   8. Every report value is labelled: r.label is 'JUDGMENT'.

    properties
        R
        C
        r
        sas
    end

    properties (Constant)
        GROUPS = {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other'}
        W = [0.5 1 1.5]
    end

    methods (TestClassSetup)
        function runOnce(tc)
            tc.R = vital.fq.loadRules();
            tc.C = vital.ctrl.inEnvelopeConditions();
            tc.r = vital.uq.analyze('Groups', tc.GROUPS, 'WidthScales', tc.W, 'Rules', tc.R, 'Conditions', tc.C, ...
                'NumLHS', 8, 'NumStarts', 1, 'MaxEvals', 20, 'NumCandidates', 2, 'N', 20);
            tc.sas = jsondecode(fileread(fullfile(vital.paths('reports'), 'ctrl', 'f16_sas_suggestion.json')));
        end
    end

    methods (Access = private)
        function g = grp(tc, name)
            g = tc.r.groups(strcmp({tc.r.groups.group}, name));
        end
    end

    methods (Test)
        function nominalIsM7Confirmation(tc)
            [~, k] = vital.uq.augmentedBuilder();
            tc.verifyEqual([k.Kq k.Ka k.Kr], tc.sas.confirmation.gains(:).', 'AbsTol', 1e-12, 'augmented gains = M7 confirmed');
            T = tc.sas.targets;
            crit = {[13000 0.45 30], [13000 0.45 20]};
            for i = 1:2
                g = tc.grp(tc.GROUPS{i});
                t = T(strcmp({T.group}, tc.GROUPS{i}));
                tc.verifyEqual(g.level0, 1, [tc.GROUPS{i} ' nominal Level']);
                tc.verifyTol(g.margin0, t.achievedMargin, 1e-12, 'rel', 'REG', 'reports/ctrl/f16_sas_suggestion.json', ...
                    'Quantity', [tc.GROUPS{i} ' nominal margin']);
                c = g.critical.cond;
                tc.verifyEqual([c.h_ft c.mach c.cg_pct_mac], crit{i}, [tc.GROUPS{i} ' critical condition']);
                tc.verifyEqual(g.candidates.labels{1}, g.critical.condLabel, 'first candidate = critical');
                tc.verifyEqual(numel(g.candidates.labels), 2);
            end
        end

        function boundWorstNotAboveNominal(tc)
            for n = tc.GROUPS
                g = tc.grp(n{1});
                for j = 1:numel(tc.W)
                    tc.verifyLessThanOrEqual(g.widths(j).bw.value, g.margin0, sprintf('%s x%g', n{1}, tc.W(j)));
                end
            end
        end

        function nonIncreasingWithWidth(tc)
            for n = tc.GROUPS
                g = tc.grp(n{1});
                v = arrayfun(@(w) w.bw.value, g.widths);
                tc.verifyTrue(all(isfinite(v)), [n{1} ' finite bound-worst values']);
                tc.verifyTrue(all(diff(v) <= 1e-9), sprintf('%s: bound-worst %s not non-increasing', n{1}, mat2str(v, 8)));
            end
        end

        function monteCarloAboveBoundWorst(tc)
            for n = tc.GROUPS
                g = tc.grp(n{1});
                for j = 1:numel(tc.W)
                    mc = g.widths(j).mc;
                    use = mc.inBox(:) & strcmp(mc.status(:), 'OK');
                    tc.verifyNotEmpty(find(use, 1), 'some samples inside the box');
                    tc.verifyTrue(all(mc.margin(use) >= g.widths(j).bw.value - 1e-9), ...
                        sprintf('%s x%g: min MC margin in box %g < bound-worst %g', n{1}, tc.W(j), ...
                        min(mc.margin(use)), g.widths(j).bw.value));
                end
            end
        end

        function yawDampingSign(tc)
            spec = vital.uq.loadSpec();
            B = vital.uq.box(spec);
            E = vital.uq.F16Evaluator(B.aeroScale, 'Rules', tc.R, 'Conditions', tc.C);
            g = tc.grp('3.3.1.1-CatA-other');
            c = g.critical.cond;
            th = ones(1, 6);
            iR = strcmp(B.aeroScale, 'Cnr_table'); iM = strcmp(B.aeroScale, 'Cm_q');   % failed hypothesis 5b: Cm_q, not Cm_table
            m = @(t) E.groupMargin(t, c, g.group, g.level0).margin;
            tp = th; tp(iR) = 1.02; tm = th; tm(iR) = 0.98;
            dR = (m(tp) - m(tm)) / 0.04;
            tc.verifyGreaterThan(dR, 0, 'd margin(Dutch roll)/d Cn_r > 0');
            tp = th; tp(iM) = 1.02; tm = th; tm(iM) = 0.98;
            dM = (m(tp) - m(tm)) / 0.04;
            tc.verifyTol(dM, 0, 1e-6, 'abs', 'ANALYTIC', ...
                'hypothesis 5b corrected: Cm_q leaves the q = 0 trim untouched; lon/lat decoupling', ...
                'Quantity', 'd margin(3.3.1.1-CatA-other)/d Cm_q');
        end

        function confirmationIsIndependentAssessment(tc)
            b = vital.uq.augmentedBuilder();
            for n = tc.GROUPS
                g = tc.grp(n{1});
                for j = 1:numel(tc.W)
                    tc.verifyTrue(g.widths(j).bw.confirmation.evaluated, sprintf('%s x%g confirmed', n{1}, tc.W(j)));
                end
                bw = g.widths(tc.W == 1).bw;
                s = cell2struct(num2cell(bw.theta(:)), g.widths(tc.W == 1).box.aeroScale(:), 1);
                res = vital.fq.assess(tc.R, vital.fq.f16Factory('AeroScale', s, 'Controller', b), tc.C);
                m = vital.uq.F16Evaluator.levelMargin(res, n{1}, g.level0);
                tc.verifyTrue(isequaln(m, bw.confirmation.margin), sprintf('%s: %g vs %g', n{1}, m, bw.confirmation.margin));
            end
        end

        function regHypotheses(tc)
            g = tc.grp('3.2.2.1.1-CatA');
            w = g.widths(tc.W == 1);
            tc.verifyEqual(w.bw.status, 'VIOLATED', 'H1: CAP group violated at x1');
            tc.verifyEqual(w.verdict.verdict, 'NOT_ROBUST', 'H1');
            g = tc.grp('3.3.1.1-CatA-other');
            w = g.widths(tc.W == 1);
            tc.verifyWithin(w.bw.value, 0, Inf, 'REG', 'H2: Dutch-roll group keeps a positive margin at x1', ...
                'Quantity', '3.3.1.1-CatA-other bound-worst x1');
        end

        function labelledJudgment(tc)
            tc.verifyEqual(tc.r.label, 'JUDGMENT');
            tc.verifyEqual(tc.r.widthScales, tc.W);
        end
    end
end
