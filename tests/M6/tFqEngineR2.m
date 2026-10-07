classdef (TestTags = {'M6'}) tFqEngineR2 < vital.test.VitalTestCase
%TFQENGINER2  M6, review R2 fixes: engine semantics of vital.fq.assess, tested
%   with SYNTHETIC point functions (no aircraft; every expected value ANALYTIC).
%
%   Findings covered (reports/work/review2/REVIEW.md): B1 (a divergent point
%   fails, it is not excluded), B2 / MINOR 9 (an excluded point never hides a
%   worse Level), R2-3, R2-4, R2-8, R2-11 (escaped mutations), M8 (validity
%   envelope tags), MINOR 2 (not-applicable with unrated points).
%
%   New engine semantics, PRE-REGISTERED here before they were implemented:
%   1. Metric status DIVERGENT means the requirement cannot be met at that point
%      (e.g. a split short period with an unstable root): the point is USED, its
%      margin is -Inf, it fails every Level (group Level 4 = worse than Level 3)
%      and it is not counted as excluded.
%   2. A group with excluded points is not complete: g.complete = false,
%      g.levelHeadline = NaN unless a used point is already worse than Level 3
%      (then 4 is certain), and g.levelText says how many points are unrated and
%      never reads as a plain "Level L". g.worstLevel keeps its meaning (worst
%      Level over the USED points).
%   3. Group margin: margin to the boundary of the Level achieved at the
%      critical point (Level 1 boundary for an all-Level-1 group).
%   4. Refinement evaluates the midpoints on BOTH sides of the critical grid
%      value.
%   5. MODE_MISSING (and any status other than OK, DIVERGENT, NOT_APPLICABLE) is
%      EXCLUDED and counted as 'metric:<status>', never not-applicable.
%   6. conditions.validity.bounds {quantity, min, max}: every point is tagged
%      envelope 'IN' or 'EXTRAPOLATED' (a quantity is looked up in the condition
%      point, then in the aircraft-factory output). Each record and group gets
%      separate summaries .inEnvelope and .extrapolated with their own Level,
%      status and critical condition (global point index).
%   7. A group whose rated points are all NOT_APPLICABLE but some points are
%      excluded is PARTIAL, with a reason giving both counts.

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
                fid = fopen(fullfile(d, [recs{k}.id '.json']), 'w', 'n', 'UTF-8');
                fprintf(fid, '%s', jsonencode(recs{k}));
                fclose(fid);
            end
            R = vital.fq.loadRules(d);
        end

        function g = grp(tc, res, name)
            g = res.groups(strcmp({res.groups.group}, name));
            tc.assertNumElements(g, 1, ['group ' name]);
        end

        function r = rul(tc, res, id)
            r = res.rules(strcmp({res.rules.id}, id));
            tc.assertNumElements(r, 1, ['record ' id]);
        end

        function needFields(tc, s, f)
            tc.assertTrue(all(isfield(s, f)), sprintf('result lacks field(s) %s', strjoin(f, ', ')));
        end
    end

    methods (Static, Access = private)
        function r = rec(id, group, metric, level, cat, lo, hi, scale)
            L = struct('level', level, 'category', cat);
            if ~isempty(lo), L.min = lo; end
            if ~isempty(hi), L.max = hi; end
            L.strict = false;
            r = struct('id', id, 'title', ['synthetic ' id], ...
                'ruleset', struct('name', 'SYNTHETIC', 'revision', 'n/a', 'basis', 'engine test'), ...
                'class', 'Q-SPEC', 'source', struct('document', 'synthetic', 'paragraph', group, 'page', '0'), ...
                'applicability', struct('aircraft_class', {{'IV'}}, 'flight_phase_category', {{cat}}), ...
                'group', group, 'metric', metric, 'criterion', struct('type', 'levels', 'levels', {{L}}), ...
                'scale', scale, 'conditions', struct('axes', {{'x'}}, 'search', 'grid'), ...
                'status_policy', struct('INFEASIBLE', 'exclude'));
        end

        function Z = zetaRules()
            Z = {tFqEngineR2.rec('Z1', 'Z-CatA', 'zeta_sp', 1, 'A', 0.35, 1.30, 0.35), ...
                 tFqEngineR2.rec('Z2', 'Z-CatA', 'zeta_sp', 2, 'A', 0.25, 2.00, 0.25), ...
                 tFqEngineR2.rec('Z3', 'Z-CatA', 'zeta_sp', 3, 'A', 0.15, [], 0.15)};
        end

        function C = conds(varargin)
            C.id = 'synthetic'; C.grid = 'test';
            C.axes = struct('name', varargin(1:2:end), 'values', varargin(2:2:end));
            C.fixed = struct(); C.categoryPolicy = struct();
        end

        function P = pt(name, v, st, stage, status)
            if nargin < 3, st = 'OK'; end
            if nargin < 4, stage = 'done'; status = 'OK'; end
            M.(name) = struct('value', v, 'status', st, 'reason', '', 'unit', '');
            P = struct('status', status, 'stage', stage, 'reason', '', 'metrics', M, 'info', struct());
        end
    end

    methods (Test)
        function excludedPointNeverHidesWorseLevel(tc)
            % B2 (c) / MINOR 9: the only point that would be Level 3 is excluded
            R = tc.rules(tFqEngineR2.zetaRules());
            pf = @(ac, c) tFqEngineR2.caseB2(c.x);
            res = vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:3), 'PointFcn', pf);
            g = tc.grp(res, 'Z-CatA');
            tc.needFields(g, {'complete', 'levelHeadline'});
            c = 'ANALYTIC: pre-registration 2 (class header); review R2 B2';
            tc.verifyEqual(g.status, 'PARTIAL', c);
            tc.verifyExact([g.nOK g.nExcluded], [2 1], 'ANALYTIC', c, 'Quantity', 'group [used excluded]');
            tc.verifyFalse(g.complete, 'a group with an excluded point is not complete');
            tc.verifyTrue(isnan(g.levelHeadline), 'no headline Level while a point is unrated');
            tc.verifyExact(g.worstLevel, 2, 'ANALYTIC', c, 'Quantity', 'worst Level over the used points');
            tc.verifyNotEqual(g.levelText, 'Level 2', 'never printed as a plain achieved Level');
            tc.verifySubstring(g.levelText, 'unrated');
            % a used point worse than Level 3 makes Level 4 certain despite exclusions
            pf2 = @(ac, c) tFqEngineR2.caseB2worse(c.x);
            g2 = tc.grp(vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:3), 'PointFcn', pf2), 'Z-CatA');
            tc.verifyExact(g2.levelHeadline, 4, 'ANALYTIC', c, 'Quantity', 'certain worse-than-Level-3 headline');
        end

        function missingModeNeverPasses(tc)
            % pre-registration 5 (R2-8)
            R = tc.rules(tFqEngineR2.zetaRules());
            pf = @(ac, c) tFqEngineR2.caseMissing(c.x);
            res = vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:3), 'PointFcn', pf);
            r = tc.rul(res, 'Z1');
            c = 'ANALYTIC: pre-registration 5';
            tc.verifyExact([r.nOK r.nExcluded r.nNotApplicable], [2 1 0], 'ANALYTIC', c, 'Quantity', 'record counts');
            k = strcmp({r.excludedBy.reason}, 'metric:MODE_MISSING');
            tc.verifyTrue(any(k) && r.excludedBy(k).count == 1, 'counted as metric:MODE_MISSING');
            g = tc.grp(res, 'Z-CatA');
            tc.verifyExact([g.nExcluded g.nNotApplicable], [1 0], 'ANALYTIC', c, 'Quantity', 'group counts');
            tc.verifyEqual(g.status, 'PARTIAL');
        end

        function divergentMetricFailsNotExcluded(tc)
            % pre-registration 1 (B1)
            R = tc.rules(tFqEngineR2.zetaRules());
            pf = @(ac, c) tFqEngineR2.caseDivergent(c.x);
            res = vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:3), 'PointFcn', pf);
            r = tc.rul(res, 'Z3');
            c = 'ANALYTIC: pre-registration 1 (DIVERGENT fails, not excluded)';
            tc.verifyExact([r.nOK r.nExcluded], [3 0], 'ANALYTIC', c, 'Quantity', 'record [used excluded]');
            tc.verifyExact(r.margin(2), -Inf, 'ANALYTIC', c, 'Quantity', 'margin of the divergent point');
            tc.verifyEqual(r.verdict, 'FAIL');
            tc.verifyExact(r.criticalIndex, 2, 'ANALYTIC', c, 'Quantity', 'critical point');
            g = tc.grp(res, 'Z-CatA');
            tc.verifyExact(g.levelAtPoint(:).', [1 4 1], 'ANALYTIC', c, 'Quantity', 'Levels');
            tc.verifyExact([g.worstLevel g.nExcluded], [4 0], 'ANALYTIC', c, 'Quantity', '[worst Level, excluded]');
            tc.verifyEqual(g.status, 'ASSESSED');
        end

        function groupMarginToAchievedLevel(tc)
            % pre-registration 3 (R2-11)
            R = tc.rules(tFqEngineR2.zetaRules());
            pf = @(ac, c) tFqEngineR2.pt('zeta_sp', 0.5);
            g = tc.grp(vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:2), 'PointFcn', pf), 'Z-CatA');
            tc.verifyExact(g.worstLevel, 1, 'ANALYTIC', 'all points Level 1', 'Quantity', 'Level');
            tc.verifyTol(g.criticalMargin, (0.5 - 0.35) / 0.35, 1e-12, 'abs', 'ANALYTIC', ...
                'pre-registration 3: margin to the Level 1 boundary, not Level 2 or 3', 'Quantity', 'group margin');
        end

        function refinementBelowCriticalValue(tc)
            % pre-registration 4 (R2-4): the minimum lies below the critical grid value
            R = tc.rules(tFqEngineR2.zetaRules());
            C = tFqEngineR2.conds('x', [0 0.2 0.4 0.6 0.8 1.0]);
            pf = @(ac, c) tFqEngineR2.pt('zeta_sp', 0.5 + (c.x - 0.33)^2);
            r0 = tc.rul(vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf), 'Z1');
            tc.verifyExact(r0.critical.x, 0.4, 'ANALYTIC', 'grid minimum at 0.4', 'Quantity', 'grid critical');
            r = tc.rul(vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf, 'Refine', true), 'Z1');
            c = 'ANALYTIC: pre-registration 4 (lower-side midpoint 0.3)';
            tc.verifyTrue(r.refined, 'critical from the refinement');
            tc.verifyTol(r.critical.x, 0.3, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'refined critical x');
            tc.verifyTol(r.minMargin, (0.5 + 0.03^2 - 0.35) / 0.35, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'refined margin');
        end

        function envelopeTagging(tc)
            % pre-registration 6 (M8): IN for x in [1, 2] (from the condition) and
            % q = 10 x <= 20 (from the factory); the worst point x = 4 is EXTRAPOLATED
            R = tc.rules(tFqEngineR2.zetaRules());
            C = tFqEngineR2.conds('x', 1:4);
            C.validity = struct('description', 'synthetic', 'judgment', 'synthetic', ...
                'bounds', struct('quantity', {'x', 'q'}, 'min', {1, 0}, 'max', {2, 20}));
            vals = [0.5 0.6 0.3 0.2];
            pf = @(ac, c) tFqEngineR2.pt('zeta_sp', vals(c.x));
            res = vital.fq.assess(R, @(c) struct('q', 10 * c.x), C, 'PointFcn', pf);
            tc.needFields(res.points, {'envelope'});
            c = 'ANALYTIC: pre-registration 6';
            tc.verifyEqual({res.points.envelope}, {'IN', 'IN', 'EXTRAPOLATED', 'EXTRAPOLATED'}, c);
            g = tc.grp(res, 'Z-CatA');
            tc.needFields(g, {'inEnvelope', 'extrapolated'});
            tc.verifyExact(g.inEnvelope.worstLevel, 1, 'ANALYTIC', c, 'Quantity', 'in-envelope Level');
            tc.verifyExact(g.inEnvelope.levelHeadline, 1, 'ANALYTIC', c, 'Quantity', 'in-envelope headline');
            tc.verifyExact(g.inEnvelope.critical.x, 1, 'ANALYTIC', c, 'Quantity', 'in-envelope critical');
            tc.verifyExact(g.extrapolated.worstLevel, 3, 'ANALYTIC', c, 'Quantity', 'extrapolated Level');
            tc.verifyExact(g.extrapolated.criticalIndex, 4, 'ANALYTIC', c, 'Quantity', 'extrapolated critical (global index)');
            tc.verifyExact(g.worstLevel, 3, 'ANALYTIC', c, 'Quantity', 'all-points Level unchanged');
            r = tc.rul(res, 'Z1');
            tc.verifyExact(r.inEnvelope.criticalIndex, 1, 'ANALYTIC', c, 'Quantity', 'record in-envelope critical');
            tc.verifyExact(r.extrapolated.criticalIndex, 4, 'ANALYTIC', c, 'Quantity', 'record extrapolated critical');
            % no validity registered: every point IN
            res0 = vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:2), 'PointFcn', pf);
            tc.verifyEqual({res0.points.envelope}, {'IN', 'IN'});
            % a validity quantity that exists nowhere is an error
            C.validity.bounds(2).quantity = 'nosuch';
            tc.verifyError(@() vital.fq.assess(R, @(c) struct(), C, 'PointFcn', pf), 'vital:fq:badConditions');
        end

        function notApplicableWithExclusionsIsPartial(tc)
            % pre-registration 7 (MINOR 2)
            R = tc.rules({tFqEngineR2.rec('R1', 'R-CatB', 'zeta_RS_omega_nRS_rad_s', 1, 'B', 0.5, [], 0.5)});
            pf = @(ac, c) tFqEngineR2.caseNA(c.x);
            g = tc.grp(vital.fq.assess(R, @(c) struct(), tFqEngineR2.conds('x', 1:4), 'PointFcn', pf), 'R-CatB');
            tc.verifyEqual(g.status, 'PARTIAL', 'pre-registration 7');
            tc.verifyExact([g.nNotApplicable g.nExcluded], [3 1], 'ANALYTIC', 'pre-registration 7', 'Quantity', 'counts');
            tc.verifySubstring(g.reason, 'not applicable at 3');
            tc.verifySubstring(g.reason, '1 unrated');
        end
    end

    methods (Static)
        function P = caseB2(x)
            if x == 3
                P = tFqEngineR2.pt('zeta_sp', 0.20, 'OK', 'trim', 'INFEASIBLE');
            else
                P = tFqEngineR2.pt('zeta_sp', 0.30);
            end
        end

        function P = caseB2worse(x)
            switch x
                case 1, P = tFqEngineR2.pt('zeta_sp', 0.10);
                case 2, P = tFqEngineR2.pt('zeta_sp', 0.30);
                otherwise, P = tFqEngineR2.pt('zeta_sp', 0.20, 'OK', 'trim', 'INFEASIBLE');
            end
        end

        function P = caseMissing(x)
            if x == 2, P = tFqEngineR2.pt('zeta_sp', NaN, 'MODE_MISSING'); else, P = tFqEngineR2.pt('zeta_sp', 0.5); end
        end

        function P = caseDivergent(x)
            if x == 2, P = tFqEngineR2.pt('zeta_sp', NaN, 'DIVERGENT'); else, P = tFqEngineR2.pt('zeta_sp', 0.5); end
        end

        function P = caseNA(x)
            if x == 4
                P = tFqEngineR2.pt('zeta_RS_omega_nRS_rad_s', NaN, 'NOT_APPLICABLE', 'trim', 'INFEASIBLE');
            else
                P = tFqEngineR2.pt('zeta_RS_omega_nRS_rad_s', NaN, 'NOT_APPLICABLE');
            end
        end
    end
end
