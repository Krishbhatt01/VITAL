classdef (TestTags = {'M7'}) tCtrlR3 < vital.test.VitalTestCase
%TCTRLR3  M7 coverage tests added after independent review R3 (findings M1 and
%   M6, reports/review/R3_REVIEW.md sections 4 and 6), written during M8 without
%   reopening M7's results: no implementation change, no change to an M7 number.
%   Expected values are pinned here (never read from reports/).
%   Runtime: about 4.5 min, dominated by test 4 (the full default
%   vital.ctrl.suggestGains search, about 220 s: the only live re-derivation of
%   the M7 proposal); tests 1-3 use the README point only (a few seconds).
%
%   Design inputs (the gains of tests 1 and 2, the start of test 3) were chosen
%   from an exploration run of the real chain (r3tests, 2026-10-09) so that
%   each test exercises the defect's blind spot; the expectations below were
%   written before the first run of this file.
%
%   PRE-REGISTERED:
%   1. 3.1.12 FLAG WITH ALL FIVE NAMES PRESENT (sabotage S7R-3; contract of
%      vital.fq.evaluatePoint: CLASSICAL only when the 8-state closed-loop modes
%      are EXACTLY the five classical modes, all OK). README point, pitchSas
%      Kq 1 s (Ka 0), and separately Ka -1 (Kq 0): the closed-loop short
%      period splits into two real roots, so the modes are two short_period
%      NOT_OSCILLATORY plus phugoid, dutch_roll, roll, spiral: all five names
%      present (guard), six entries (guard) -> info.equivalentSystem 'FLAGGED'
%      with a note citing 3.1.12 (REG).
%   2. NOT_ASSESSABLE PROTECTED GROUP IS A REGRESSION (S7R-1; FC-702 rule
%      "non-OK never improves a verdict"; suggestGains contract: a protected
%      group must keep its bare Level). README point, target 3.2.2.1.1-CatA
%      Level 1 (Level 1 bare), one gain Kr fixed at 2 s (lo = hi = start = 2,
%      builder vital.ctrl.yawDamper), MaxIter 0. Kr 2 splits the Dutch roll, so
%      3.3.1.1-CatA-COGA, -CatA-other (bare Level 2) and -CatB (bare Level 1)
%      have no in-envelope headline (NaN) in the confirmation (REG). Expected:
%      the target is reached (achieved Level 1); those three protected groups
%      have achievedLevel NaN and regressed true; status 'TARGET_NOT_REACHED'
%      with 'worse than bare' and '3.3.1.1-CatA-other' in the reason. Never
%      'TARGET_REACHED'.
%   3. ROUNDING TO THE NEAREST MULTIPLE (S7R-2, mechanism; ANALYTIC). README
%      point, default targets, gain box and builder, start k = [0.017 0.141
%      0.816], MaxIter 0 (the best iterate is the start): s.gains.unrounded =
%      the start (exact); s.gains.value = the nearest multiples of the
%      Resolution 0.01, [0.02 0.14 0.82] (1e-12 abs); |value - unrounded| <=
%      0.005 (+1e-12) per gain (truncation would give 0.01 and 0.81).
%   4. THE M7 PROPOSAL IS PINNED (S7R-2; R3 finding M1). The full default
%      search vital.ctrl.suggestGains() (the M7 defaults: 36 in-envelope
%      conditions, default targets, box, Goal 0.05, MaxIter 4, Resolution 0.01):
%      status 'TARGET_REACHED'; s.gains.value = [0.02 0.14 0.82] (Kq s, Ka
%      rad/rad, Kr s; 1e-12 abs; REG: the confirmed M7 gains, docs/
%      MILESTONES.json M7_acceptance, which vital.uq.augmentedBuilder analyses
%      in M8). Independent derivation of the rounding: each proposed gain is a
%      multiple of 0.01 (1e-9) within 0.005 (+1e-12) of the live unrounded
%      search result, and that result lies inside the gain box; the
%      confirmation was run with exactly the proposed gains.

    properties
        R
        Cr
        cReadme
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.R = vital.fq.loadRules();
            tc.Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), ...
                'Grid', 'readme');
            tc.cReadme = vital.fq.gridPoints(tc.Cr);
        end
    end

    methods (Test)
        function equivalentSystemFlagAllNamesPresent(tc)
            c = tc.cReadme;
            classical = {'short_period', 'phugoid', 'dutch_roll', 'roll', 'spiral'};
            for kk = {[1 0], [0 -1]}
                k = kk{1};
                b = @(AC, env, tr) vital.ctrl.pitchSas(AC, env, tr, 'Kq', k(1), 'Ka', k(2));
                ac = vital.fq.f16Factory('Controller', b);
                P = vital.fq.evaluatePoint(ac(c), c);
                tc.assertEqual(P.status, 'OK', P.reason);
                names = {P.info.modes.name};
                lbl = sprintf('Kq %g Ka %g', k(1), k(2));
                tc.verifyTrue(all(ismember(classical, names)), [lbl ': guard, all five classical names present']);
                tc.verifyNumElements(names, 6, [lbl ': guard, six modes (split short period)']);
                tc.verifyEqual(sum(strcmp(names, 'short_period') & strcmp({P.info.modes.status}, 'NOT_OSCILLATORY')), 2, ...
                    [lbl ': two NOT_OSCILLATORY short-period roots']);
                tc.verifyEqual(P.info.equivalentSystem, 'FLAGGED', [lbl ': header 1']);
                tc.verifyTrue(any(contains(P.info.notes, '3.1.12')), [lbl ': the flag is explained']);
            end
        end

        function notAssessableProtectedGroupIsRegression(tc)
            s = vital.ctrl.suggestGains('Conditions', tc.Cr, 'Rules', tc.R, ...
                'Targets', struct('group', '3.2.2.1.1-CatA', 'level', 1), ...
                'Gains', struct('name', 'Kr', 'lo', 2, 'hi', 2, 'start', 2, 'unit', 's'), ...
                'Builder', @(AC, env, tr, k) vital.ctrl.yawDamper(AC, env, tr, 'Kr', k(1)), 'MaxIter', 0);
            tc.verifyTrue(s.targets(1).reached, 'header 2: the target itself is reached');
            tc.verifyEqual(s.targets(1).achievedLevel, 1);
            for g = {'3.3.1.1-CatA-COGA', '3.3.1.1-CatA-other', '3.3.1.1-CatB'}
                p = s.protected(strcmp({s.protected.group}, g{1}));
                tc.assertNumElements(p, 1, [g{1} ' is protected']);
                tc.verifyTrue(isnan(p.achievedLevel), [g{1} ': no in-envelope headline with Kr 2']);
                tc.verifyTrue(p.regressed, [g{1} ': header 2, NOT_ASSESSABLE is worse than bare']);
            end
            tc.verifyEqual(s.status, 'TARGET_NOT_REACHED', s.reason);
            tc.verifySubstring(s.reason, 'worse than bare');
            tc.verifySubstring(s.reason, '3.3.1.1-CatA-other');
        end

        function roundingIsToNearest(tc)
            k0 = [0.017 0.141 0.816];
            G = struct('name', {'Kq', 'Ka', 'Kr'}, 'lo', {0, 0, 0}, 'hi', {0.4, 1.0, 1.5}, ...
                'start', num2cell(k0), 'unit', {'s', 'rad/rad', 's'});
            s = vital.ctrl.suggestGains('Conditions', tc.Cr, 'Rules', tc.R, 'Gains', G, 'MaxIter', 0);
            tc.verifyExact(s.gains.unrounded, k0, 'ANALYTIC', 'header 3: MaxIter 0, the start is the best iterate', ...
                'Quantity', 'unrounded gains');
            tc.verifyTol(s.gains.value, [0.02 0.14 0.82], 1e-12, 'abs', 'ANALYTIC', 'header 3: nearest multiples of 0.01', ...
                'Quantity', 'proposed gains');
            tc.verifyWithin(abs(s.gains.value - k0), 0, 0.005 + 1e-12, 'ANALYTIC', 'header 3: nearest, not truncated', ...
                'Quantity', '|value - unrounded|');
        end

        function m7GainsPinned(tc)
            s = vital.ctrl.suggestGains();
            tc.verifyEqual(s.status, 'TARGET_REACHED', s.reason);
            k = s.gains.value(:).';
            ku = s.gains.unrounded(:).';
            tc.verifyTol(k, [0.02 0.14 0.82], 1e-12, 'abs', 'REG', ...
                'docs/MILESTONES.json M7_acceptance: Kq 0.02 s, Ka 0.14, Kr 0.82 s (analysed by M8)', ...
                'Quantity', 'M7 proposed gains [Kq Ka Kr]');
            tc.verifyWithin(abs(k / 0.01 - round(k / 0.01)), 0, 1e-9, 'ANALYTIC', 'header 4: multiples of 0.01', ...
                'Quantity', 'k / 0.01 - integer');
            tc.verifyWithin(abs(k - ku), 0, 0.005 + 1e-12, 'ANALYTIC', 'header 4: nearest multiple of the live search result', ...
                'Quantity', '|value - unrounded|');
            tc.verifyTrue(all(ku >= [0 0 0] & ku <= [0.4 1.0 1.5]), 'header 4: the search result is inside the box');
            tc.verifyEqual(s.confirmation.gains, s.gains.value, 'header 4: confirmed with the proposed gains');
        end
    end
end
