classdef (TestTags = {'M8'}) tBoundWorstToys < vital.test.VitalTestCase
%TBOUNDWORSTTOYS  M8: vital.uq.boundWorst on closed-form margin functions (no
%   aircraft), the plan's toy counterexamples and failure modes.
%   Normalized coordinates u_i = (theta_i - 1)/h_i, h_i the box half-width; the
%   box is |u_i| <= 1. Search defaults: centre, 2^d corners, 32 seeded LHS
%   points, fmincon (sqp) from the 2 best points, 60 evaluations each, forward
%   differences of step 1e-3 (in theta).
%
%   PRE-REGISTERED (with the stubs, before any implementation; every expected
%   value is ANALYTIC from the closed forms below):
%   1. CLIFF JUST OUTSIDE THE BOX (d = 2, h = [0.25 0.25]):
%        m = 0.5 - 0.3 (theta1 - 1) + 0.2 (theta2 - 1) inside |theta_i - 1| <=
%        0.2501, m = -5 beyond (the cliff, 4e-4 outside the box).
%      The search never evaluates outside the box (every evaluated theta in
%      [lo, hi], exact), never sees the cliff, and returns the in-box minimum
%      0.375 at the corner theta = [1.25 0.75] (1e-12 abs; the corner is
%      evaluated exactly), status 'OK', converged.
%   2. INTERIOR INTERACTION VALLEY OFF BOTH AXES (d = 2, h = [0.2 0.2]):
%        m = 1 - 2 exp(-((u1 - 0.5)^2 + (u2 + 0.5)^2) / 0.35^2)
%      A one-at-a-time sweep (each u_j over [-1, 1], the other 0) has minimum
%      1 - 2 exp(-0.25/0.1225) = 0.74013 > 0: it misses the valley (checked in
%      the test on a 201-point sweep). boundWorst: status 'VIOLATED', value in
%      [-1, -0.99] (the global minimum is -1; -0.99 allows |u - u*| <= 0.025),
%      arg-min within 0.05 (in u) of (0.5, -0.5).
%   3. MOVING LIMIT (d = 1, h = 0.5; five conditions c1..c5, candidates c1..c4;
%      margins m1 = 0.100 - 0.010 (theta - 1), m2 = 0.110, m3 = 0.120,
%      m4 = 0.130, m5 = 0.140 - 0.100 (theta - 1), gradient 0.100 for the
%      moving condition c5): the search value is 0.095 at theta = 1.5, c1; the
%      confirmation (all five conditions) finds 0.090 at c5, which REPLACES it:
%      value 0.090, cond 'c5', confirmation.moved true, searchValue 0.095
%      (1e-12 abs), status 'OK'; nominal critical c1, 0.100.
%   4. ACTIVE-SET SWITCH INSIDE THE BOX (d = 2, h = [0.2 0.2]; one condition, two
%      records): mA = 0.30 + 0.1 u1, mB = 0.40 - 0.3 u2, m = min, record = the
%      arg-min. Nominal: 0.30, record 'A'. Bound-worst: 0.100 (1e-12) at
%      u2 = +1 (theta2 = 1.2 exactly), record 'B'; status 'OK'.
%   5. NON-CONVERGENCE (FC-901; d = 2, h = [0.2 0.2]):
%        m = 1 + (u1 - 0.3)^2 + 2 (u2 + 0.2)^2   (interior minimum 1, no
%      counterexample). MaxEvals 3 (one forward-difference gradient in 2-D
%      needs 3 evaluations): no start converges -> status 'NOT_ASSESSABLE',
%      reason starting 'FC-901', converged false, value = the minimum over the
%      evaluated points (finite, > 1). With the default budget the same problem
%      converges: status 'OK', value within 1e-4 of 1 (the forward-difference
%      bias of step 1e-3 on curvatures 50 and 100 in theta moves the stationary
%      point by ~5e-4 in theta; excess ~2e-5), arg-min within 0.01 (in u) of
%      (0.3, -0.2).
%   6. A COUNTEREXAMPLE IS DEFINITIVE: problem 5 minus 1.5 (centre margin
%      -0.33) with MaxEvals 3: status 'VIOLATED' although converged is false.
%   7. NON-OK POINTS: m = 0.5 + 0.1 u2, but status 'INFEASIBLE' (margin NaN)
%      where u1 > 0.9 -> 'NOT_ASSESSABLE', reason mentions 'INFEASIBLE', nonOK
%      not empty, value 0.4 (min over the OK points, 1e-12). With m = 0.05 +
%      0.1 u2 instead (minimum -0.05): 'VIOLATED' (definitive).
%   8. POINT SET (structure of the search, problem 1 with NumLHS 8): exactly one
%      'centre' point at the nominal; the 'corner' points are exactly the 2^d
%      vertices; 8 'lhs' points, stratified (in every dimension each of the 8
%      equal strata holds exactly one point); the fmincon starts are the 2 best
%      distinct points of the first three phases; fmincon points <= 2 x 60;
%      a second run gives identical points (seeded).
%   9. FAILURE MODES: lo > hi, nominal outside the box, no condition, a
%      pointFcn that is not a function handle -> vital:badInput.

    methods (Static)
        function P = problem(d, h, fcn, labels)
            if nargin < 4, labels = {'c1'}; end
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.lo = 1 - h; P.hi = 1 + h;
            P.conditions = num2cell(1:numel(labels));
            P.condLabels = labels;
            P.pointFcn = fcn;
            P.confirmFcn = [];
        end

        function q = pt(m, rec)
            if nargin < 2, rec = 'R1'; end
            q = struct('status', 'OK', 'margin', m, 'record', rec, 'reason', '');
        end

        function q = cliff(th)
            if any(abs(th - 1) > 0.2501)
                q = tBoundWorstToys.pt(-5);
            else
                q = tBoundWorstToys.pt(0.5 - 0.3 * (th(1) - 1) + 0.2 * (th(2) - 1));
            end
        end

        function m = valley(u)
            m = 1 - 2 * exp(-((u(1) - 0.5)^2 + (u(2) + 0.5)^2) / 0.35^2);
        end

        function q = moving(th, k)
            m = [0.100 - 0.010 * (th - 1), 0.110, 0.120, 0.130, 0.140 - 0.100 * (th - 1)];
            q = tBoundWorstToys.pt(m(k));
        end

        function c = movingConfirm(th)
            m = [0.100 - 0.010 * (th - 1), 0.110, 0.120, 0.130, 0.140 - 0.100 * (th - 1)];
            [mm, k] = min(m);
            c = struct('status', 'OK', 'margin', mm, 'condLabel', sprintf('c%d', k), 'record', 'R1', 'reason', '');
        end

        function q = switching(th)
            u = (th - 1) / 0.2;
            mA = 0.30 + 0.1 * u(1); mB = 0.40 - 0.3 * u(2);
            if mA <= mB, q = tBoundWorstToys.pt(mA, 'A'); else, q = tBoundWorstToys.pt(mB, 'B'); end
        end

        function q = quad(th, shift)
            u = (th - 1) / 0.2;
            q = tBoundWorstToys.pt(1 + (u(1) - 0.3)^2 + 2 * (u(2) + 0.2)^2 - shift);
        end

        function q = holes(th, base)
            u = (th - 1) / 0.2;
            if u(1) > 0.9
                q = struct('status', 'INFEASIBLE', 'margin', NaN, 'record', '', 'reason', 'trim: INFEASIBLE (toy)');
            else
                q = tBoundWorstToys.pt(base + 0.1 * u(2));
            end
        end
    end

    methods (Test)
        function cliffOutsideNeverSeen(tc)
            P = tBoundWorstToys.problem(2, [0.25 0.25], @(th, c) tBoundWorstToys.cliff(th));
            bw = vital.uq.boundWorst(P);
            th = bw.points.theta;
            tc.verifyTrue(all(all(th >= P.lo & th <= P.hi)), 'every evaluated point inside the box');
            tc.verifyFalse(any(bw.points.margin == -5), 'the cliff is never seen');
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTrue(bw.converged);
            tc.verifyTol(bw.value, 0.375, 1e-12, 'abs', 'ANALYTIC', 'header 1: in-box minimum at the corner', 'Quantity', 'bound-worst');
            tc.verifyEqual(bw.theta, [1.25 0.75]);
        end

        function interiorValleyFound(tc)
            u = linspace(-1, 1, 201);
            oat = min([arrayfun(@(a) tBoundWorstToys.valley([a 0]), u), arrayfun(@(a) tBoundWorstToys.valley([0 a]), u)]);
            tc.verifyTol(oat, 1 - 2 * exp(-0.25 / 0.1225), 1e-12, 'abs', 'ANALYTIC', 'header 2: one-at-a-time minimum', 'Quantity', 'OAT min');
            tc.verifyGreaterThan(oat, 0, 'a one-at-a-time sweep misses the valley');
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.pt(tBoundWorstToys.valley((th - 1) / 0.2)));
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'VIOLATED', bw.reason);
            tc.verifyWithin(bw.value, -1, -0.99, 'ANALYTIC', 'header 2: valley floor -1', 'Quantity', 'bound-worst');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - [0.5 -0.5]), 0.05, 'arg-min at the valley');
        end

        function movingLimitCaught(tc)
            P = tBoundWorstToys.problem(1, 0.5, @(th, c) tBoundWorstToys.moving(th, c), {'c1', 'c2', 'c3', 'c4'});
            P.confirmFcn = @(th) tBoundWorstToys.movingConfirm(th);
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.nominal.cond, 'c1');
            tc.verifyTol(bw.nominal.margin, 0.100, 1e-12, 'abs', 'ANALYTIC', 'header 3', 'Quantity', 'nominal margin');
            tc.verifyTol(bw.searchValue, 0.095, 1e-12, 'abs', 'ANALYTIC', 'header 3: search over c1..c4', 'Quantity', 'search value');
            tc.verifyTrue(bw.confirmation.evaluated);
            tc.verifyTrue(bw.confirmation.moved, 'the confirmation catches the moving limit');
            tc.verifyTol(bw.value, 0.090, 1e-12, 'abs', 'ANALYTIC', 'header 3: c5 at theta 1.5', 'Quantity', 'bound-worst after confirmation');
            tc.verifyEqual(bw.cond, 'c5');
            tc.verifyEqual(bw.theta, 1.5);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
        end

        function activeSetSwitch(tc)
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.switching(th));
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.nominal.record, 'A');
            tc.verifyTol(bw.nominal.margin, 0.30, 1e-12, 'abs', 'ANALYTIC', 'header 4', 'Quantity', 'nominal margin');
            tc.verifyEqual(bw.record, 'B', 'the reported critical record switches');
            tc.verifyTol(bw.value, 0.100, 1e-12, 'abs', 'ANALYTIC', 'header 4', 'Quantity', 'bound-worst');
            tc.verifyEqual(bw.theta(2), 1.2);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
        end

        function notConvergedIsNotAssessable(tc)
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.quad(th, 0));
            bw = vital.uq.boundWorst(P, 'MaxEvals', 3);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE');
            tc.verifyTrue(startsWith(bw.reason, 'FC-901'), bw.reason);
            tc.verifyFalse(bw.converged);
            tc.verifyTrue(isfinite(bw.value) && bw.value > 1, 'value = min over the evaluated points');
            tc.verifyEqual(bw.value, min(bw.points.margin));
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTrue(bw.converged);
            tc.verifyTol(bw.value, 1, 1e-4, 'abs', 'ANALYTIC', 'header 5: interior minimum (FD bias)', 'Quantity', 'bound-worst');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - [0.3 -0.2]), 0.01, 'arg-min');
        end

        function counterexampleIsDefinitive(tc)
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.quad(th, 1.5));
            bw = vital.uq.boundWorst(P, 'MaxEvals', 3);
            tc.verifyFalse(bw.converged);
            tc.verifyEqual(bw.status, 'VIOLATED', bw.reason);
            tc.verifyLessThan(bw.value, 0);
        end

        function nonOKPointIsNotAssessable(tc)
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.holes(th, 0.5));
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE');
            tc.verifySubstring(bw.reason, 'INFEASIBLE');
            tc.verifyNotEmpty(bw.nonOK);
            tc.verifyTol(bw.value, 0.4, 1e-12, 'abs', 'ANALYTIC', 'header 7: min over OK points', 'Quantity', 'bound-worst');
            P = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.holes(th, 0.05));
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'VIOLATED', bw.reason);
        end

        function searchPointSet(tc)
            P = tBoundWorstToys.problem(2, [0.25 0.25], @(th, c) tBoundWorstToys.cliff(th));
            bw = vital.uq.boundWorst(P, 'NumLHS', 8);
            ph = bw.points.phase;
            th = bw.points.theta;
            c = strcmp(ph, 'centre');
            tc.verifyEqual(sum(c), 1);
            tc.verifyEqual(th(c, :), P.nominal);
            V = th(strcmp(ph, 'corner'), :);
            tc.verifyEqual(size(V, 1), 4, '2^d corners');
            tc.verifyEqual(sortrows(V), sortrows([0.75 0.75; 0.75 1.25; 1.25 0.75; 1.25 1.25]), 'the corners are the vertices');
            L = th(strcmp(ph, 'lhs'), :);
            tc.verifyEqual(size(L, 1), 8);
            for j = 1:2
                s = floor((L(:, j) - P.lo(j)) / (P.hi(j) - P.lo(j)) * 8);
                tc.verifyEqual(sort(s(:)).', 0:7, sprintf('LHS stratified in dimension %d', j));
            end
            first = ~startsWith(ph, 'fmincon');
            [~, k] = sort(bw.points.margin(first));
            T = th(first, :); T = T(k, :);
            [~, iu] = unique(T, 'rows', 'stable');
            starts = T(iu(1:2), :);
            tc.verifyEqual(vertcat(bw.optimizer.start), starts, 'fmincon starts from the 2 best distinct points');
            tc.verifyLessThanOrEqual(sum(startsWith(ph, 'fmincon')), 120);
            tc.verifyEqual(bw.nEvaluated, numel(ph));
            bw2 = vital.uq.boundWorst(P, 'NumLHS', 8);
            tc.verifyEqual(bw2.points, bw.points, 'seeded: identical points');
        end

        function badProblems(tc)
            ok = tBoundWorstToys.problem(2, [0.2 0.2], @(th, c) tBoundWorstToys.quad(th, 0));
            P = ok; P.lo = [1.3 0.8];
            tc.verifyError(@() vital.uq.boundWorst(P), 'vital:badInput');
            P = ok; P.nominal = [1.5 1];
            tc.verifyError(@() vital.uq.boundWorst(P), 'vital:badInput');
            P = ok; P.conditions = {}; P.condLabels = {};
            tc.verifyError(@() vital.uq.boundWorst(P), 'vital:badInput');
            P = ok; P.pointFcn = 'quad';
            tc.verifyError(@() vital.uq.boundWorst(P), 'vital:badInput');
        end
    end
end
