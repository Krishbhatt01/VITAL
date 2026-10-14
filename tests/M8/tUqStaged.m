classdef (TestTags = {'M8'}) tUqStaged < vital.test.VitalTestCase
%TUQSTAGED  M8 amendment R4b, items R4-8 (staged default run) and R4-9 (lateral
%   groups drop Cm_q) (docs/PLAN_M5_M8.md, "Amendment R4b", coordinator
%   2026-10-14): the decision logic, on fakes and toys (no aircraft; the F-16
%   gate and the end-to-end staged run are in tests/M8/tUqR4bF16.m).
%   Expected runtime: a few seconds.
%
%   R4-8 (stated here before any implementation):
%   - Stage 1 budget, vital.uq.stageBudget(full): the full budget with
%     NumCandidates min(full, 2), DEPopulation min(full, 8) and DEGenerations
%     min(full, 4) (the smaller differential-evolution stage: 8 members x 4
%     generations instead of 16 x 8), every other option (Monte Carlo N = 200,
%     NumLHS, MaxEvals, ...) unchanged; [s1, same]: same = isequal(s1, full)
%     (then stage 2 cannot add anything and is not run).
%   - Stage 2, vital.uq.stagePlan(e, 'Band', [0.8 1.2]) for an analysed group
%     e (its stage-1 result): need = true when
%       (a) e.status is 'DONE', e.plan.method is not 'lattice' (the
%           longitudinal lattice groups need no stage 2), AND
%       (b) EITHER its judged CSR bracket [alphaLo, alphaHi] overlaps the band
%           (closed intervals: alphaLo <= 1.2 and alphaHi >= 0.8),
%           OR its judged CSR status is NOT_ASSESSABLE for budget reasons (reason
%           containing 'FC-901' or 'budget'),
%           OR (no CSR computed) its x1 bound-worst is NOT_ASSESSABLE with a
%           reason containing 'FC-901' or 'budget'.
%     why: a text naming the rule that applied ('lattice' for a lattice group).
%
%   R4-9 (stated here before any implementation):
%   - vital.uq.searchPlan(..., 'LatDropCmq', true): a lateral group (name
%     starting '3.3.') drops the field Cm_q from its searched parameters when
%     the box has Cm_q and at least one other parameter: mode 'lateral' (or
%     'surrogate' for a +Inf spiral group, which keeps its mode), plan.dropped
%     {'Cm_q'}; otherwise nothing is dropped. Default 'LatDropCmq' false in
%     searchPlan (vital.uq.analyze passes true). 'Lattice' true with Method
%     'auto' gives the longitudinal groups plan.method 'lattice'.
%   - vital.uq.gatePlan(plan, check, fields): the FALLBACK. If plan.dropped is
%     not empty and check.passed is false, every parameter is searched again
%     (idx 1:d, dropped {}, mode 'full' unless 'surrogate', method recomputed
%     with vital.uq.searchMethod for 'auto'), and plan.reason says the gate
%     FAILED. plan.latCheck = check in every case.
%   - vital.uq.invarianceCheck(qfun, th0, ths, 'RelTol', 1e-9): q = qfun(theta)
%     (status, value); passed when every q is OK and every value equals the
%     value at th0 within RelTol relative (or exactly, for 0 / Inf / NaN).
%
%   PRE-REGISTERED (agent uq4, 2026-10-14, with the stubs, before any
%   implementation):
%   1. stagePlan truth table (Band [0.8 1.2]):
%        lattice, OK [0.9 0.905]                                  -> false ('lattice')
%        hybrid,  OK [0.85 0.86]                                  -> true
%        hybrid,  OK [1.25 1.26]                                  -> false
%        hybrid,  ROBUST_TO_CAP [3 Inf]                           -> false
%        hybrid,  NOT_ASSESSABLE [0 2.76] ('a point is not OK')   -> true (overlap)
%        hybrid,  NOT_ASSESSABLE [1.3 Inf] ('FC-901: ...')        -> true (budget)
%        hybrid,  NOT_ASSESSABLE [1.3 Inf] ('MOVING_LIMIT: ...')  -> false
%        hybrid,  NOT_ASSESSABLE [1.3 Inf] ('... search budget (15 box searches) is used up') -> true
%        hybrid,  OK [1.2 1.21] -> true; OK [0.79 0.8] -> true;
%                 OK [0.78 0.79] -> false; OK [1.21 1.22] -> false
%        hybrid,  OK [1.3 1.31], x1 bound-worst NOT_ASSESSABLE 'FC-901' -> false
%        no CSR,  x1 NOT_ASSESSABLE 'FC-901: ...' -> true; x1 OK -> false
%        group status NOT_ASSESSABLE (not searched)               -> false
%      every why is a non-empty text (sabotage S8X-5).
%   2. stageBudget: full (NumCandidates 4, DEPopulation 16, DEGenerations 8,
%      N 200, NumLHS 32, MaxEvals 150) -> stage 1 (2, 8, 4, 200, 32, 150),
%      same false; full (1, 8, 3, 20, 8, 120) -> stage 1 = full, same true.
%   3. searchPlan, fields {Cm_q, Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table,
%      Cnt_table}, 'LatDropCmq' true:
%        3.3.1.1-CatA-other (zeta_d, 1.2)  -> 'lateral', idx 2:7, dropped {Cm_q},
%                                             method 'hybrid' (6 > 2)
%        3.3.1.3-CatA (spiral_T2_s, Inf)   -> 'surrogate', idx 2:7, dropped {Cm_q}
%        3.2.2.1.1-CatA (CAP, 0.05)        -> 'longitudinal', idx 1:3, dropped {}
%                                             ('Lattice' true: method 'lattice';
%                                             with 'Method' 'sqp': 'sqp';
%                                             'Lattice' false: 'hybrid')
%        'LatDropCmq' false                -> 3.3.1.1: 'full', idx 1:7
%        fields {Cl_p, Cn_r}               -> 'full', dropped {}
%        fields {Cm_q}                     -> 'full', idx 1, dropped {}
%        no new option (defaults)          -> 3.3.1.1: 'full', idx 1:7
%   4. gatePlan: the 3.3.1.1 plan of item 3 with check.passed true -> idx 2:7
%      unchanged, latCheck.passed true; with passed false -> idx 1:7, all
%      seven fields, dropped {}, mode 'full', method 'hybrid', reason
%      containing 'FAILED'; the surrogate plan with passed false -> mode
%      'surrogate', idx 1:7 (sabotage S8X-6).
%   5. invarianceCheck: th0 = [1 1], ths = [0.5 1; 1.5 1]:
%        value 2 + th(2)                 -> passed
%        value 2 + 1e-12 th(1)           -> passed (2.5e-13 relative)
%        value 2 + 1e-6 th(1)            -> failed, reason containing 'relative'
%        value Inf everywhere            -> passed
%        status INFEASIBLE at th(1) = 1.5 -> failed, reason containing 'INFEASIBLE'

    properties (Constant)
        F7 = {'Cm_q', 'Cm_basic', 'Cm_de', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'}
    end

    methods (Static)
        function e = fake(method, st, lo, hi, reason, bwSt, bwReason)
            if nargin < 6, bwSt = 'OK'; bwReason = ''; end
            e.status = 'DONE';
            e.plan = struct('method', method);
            if isempty(st)
                e.csr = struct([]);
            else
                e.csr = struct('judged', struct('status', st, 'alphaLo', lo, 'alphaHi', hi, 'reason', reason));
            end
            e.widths = struct('widthScale', 1, 'bw', struct('status', bwSt, 'reason', bwReason));
        end

        function q = qv(v, st)
            if nargin < 2, st = 'OK'; end
            q = struct('status', st, 'value', v);
        end

        function q = holeAt(t)
            if t(1) == 1.5, q = tUqStaged.qv(NaN, 'INFEASIBLE'); else, q = tUqStaged.qv(1); end
        end
    end

    methods (Test)
        function stagePlanTruthTable(tc)
            f = @tUqStaged.fake;
            T = {f('lattice', 'OK', 0.9, 0.905, ''), false
                 f('hybrid', 'OK', 0.85, 0.86, ''), true
                 f('hybrid', 'OK', 1.25, 1.26, ''), false
                 f('hybrid', 'ROBUST_TO_CAP', 3, Inf, ''), false
                 f('hybrid', 'NOT_ASSESSABLE', 0, 2.76, 'a point is not OK'), true
                 f('hybrid', 'NOT_ASSESSABLE', 1.3, Inf, 'FC-901: the local stage did not converge'), true
                 f('hybrid', 'NOT_ASSESSABLE', 1.3, Inf, 'MOVING_LIMIT: still moving'), false
                 f('hybrid', 'NOT_ASSESSABLE', 1.3, Inf, 'the search budget (15 box searches) is used up'), true
                 f('hybrid', 'OK', 1.2, 1.21, ''), true
                 f('hybrid', 'OK', 0.79, 0.8, ''), true
                 f('hybrid', 'OK', 0.78, 0.79, ''), false
                 f('hybrid', 'OK', 1.21, 1.22, ''), false
                 f('hybrid', 'OK', 1.3, 1.31, '', 'NOT_ASSESSABLE', 'FC-901: x'), false
                 f('hybrid', '', NaN, NaN, '', 'NOT_ASSESSABLE', 'FC-901: x'), true
                 f('hybrid', '', NaN, NaN, '', 'OK', ''), false};
            for k = 1:size(T, 1)
                [need, why] = vital.uq.stagePlan(T{k, 1}, 'Band', [0.8 1.2]);
                tc.verifyEqual(need, T{k, 2}, sprintf('header 1 row %d (%s)', k, why));
                tc.verifyNotEmpty(why, sprintf('header 1 row %d: why', k));
            end
            [~, why] = vital.uq.stagePlan(T{1, 1});
            tc.verifySubstring(why, 'lattice', 'header 1: lattice row');
            e = f('hybrid', 'OK', 0.85, 0.86, ''); e.status = 'NOT_ASSESSABLE';
            tc.verifyFalse(vital.uq.stagePlan(e), 'header 1: not searched');
        end

        function stageOneBudget(tc)
            full = struct('NumCandidates', 4, 'DEPopulation', 16, 'DEGenerations', 8, 'N', 200, 'NumLHS', 32, 'MaxEvals', 150);
            [s1, same] = vital.uq.stageBudget(full);
            tc.verifyEqual([s1.NumCandidates s1.DEPopulation s1.DEGenerations s1.N s1.NumLHS s1.MaxEvals], ...
                [2 8 4 200 32 150], 'header 2');
            tc.verifyFalse(same, 'header 2');
            full = struct('NumCandidates', 1, 'DEPopulation', 8, 'DEGenerations', 3, 'N', 20, 'NumLHS', 8, 'MaxEvals', 120);
            [s1, same] = vital.uq.stageBudget(full);
            tc.verifyEqual(s1, full, 'header 2');
            tc.verifyTrue(same, 'header 2');
        end

        function lateralPlanDropsCmq(tc)
            F = tc.F7;
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, F, 'LatDropCmq', true);
            tc.verifyEqual({p.mode, p.idx, p.dropped, p.method}, {'lateral', 2:7, {'Cm_q'}, 'hybrid'}, 'header 3');
            p = vital.uq.searchPlan('3.3.1.3-CatA', {'spiral_T2_s'}, Inf, F, 'LatDropCmq', true);
            tc.verifyEqual({p.mode, p.idx, p.dropped}, {'surrogate', 2:7, {'Cm_q'}}, 'header 3: spiral');
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, F, 'LatDropCmq', true, 'Lattice', true);
            tc.verifyEqual({p.mode, p.idx, p.method}, {'longitudinal', 1:3, 'lattice'}, 'header 3: lon');
            tc.verifyEmpty(p.dropped, 'header 3: lon');
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, F, 'Lattice', true, 'Method', 'sqp');
            tc.verifyEqual(p.method, 'sqp', 'header 3: forced method');
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, F, 'Lattice', false);
            tc.verifyEqual(p.method, 'hybrid', 'header 3: no lattice');
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, F, 'LatDropCmq', false);
            tc.verifyEqual({p.mode, p.idx}, {'full', 1:7}, 'header 3: LatDropCmq false');
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, {'Cl_p', 'Cn_r'}, 'LatDropCmq', true);
            tc.verifyEqual({p.mode, p.idx}, {'full', 1:2}, 'header 3: no Cm_q');
            tc.verifyEmpty(p.dropped);
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, {'Cm_q'}, 'LatDropCmq', true);
            tc.verifyEqual({p.mode, p.idx}, {'full', 1}, 'header 3: only Cm_q');
            tc.verifyEmpty(p.dropped);
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, F);
            tc.verifyEqual({p.mode, p.idx}, {'full', 1:7}, 'header 3: defaults');
        end

        function gateFallback(tc)
            F = tc.F7;
            p0 = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, F, 'LatDropCmq', true);
            p = vital.uq.gatePlan(p0, struct('passed', true, 'reason', 'equal'), F);
            tc.verifyEqual(p.idx, 2:7, 'header 4: gate passed');
            tc.verifyTrue(p.latCheck.passed);
            p = vital.uq.gatePlan(p0, struct('passed', false, 'reason', 'margin 1.2 vs 1.1'), F);
            tc.verifyEqual({p.idx, p.fields, p.mode, p.method}, {1:7, F, 'full', 'hybrid'}, 'header 4: fallback');
            tc.verifyEmpty(p.dropped, 'header 4: fallback');
            tc.verifySubstring(p.reason, 'FAILED');
            ps = vital.uq.searchPlan('3.3.1.3-CatA', {'spiral_T2_s'}, Inf, F, 'LatDropCmq', true);
            p = vital.uq.gatePlan(ps, struct('passed', false, 'reason', 'x'), F);
            tc.verifyEqual({p.mode, p.idx}, {'surrogate', 1:7}, 'header 4: surrogate fallback');
        end

        function invarianceCheckToys(tc)
            th0 = [1 1]; ths = [0.5 1; 1.5 1];
            c = vital.uq.invarianceCheck(@(t) tUqStaged.qv(2 + t(2)), th0, ths);
            tc.verifyTrue(c.passed, c.reason);
            c = vital.uq.invarianceCheck(@(t) tUqStaged.qv(2 + 1e-12 * t(1)), th0, ths);
            tc.verifyTrue(c.passed, c.reason);
            c = vital.uq.invarianceCheck(@(t) tUqStaged.qv(2 + 1e-6 * t(1)), th0, ths);
            tc.verifyFalse(c.passed, c.reason);
            tc.verifySubstring(c.reason, 'relative');
            c = vital.uq.invarianceCheck(@(t) tUqStaged.qv(Inf), th0, ths);
            tc.verifyTrue(c.passed, c.reason);
            c = vital.uq.invarianceCheck(@(t) tUqStaged.holeAt(t), th0, ths);
            tc.verifyFalse(c.passed, c.reason);
            tc.verifySubstring(c.reason, 'INFEASIBLE');
        end
    end
end
