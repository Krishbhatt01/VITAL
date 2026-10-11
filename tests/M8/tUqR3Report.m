classdef (TestTags = {'M8'}) tUqR3Report < vital.test.VitalTestCase
%TUQR3REPORT  M8 after review R3 (docs/PLAN_M5_M8.md, "Amendment after review
%   R3", 2026-10-09): one small vital.uq.analyze run on the augmented F-16 and
%   its report. Rules restricted to six groups, the NESC README point (10,013
%   ft, 565.6854 ft/s, CG 25 %, IN), x1 only, a small budget: NumLHS 2,
%   NumStarts 1, MaxEvals 20, NumCandidates 1, N 4 (about 150 single-point
%   evaluations, under 1 min). The structure is what is tested, not the
%   budget's numbers.
%   Groups: 3.2.2.1.1-CatA (longitudinal), 3.3.1.3-CatA (spiral, nominal margin
%   +Inf), 3.3.1.4-CatA-other (binary metric), and their CatC partners
%   3.2.2.1.1-CatC, 3.3.1.3-CatC, 3.3.1.4-CatC (no in-envelope headline Level:
%   Category C is not assessed by the condition file's policy; 3.3.1.4-CatC is
%   NOT_APPLICABLE only).
%
%   PRE-REGISTERED (agent uq2, 2026-10-09, before any implementation of the
%   amendment):
%   1. m6: with the default group list, the analysed groups are exactly
%      3.2.2.1.1-CatA, 3.3.1.3-CatA, 3.3.1.4-CatA-other; r.omitted lists
%      exactly the three CatC groups, each with a reason containing 'no finite
%      in-envelope headline Level'; the report and vital.uq.headline list them
%      under 'Groups omitted' with the reason.
%   2. R3-M3(a): 3.2.2.1.1-CatA has plan.mode 'longitudinal', bw.searchNames
%      {Cm_q, Cm_table}, every evaluated point has the four lateral multipliers
%      exactly 1, exactly 4 corner points, and the runtime lon/lat spot check
%      passed (plan.spotCheck.passed).
%   3. R3-M3(b): 3.3.1.3-CatA has plan.mode 'surrogate' and (REG prediction
%      from R3 3.8: the spiral is stable at every x1 corner of the in-envelope
%      grid, max Re -0.00055 1/s) bw.status 'OK', bw.value +Inf,
%      bw.surrogate.value < 0, reason starting 'stable over the box (surrogate
%      search)'; the report contains that phrase.
%   4. R3-M2: 3.3.1.4-CatA-other has plan.sampledOnly true; its headline row
%      says 'sampled only'; the report says the bound-worst is a 'search
%      estimate (upper bound), not a proof'.
%   5. R3-M5: every analysed width carries mahalanobis.D equal (isequal) to
%      vital.uq.mahalanobis(bw.theta, ones, spec sigma, 'Dof', numel of the
%      searched parameters), and mahalanobis.dof = that number; the report
%      prints 'Mahalanobis' and the MRC note: 'about the MRC (35 % MAC)' and
%      'Cm_table scales the whole pitching-moment table'.
%   6. R3-M4: every width has bw.rounds (1 to 3 rounds, each with candidates,
%      searchValue and confirmation); a width with status OK has a final
%      confirmation that did not move; the report lists 'round 1'.
%   7. m2 / m9: the report prints the joint-box coverage (sprintf('%.4f') of
%      vital.uq.boxCoverage(box(spec)).joint, i.e. '0.9707') and the sentences
%      'implies robustness of every box it contains' and 'NOT_ASSESSABLE means
%      "not established"'.

    properties
        r
        spec
        md
        hl
        dir
    end

    properties (Constant)
        GROUPS = {'3.2.2.1.1-CatA', '3.3.1.3-CatA', '3.3.1.4-CatA-other'}
        OMITTED = {'3.2.2.1.1-CatC', '3.3.1.3-CatC', '3.3.1.4-CatC'}
    end

    methods (TestClassSetup)
        function runOnce(tc)
            R = vital.fq.loadRules();
            R = R(ismember({R.group}, [tc.GROUPS tc.OMITTED]));
            tc.assertEqual(sort(unique({R.group})), sort([tc.GROUPS tc.OMITTED]), 'records of the six groups');
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            tc.spec = vital.uq.loadSpec();
            tc.r = vital.uq.analyze('Rules', R, 'Conditions', Cr, 'WidthScales', 1, 'NumLHS', 2, 'NumStarts', 1, ...
                'MaxEvals', 20, 'NumCandidates', 1, 'N', 4);
            tc.dir = tempname;
            mkdir(tc.dir);
            tc.addTeardown(@() rmdir(tc.dir, 's'));
            f = vital.uq.writeReport(tc.r, tc.dir, 'f16_uq_r3report');
            tc.md = fileread(f.md);
            tc.hl = strjoin(vital.uq.headline(tc.r), newline);
        end
    end

    methods (Access = private)
        function g = grp(tc, name)
            g = tc.r.groups(strcmp({tc.r.groups.group}, name));
            tc.assertNumElements(g, 1, name);
        end
    end

    methods (Test)
        function omittedGroupsListed(tc)
            tc.verifyEqual(sort({tc.r.groups.group}), sort(tc.GROUPS), 'header 1: analysed groups');
            tc.verifyEqual(sort({tc.r.omitted.group}), sort(tc.OMITTED), 'header 1: omitted groups');
            for o = tc.r.omitted(:).'
                tc.verifySubstring(o.reason, 'no finite in-envelope headline Level', o.group);
            end
            for txt = {tc.md, tc.hl}
                tc.verifySubstring(txt{1}, 'Groups omitted');
                for o = tc.r.omitted(:).'
                    tc.verifySubstring(txt{1}, o.group);
                end
            end
        end

        function longitudinalSearchSpace(tc)
            g = tc.grp('3.2.2.1.1-CatA');
            tc.verifyEqual(g.plan.mode, 'longitudinal');
            tc.verifyTrue(g.plan.spotCheck.passed, 'header 2: spot check');
            bw = g.widths(1).bw;
            tc.verifyEqual(bw.searchNames, {'Cm_q', 'Cm_table'});
            lat = ismember(g.widths(1).box.aeroScale, {'Cl_p', 'Cnr_table', 'Cl_table', 'Cnt_table'});
            tc.verifyTrue(all(all(bw.points.theta(:, lat) == 1)), 'header 2: lateral multipliers held at 1');
            tc.verifyEqual(sum(strcmp(bw.points.phase, 'corner')), 4, 'header 2: 2^2 corners');
            tc.verifySubstring(tc.md, 'longitudinal parameters only');
        end

        function spiralSurrogate(tc)
            g = tc.grp('3.3.1.3-CatA');
            tc.verifyEqual(g.plan.mode, 'surrogate');
            bw = g.widths(1).bw;
            tc.verifyEqual(bw.status, 'OK', ['header 3 (REG prediction): ' bw.reason]);
            tc.verifyEqual(bw.value, Inf);
            tc.verifyLessThan(bw.surrogate.value, 0, 'header 3: stable spiral over the box');
            tc.verifyTrue(startsWith(bw.reason, 'stable over the box (surrogate search)'), bw.reason);
            tc.verifySubstring(tc.md, 'stable over the box (surrogate search)');
        end

        function sampledOnlyAndSearchEstimate(tc)
            g = tc.grp('3.3.1.4-CatA-other');
            tc.verifyTrue(g.plan.sampledOnly, 'header 4');
            L = splitlines(tc.md);
            row = L(startsWith(L, '| 3.3.1.4-CatA-other |'));
            tc.assertNotEmpty(row);
            tc.verifySubstring(row{1}, 'sampled only');
            tc.verifySubstring(tc.md, 'search estimate (upper bound), not a proof');
            tc.verifySubstring(tc.hl, 'search estimate (upper bound), not a proof');
        end

        function mahalanobisAndMrcNote(tc)
            sig = [tc.spec.parameters.sigma];
            for g = tc.r.groups(:).'
                for w = g.widths(:).'
                    n = numel(w.bw.searchNames);
                    D = vital.uq.mahalanobis(w.bw.theta, ones(1, numel(sig)), sig, 'Dof', n);
                    tc.verifyTrue(isequal(w.mahalanobis.D, D), sprintf('header 5: %s D %g vs %g', g.group, w.mahalanobis.D, D));
                    tc.verifyEqual(w.mahalanobis.dof, n);
                end
            end
            tc.verifySubstring(tc.md, 'Mahalanobis');
            tc.verifySubstring(tc.md, 'about the MRC (35 % MAC)');
            tc.verifySubstring(tc.md, 'Cm_table scales the whole pitching-moment table');
        end

        function roundsRecorded(tc)
            for g = tc.r.groups(:).'
                for w = g.widths(:).'
                    R = w.bw.rounds;
                    tc.verifyTrue(numel(R) >= 1 && numel(R) <= 3, g.group);
                    tc.verifyTrue(all(isfield(R, {'candidates', 'searchValue', 'confirmation'})), g.group);
                    if strcmp(w.bw.status, 'OK')
                        tc.verifyFalse(w.bw.confirmation.moved, ['header 6: OK needs a final confirmation that did not move: ' g.group]);
                    end
                end
            end
            tc.verifySubstring(tc.md, 'round 1');
        end

        function coverageAndNesting(tc)
            cv = vital.uq.boxCoverage(vital.uq.box(tc.spec));
            tc.verifySubstring(tc.md, sprintf('%.4f', cv.joint));
            tc.verifySubstring(tc.md, '0.9707');
            tc.verifySubstring(tc.md, 'implies robustness of every box it contains');
            tc.verifySubstring(tc.md, 'NOT_ASSESSABLE means "not established"');
        end
    end
end
