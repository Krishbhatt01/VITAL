classdef (TestTags = {'M6'}) tFqEngine < vital.test.VitalTestCase
%TFQENGINE  M6: the status-aware flying-qualities engine vital.fq.assess, tested
%   with SYNTHETIC point functions (no aircraft), so that every expected
%   value is a closed form in the test (ANALYTIC).
%
%   Engine semantics under test (docs: reports/fragments/fq/DECISIONS.md):
%   - A record encodes one Level boundary: lo <= y <= hi (strict: lo < y < hi),
%     y the metric value at a point. Normalized margin m = min((y - lo)/scale,
%     (hi - y)/scale) (RULE_SCHEMA: m > 0 satisfies). With a Table VI increment
%     the lower bound is lo + slope*max(0, x - threshold), x the increment metric.
%   - A point is used for a record only if the point status is OK and the
%     metric status is OK with a non-NaN value. Every other point is EXCLUDED and
%     counted by reason '<stage>:<status>' (trim:INFEASIBLE, metric:NAN, ...), or
%     NOT_APPLICABLE (metric status NOT_APPLICABLE). Excluded points are never the
%     critical point and never change a Level (FC-702).
%   - Record status: ASSESSED (all points used), PARTIAL (some excluded),
%     NOT_ASSESSABLE (no point usable: FC-701), NOT_APPLICABLE (only
%     not-applicable points). Critical point = smallest margin over used points.
%   - Group (paragraph + Category): at a point the Level achieved is the best
%     Level L whose records all pass (MIL-F-8785C 6.7.1, extract 1); none -> 4
%     ("worse than Level 3"). Worst Level over the used points; critical point =
%     worst Level, then smallest margin to that Level's boundary.
%   - Categories whose policy says assess = false are NOT_ASSESSABLE with the
%     policy reason.
%   - Refinement (option): around each critical grid point, the midpoints to the
%     neighbouring grid values on every axis (never outside the axis range) are
%     evaluated once; a refined point can become critical only if it is OK.
%
%   PRE-REGISTERED expectations (all ANALYTIC; values given in each test):
%   1. zeta = 0.5 + 0.02((x-3)^2 + (y-1)^2) on x = 0..4, y = 0..3 against
%      [0.35, 1.30] (scale 0.35): critical (3, 1), margin 0.15/0.35 exactly; the
%      upper-bound record tau = 0.2 + 0.05x + 0.1y against <= 1.0: critical (4, 3),
%      margin 0.3.
%   2. Moving the surface minimum to (1, 2) moves the critical condition there.
%   3. FC-702: an INFEASIBLE point with the lowest metric value and a
%      NOT_OSCILLATORY point are excluded (counted), never critical, and cannot
%      raise the worst Level; an OK point with a NaN value is excluded as
%      metric:NAN.
%   4. FC-701: all points INFEASIBLE -> NOT_ASSESSABLE (record and group),
%      no critical point, worst Level NaN.
%   5. A value exactly on an inclusive boundary passes with margin 0; exactly on
%      a strict boundary fails with margin 0 (Level 2 instead of 1).
%   6. Figures 1-3 boundaries (real curated 3.2.2.1.1 records): points 1e-9
%      (relative) inside/outside each CAP line, omega floor and n/alpha edge give
%      the Levels listed in figureBoundaryEncoding.
%   7. Refinement finds the inter-grid minimum of 0.5 + (x - 0.3)^2 at x = 0.3 and
%      ignores a non-OK refined point.
%   8. Table VI increment: zeta_d omega_nd >= 0.35 + 0.014 max(0, X - 20).
%   9. Category policy, NOT_APPLICABLE records, report files, bad inputs
%      (vital:fq:badConditions, vital:fq:noRules).

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeDir(tc)
            tc.Dir = tempname; mkdir(tc.Dir);
            tc.addTeardown(@() vital.test.removeTree(tc.Dir));
        end
    end

    methods (Access = private)
        function R = rules(tc, recs)
            d = fullfile(tc.Dir, sprintf('rules%06d', randi(1e6)));
            mkdir(d);
            for k = 1:numel(recs)
                tFqEngine.writeJson(fullfile(d, [recs{k}.id '.json']), recs{k});
            end
            R = vital.fq.loadRules(d);
        end
    end

    methods (Static, Access = private)
        function r = rec(id, group, metric, level, cat, lo, hi, scale, varargin)
            L = struct('level', level, 'category', cat);
            if ~isempty(lo), L.min = lo; end
            if ~isempty(hi), L.max = hi; end
            L.strict = false;
            r = struct('id', id, 'title', ['synthetic ' id], ...
                'ruleset', struct('name', 'SYNTHETIC', 'revision', 'n/a', 'basis', 'engine test'), ...
                'class', 'Q-SPEC', ...
                'source', struct('document', 'synthetic (engine test)', 'paragraph', group, 'page', '0'), ...
                'applicability', struct('aircraft_class', {{'IV'}}, 'flight_phase_category', {{cat}}), ...
                'group', group, 'metric', metric, ...
                'criterion', struct('type', 'levels', 'levels', L), 'scale', scale, ...
                'conditions', struct('axes', {{'x', 'y'}}, 'search', 'grid'), ...
                'status_policy', struct('INFEASIBLE', 'exclude'));
            for k = 1:2:numel(varargin)
                switch varargin{k}
                    case 'strict', r.criterion.levels.strict = varargin{k+1};
                    otherwise, r.(varargin{k}) = varargin{k+1};
                end
            end
        end

        function C = conds(varargin)
            % conds('x', 0:4, 'y', 0:3, ...)
            C.id = 'synthetic';
            C.grid = 'test';
            C.axes = struct('name', varargin(1:2:end), 'values', varargin(2:2:end));
            C.fixed = struct();
            C.categoryPolicy = struct();
        end

        function M = m(varargin)
            % m('zeta_sp', 0.4, 'tau_R_s', 0.3, ...) or m('zeta_sp', {0.4, 'NOT_OSCILLATORY'})
            M = struct();
            for k = 1:2:numel(varargin)
                v = varargin{k+1}; st = 'OK';
                if iscell(v), st = v{2}; v = v{1}; end
                M.(varargin{k}) = struct('value', v, 'status', st, 'reason', '', 'unit', '');
            end
        end

        function P = pt(M, stage, status)
            if nargin < 2, stage = 'done'; status = 'OK'; end
            P = struct('status', status, 'stage', stage, 'reason', '', 'metrics', M, 'info', struct());
        end

        function g = grp(res, name)
            g = res.groups(strcmp({res.groups.group}, name));
        end

        function r = rul(res, id)
            r = res.rules(strcmp({res.rules.id}, id));
        end

        function n = excl(r, reason)
            n = 0;
            k = strcmp({r.excludedBy.reason}, reason);
            if any(k), n = r.excludedBy(k).count; end
        end

        function writeJson(file, s)
            fid = fopen(file, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
            fclose(fid);
        end
    end

    methods (Test)
        function knownMinimumFoundExactly(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35), ...
                tFqEngine.rec('T1', 'T-CatA', 'tau_R_s', 1, 'A', [], 1.0, 1.0)});
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.5 + 0.02 * ((c.x - 3)^2 + (c.y - 1)^2), ...
                'tau_R_s', 0.2 + 0.05 * c.x + 0.1 * c.y));
            res = vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', 0:4, 'y', 0:3), 'PointFcn', pf);
            r = tFqEngine.rul(res, 'Z1');
            c = 'ANALYTIC: pre-registration 1 (class header)';
            tc.verifyExact([r.critical.x r.critical.y], [3 1], 'ANALYTIC', c, 'Quantity', 'critical (x, y) lower bound');
            tc.verifyTol(r.minMargin, 0.15 / 0.35, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'critical margin lower bound');
            tc.verifyEqual(r.status, 'ASSESSED');
            tc.verifyEqual(r.verdict, 'PASS');
            tc.verifyEqual(r.nOK, 20);
            t = tFqEngine.rul(res, 'T1');
            tc.verifyExact([t.critical.x t.critical.y], [4 3], 'ANALYTIC', c, 'Quantity', 'critical (x, y) upper bound');
            tc.verifyTol(t.minMargin, 0.3, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'critical margin upper bound');
            g = tFqEngine.grp(res, 'Z-CatA');
            tc.verifyExact(g.worstLevel, 1, 'ANALYTIC', c, 'Quantity', 'worst Level');
            tc.verifyExact([g.critical.x g.critical.y], [3 1], 'ANALYTIC', c, 'Quantity', 'group critical');
            tc.verifyTol(g.criticalMargin, 0.15 / 0.35, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'group critical margin');
            tc.verifyNumElements(g.levelAtPoint, 20);
        end

        function movingCriticalCondition(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35)});
            C = tFqEngine.conds('x', 0:4, 'y', 0:3);
            for ctr = [3 1; 1 2; 4 0].'
                pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.5 + 0.02 * ((c.x - ctr(1))^2 + (c.y - ctr(2))^2)));
                res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf);
                r = tFqEngine.rul(res, 'Z1');
                tc.verifyExact([r.critical.x r.critical.y], ctr.', 'ANALYTIC', 'pre-registration 2: the critical point follows the minimum', ...
                    'Quantity', 'moving critical (x, y)');
            end
        end

        function nonOkPointsNeverCriticalOrImproving(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35), ...
                tFqEngine.rec('Z2', 'Z-CatA', 'zeta_sp', 2, 'A', 0.25, 2.00, 0.25)});
            C = tFqEngine.conds('x', 0:5);
            vals = [0.40 0.10 0.20 0.45 0.50 0.60];
            pf = @(ac, c) tFqEngine.nonOkCase(c.x, vals);
            res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf);
            r = tFqEngine.rul(res, 'Z1');
            c = 'ANALYTIC: pre-registration 3 (FC-702)';
            tc.verifyExact(r.critical.x, 0, 'ANALYTIC', c, 'Quantity', 'critical x (excluded points skipped)');
            tc.verifyTol(r.minMargin, (0.40 - 0.35) / 0.35, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'critical margin');
            tc.verifyEqual(r.status, 'PARTIAL');
            tc.verifyExact([r.nOK r.nExcluded], [3 3], 'ANALYTIC', c, 'Quantity', '[used excluded] points');
            tc.verifyExact([tFqEngine.excl(r, 'trim:INFEASIBLE') tFqEngine.excl(r, 'metric:NOT_OSCILLATORY') ...
                tFqEngine.excl(r, 'metric:NAN')], [1 1 1], 'ANALYTIC', c, 'Quantity', 'excluded by reason');
            g = tFqEngine.grp(res, 'Z-CatA');
            tc.verifyExact(g.worstLevel, 1, 'ANALYTIC', c, 'Quantity', 'worst Level from OK points only');
            tc.verifyTrue(all(isnan(g.levelAtPoint([2 3 6]))), 'excluded points have no Level');
            % improvement: every OK point is Level 2; excluded points carry Level-1 values
            vals2 = [0.30 0.90 0.90 0.30 0.30 0.90];
            res2 = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', @(ac, c) tFqEngine.nonOkCase(c.x, vals2));
            g2 = tFqEngine.grp(res2, 'Z-CatA');
            tc.verifyExact(g2.worstLevel, 2, 'ANALYTIC', c, 'Quantity', 'non-OK points cannot improve the Level');
            tc.verifyTrue(ismember(g2.critical.x, [0 3 4]), 'group critical is an OK point');
        end

        function allInfeasibleIsNotAssessable(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35)});
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.9), 'trim', 'INFEASIBLE');
            res = vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', 1:4), 'PointFcn', pf);
            r = tFqEngine.rul(res, 'Z1');
            g = tFqEngine.grp(res, 'Z-CatA');
            c = 'ANALYTIC: pre-registration 4 (FC-701)';
            tc.verifyEqual(r.status, 'NOT_ASSESSABLE', c);
            tc.verifyEqual(g.status, 'NOT_ASSESSABLE', c);
            tc.verifyEmpty(r.criticalIndex, 'no critical point');
            tc.verifyTrue(isnan(r.minMargin) && isnan(g.worstLevel), 'no margin, no Level');
            tc.verifyExact(tFqEngine.excl(r, 'trim:INFEASIBLE'), 4, 'ANALYTIC', c, 'Quantity', 'excluded count');
            tc.verifyEqual(r.verdict, '');
        end

        function levelBoundaryOnGridPoint(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35), ...
                tFqEngine.rec('S1', 'S-CatA', 'spiral_T2_s', 1, 'A', 12, [], 12, 'strict', true), ...
                tFqEngine.rec('S2', 'S-CatA', 'spiral_T2_s', 2, 'A', 8, [], 8, 'strict', true)});
            zv = [0.35 0.5 0.6]; sv = [12 20 30];
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', zv(c.x), 'spiral_T2_s', sv(c.x)));
            res = vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', 1:3), 'PointFcn', pf);
            c = 'ANALYTIC: pre-registration 5 (inclusive vs strict boundary on a grid point)';
            z = tFqEngine.rul(res, 'Z1');
            tc.verifyExact(z.margin(1), 0, 'ANALYTIC', c, 'Quantity', 'margin on inclusive boundary');
            tc.verifyEqual(z.verdict, 'PASS');
            tc.verifyExact(tFqEngine.grp(res, 'Z-CatA').levelAtPoint(1), 1, 'ANALYTIC', c, 'Quantity', 'Level on inclusive boundary');
            s = tFqEngine.rul(res, 'S1');
            tc.verifyExact(s.margin(1), 0, 'ANALYTIC', c, 'Quantity', 'margin on strict boundary');
            tc.verifyEqual(s.verdict, 'FAIL', 'strict boundary: equality fails');
            g = tFqEngine.grp(res, 'S-CatA');
            tc.verifyExact(g.levelAtPoint(:).', [2 1 1], 'ANALYTIC', c, 'Quantity', 'Levels with strict boundary');
            tc.verifyExact(g.worstLevel, 2, 'ANALYTIC', c, 'Quantity', 'worst Level');
            tc.verifyExact(g.critical.x, 1, 'ANALYTIC', c, 'Quantity', 'critical x');
        end

        function figureBoundaryEncoding(tc)
            recDir = fullfile(vital.paths('rules'), 'mil_f_8785c', 'records');
            vital.io.requireDeliverable(fullfile(recDir, 'MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA.json'));
            R = vital.fq.loadRules(recDir);
            R = R(startsWith({R.group}, '3.2.2.1.1-'));
            d = 1e-9;
            %      CAP            omega         n_alpha  Level A  B  C
            T = [0.28*(1+d)     2              10        1        1  1
                 0.28*(1-d)     2              10        2        1  1
                 3.6*(1+d)      2              10        2        2  2
                 10*(1+d)       2              10        3        3  3
                 0.16*(1-d)     2              10        4        1  2
                 1              1.0*(1-d)      10        2        1  1
                 1              0.6*(1-d)      10        3        1  4
                 0.28           1.0            10        1        1  1
                 0.085*(1-d)    2              10        4        2  4
                 0.038*(1-d)    2              10        4        4  4
                 1              2              2.7*(1-d) 1        1  2
                 1              2              1.7*(1-d) 1        1  3
                 1              0.86*(1-d)     10        2        1  2
                 1              0.6            10        2        1  2
                 0.1            0.6*(1+d)      1.0       4        1  3];
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('CAP', T(c.k, 1), 'omega_nsp_rad_s', T(c.k, 2), 'n_alpha_g_per_rad', T(c.k, 3)));
            C = tFqEngine.conds('k', 1:size(T, 1));
            res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf);
            cat = {'A', 'B', 'C'};
            for j = 1:3
                g = tFqEngine.grp(res, ['3.2.2.1.1-Cat' cat{j}]);
                tc.verifyExact(g.levelAtPoint(:), T(:, 3 + j), 'ANALYTIC', ...
                    sprintf('MIL-F-8785C Figure %d boundaries as encoded per extract 6.3 A (pre-registration 6)', j), ...
                    'Quantity', ['Levels Category ' cat{j}]);
            end
        end

        function refinementFindsInterGridMinimum(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35)});
            C = tFqEngine.conds('x', [0 0.2 0.4 0.6 0.8 1.0], 'y', [0 1]);
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.5 + (c.x - 0.3)^2 + 0.01 * c.y));
            res0 = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf);
            r0 = tFqEngine.rul(res0, 'Z1');
            tc.verifyExact([r0.critical.x r0.critical.y], [0.2 0], 'ANALYTIC', 'grid minimum (no refinement)', 'Quantity', 'critical');
            tc.verifyFalse(r0.refined);
            res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf, 'Refine', true);
            r = tFqEngine.rul(res, 'Z1');
            c = 'ANALYTIC: pre-registration 7';
            tc.verifyTrue(r.refined, 'critical point comes from the refinement');
            tc.verifyTol([r.critical.x r.critical.y], [0.3 0], 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'refined critical (x, y)');
            tc.verifyTol(r.minMargin, 0.15 / 0.35, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'refined margin');
            refPts = res.points([res.points.refine]);
            tc.verifyNotEmpty(refPts);
            xs = arrayfun(@(p) p.cond.x, refPts); ys = arrayfun(@(p) p.cond.y, refPts);
            tc.verifyTrue(all(xs >= 0 & xs <= 1 & ys >= 0 & ys <= 1), 'refinement never leaves the axis range');
            % a non-OK refined point can never become critical
            pf2 = @(ac, c) tFqEngine.refineCase(c);
            res2 = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf2, 'Refine', true);
            r2 = tFqEngine.rul(res2, 'Z1');
            tc.verifyExact([r2.critical.x r2.critical.y], [0.2 0], 'ANALYTIC', c, 'Quantity', 'critical with infeasible refined point');
            tc.verifyFalse(r2.refined);
        end

        function tableVIIncrementApplied(tc)
            inc = struct('metric', 'omega_nd2_phi_beta_d', 'threshold', 20, 'slope', 0.014, 'quote', 'synthetic');
            R = tc.rules({tFqEngine.rec('D1', 'D-CatA', 'zeta_d_omega_nd_rad_s', 1, 'A', 0.35, [], 0.35, 'increment', inc)});
            X = [10 30 30]; y = [0.40 0.45 0.49];
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_d_omega_nd_rad_s', y(c.k), 'omega_nd2_phi_beta_d', X(c.k)));
            res = vital.fq.assess(R, @(c) struct(), tFqEngine.conds('k', 1:3), 'PointFcn', pf);
            r = tFqEngine.rul(res, 'D1');
            lo = 0.35 + 0.014 * max(0, X - 20);
            tc.verifyTol(r.margin(:).', (y - lo) / 0.35, 1e-12, 'abs', 'ANALYTIC', ...
                'MIL-F-8785C Table VI increment .014(omega_nd^2|phi/beta|_d - 20) (pre-registration 8)', 'Quantity', 'margins');
            tc.verifyExact(r.critical.k, 2, 'ANALYTIC', 'increment makes k = 2 critical', 'Quantity', 'critical k');
        end

        function categoryPolicyNotAssessable(tc)
            R = tc.rules({tFqEngine.rec('ZA', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35), ...
                tFqEngine.rec('ZC', 'Z-CatC', 'zeta_sp', 1, 'C', 0.35, 1.30, 0.35)});
            C = tFqEngine.conds('x', 1:2);
            C.categoryPolicy = struct('A', struct('assess', true, 'reason', ''), 'B', struct('assess', true, 'reason', ''), ...
                'C', struct('assess', false, 'reason', 'no landing configuration in the model'));
            res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.5)));
            tc.verifyEqual(tFqEngine.rul(res, 'ZC').status, 'NOT_ASSESSABLE');
            tc.verifySubstring(tFqEngine.grp(res, 'Z-CatC').reason, 'landing');
            tc.verifyEqual(tFqEngine.grp(res, 'Z-CatC').status, 'NOT_ASSESSABLE');
            tc.verifyEqual(tFqEngine.rul(res, 'ZA').status, 'ASSESSED');
        end

        function notApplicableRecords(tc)
            R = tc.rules({tFqEngine.rec('R1', 'R-CatB', 'zeta_RS_omega_nRS_rad_s', 1, 'B', 0.5, [], 0.5, 'strict', true), ...
                tFqEngine.rec('R2', 'R-CatB', 'zeta_RS_omega_nRS_rad_s', 2, 'B', 0.3, [], 0.3, 'strict', true)});
            C = tFqEngine.conds('k', 1:4);
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_RS_omega_nRS_rad_s', {NaN, 'NOT_APPLICABLE'}));
            res = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf);
            tc.verifyEqual(tFqEngine.rul(res, 'R1').status, 'NOT_APPLICABLE');
            tc.verifyEqual(tFqEngine.grp(res, 'R-CatB').status, 'NOT_APPLICABLE');
            v = {{NaN, 'NOT_APPLICABLE'}, 0.6, {NaN, 'NOT_APPLICABLE'}, 0.4};
            pf2 = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_RS_omega_nRS_rad_s', v{c.k}));
            res2 = vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf2);
            r = tFqEngine.rul(res2, 'R1');
            tc.verifyExact([r.nOK r.nNotApplicable r.nExcluded], [2 2 0], 'ANALYTIC', 'two coupled-mode points', 'Quantity', 'counts');
            g = tFqEngine.grp(res2, 'R-CatB');
            tc.verifyExact(g.worstLevel, 2, 'ANALYTIC', '0.4 > 0.3 (L2) but not > 0.5 (L1)', 'Quantity', 'worst Level');
            tc.verifyExact(g.critical.k, 4, 'ANALYTIC', 'critical k', 'Quantity', 'critical k');
        end

        function reportsWritten(tc)
            R = tc.rules({tFqEngine.rec('S1', 'S-CatA', 'spiral_T2_s', 1, 'A', 12, [], 12, 'strict', true)});
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('spiral_T2_s', Inf));
            res = vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', 1:2), 'PointFcn', pf, ...
                'ReportDir', tc.Dir, 'ReportName', 'syn');
            tc.verifyTrue(isfile(fullfile(tc.Dir, 'syn.json')) && isfile(fullfile(tc.Dir, 'syn.md')), 'report files written');
            j = jsondecode(fileread(fullfile(tc.Dir, 'syn.json')));
            tc.verifyTrue(isfield(j, 'groups') && isfield(j, 'rules') && isfield(j, 'points'));
            tc.verifySubstring(fileread(fullfile(tc.Dir, 'syn.json')), '"Inf"');
            md = fileread(fullfile(tc.Dir, 'syn.md'));
            tc.verifySubstring(md, 'S-CatA');
            tc.verifySubstring(md, 'Level');
            tc.verifyEqual(res.files.json, fullfile(tc.Dir, 'syn.json'));
        end

        function badInputsRejected(tc)
            R = tc.rules({tFqEngine.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35)});
            pf = @(ac, c) tFqEngine.pt(tFqEngine.m('zeta_sp', 0.5));
            tc.verifyError(@() vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', [0 2 1]), 'PointFcn', pf), 'vital:fq:badConditions');
            tc.verifyError(@() vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', [0 NaN]), 'PointFcn', pf), 'vital:fq:badConditions');
            tc.verifyError(@() vital.fq.assess(R, @(c) struct(), tFqEngine.conds('x', []), 'PointFcn', pf), 'vital:fq:badConditions');
            tc.verifyError(@() vital.fq.assess(R([]), @(c) struct(), tFqEngine.conds('x', 1:2), 'PointFcn', pf), 'vital:fq:noRules');
        end
    end

    methods (Static)
        function P = nonOkCase(x, vals)
            switch x
                case 1
                    P = tFqEngine.pt(tFqEngine.m('zeta_sp', vals(2)), 'trim', 'INFEASIBLE');
                case 2
                    P = tFqEngine.pt(tFqEngine.m('zeta_sp', {vals(3), 'NOT_OSCILLATORY'}));
                case 5
                    P = tFqEngine.pt(tFqEngine.m('zeta_sp', NaN));
                otherwise
                    P = tFqEngine.pt(tFqEngine.m('zeta_sp', vals(x + 1)));
            end
        end

        function P = refineCase(c)
            v = 0.5 + (c.x - 0.3)^2 + 0.01 * c.y;
            if abs(c.x - 0.3) < 1e-9
                P = tFqEngine.pt(tFqEngine.m('zeta_sp', 0.3), 'trim', 'INFEASIBLE');
            else
                P = tFqEngine.pt(tFqEngine.m('zeta_sp', v));
            end
        end
    end
end
