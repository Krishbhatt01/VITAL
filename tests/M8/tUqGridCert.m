classdef (TestTags = {'M8'}) tUqGridCert < vital.test.VitalTestCase
%TUQGRIDCERT  M8 amendment R4-3 (docs/PLAN_M5_M8.md, "Amendment R4", 2026-10-13):
%   groups searched over at most 2 parameters are decided on a grid:
%   vital.uq.boundWorst(problem, 'Method', 'grid'). Closed-form margins, no
%   aircraft. Expected runtime: a few seconds.
%   Grid (defaults, stated here): 'GridPoints' 11 per dimension over the box
%   (spacing 0.1 in the box coordinate t = (theta - lo)/(hi - lo)), local
%   refinement around the arg-min ('GridLocalLevels' 3: the cells touching
%   the best vertex are halved, three times), and Lipschitz-driven refinement:
%   per axis i the Lipschitz estimate is L_i = LipschitzFactor (2) x the
%   largest measured slope |dm|/dt_i over every evaluated grid edge along i;
%   a cell's certified lower bound is min(vertex margins) - sum_i L_i dt_i/2;
%   cells whose bound is below the reserve are halved ('GridMaxRefine' 8
%   levels, 'GridBudget' 5000 points). Status: 'VIOLATED' on a grid
%   counterexample; 'OK' when every cell's bound is >= reserve (the
%   certificate); otherwise 'NOT_ASSESSABLE' with a reason starting 'GRID'.
%   The status label is 'grid-certified (Lipschitz estimate)'. u = 2 t - 1
%   (|u_i| <= 1); boxes h = 0.2 about 1.
%
%   PRE-REGISTERED (agent uq3, 2026-10-13, with the stubs, before any
%   implementation):
%   1. SMOOTH INTERIOR MINIMUM (ANALYTIC): m = 0.2 + (u1 - 0.3)^2 +
%      2 (u2 + 0.2)^2, true minimum 0.2 at u = (0.3, -0.2): status 'OK',
%      bw.label 'grid-certified (Lipschitz estimate)', converged true,
%      certificate.certified true, 0 <= certificate.lowerBound <= 0.2; value in
%      [0.2, 0.2 + 1e-3] (u = (0.3, -0.2) lies on the once-refined lattice
%      next to the best base vertex).
%   2. KINKED VALLEY (the uq2 toy of tests/M8/tUqR3Fixes.m header 2, where sqp
%      gave FC-901): m = 0.10 + 0.6 |u1 - 0.3| + 0.4 (u2 + 0.2)^2. Now DECIDED:
%      status 'OK' (not NOT_ASSESSABLE / FC-901), certified, 0 <= lowerBound
%      <= 0.10, value in [0.10, 0.10 + 1e-3]. Shifted down by 0.15 (minimum
%      -0.05 on the crease, negative only for |u1 - 0.3| < 0.083; the base
%      grid at u1 = 0.2, 0.4 sees +0.01 there): 'VIOLATED', value in
%      [-0.05, -0.04].
%   3. LIPSCHITZ SAFETY FACTOR (ANALYTIC): for the linear m = 0.5 + 0.1 u1 -
%      0.3 u2 every secant equals the gradient: dm/dt = (0.2, -0.6), so
%      certificate.maxSlope = [0.2 0.6] and certificate.L = 2 x maxSlope =
%      [0.4 1.2] (1e-12 abs); certificate.factor 2; status 'OK' with
%      0 <= lowerBound <= value = 0.1 (the vertex u = (-1, 1), 1e-12).
%   4. NOT CERTIFIABLE: m = 1e-4 + 0.6 |u1 - 0.31| + 0.4 (u2 + 0.2)^2 (true
%      minimum 1e-4 > 0, between lattice points) with 'GridMaxRefine' 4: the
%      bound cannot reach 0 -> status 'NOT_ASSESSABLE', reason starting
%      'GRID', certificate.certified false, never 'VIOLATED', value >= 1e-4.
%   5. NON-OK GRID POINTS: m = 0.5 + 0.1 u2 with status 'INFEASIBLE' where
%      u1 > 0.9: 'NOT_ASSESSABLE', reason mentions 'INFEASIBLE', nonOK not
%      empty, certificate.certified false.
%   6. ONE PARAMETER: m = 0.05 + 0.5 |u - 0.2| (d = 1): 'OK', certified,
%      value in [0.05, 0.05 + 1e-3].
%   7. POINT SET: every evaluated theta inside [lo, hi] (exact); the base
%      grid (11 x 11 = 121 lattice points) is evaluated: at least 121 points
%      with phase 'grid'; the box corners are among them; a second run gives
%      identical points (deterministic).
%   8. FAILURE MODES: 'GridPoints' 1, 'LipschitzFactor' 0.5, 'Method' 'newton'
%      -> vital:badInput.

    methods (Static)
        function P = problem(d, fcn)
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.lo = 0.8 * ones(1, d); P.hi = 1.2 * ones(1, d);
            P.conditions = {1};
            P.condLabels = {'c1'};
            P.pointFcn = @(th, c) tUqGridCert.wrap(fcn((th - 1) / 0.2));
            P.confirmFcn = [];
        end

        function q = wrap(m)
            if isstruct(m), q = m; return; end
            q = struct('status', 'OK', 'margin', m, 'record', 'R1', 'reason', '');
        end

        function q = holes(u)
            if u(1) > 0.9
                q = struct('status', 'INFEASIBLE', 'margin', NaN, 'record', '', 'reason', 'trim: INFEASIBLE (toy)');
            else
                q = tUqGridCert.wrap(0.5 + 0.1 * u(2));
            end
        end
    end

    methods (Test)
        function smoothInteriorMinimum(tc)
            P = tUqGridCert.problem(2, @(u) 0.2 + (u(1) - 0.3)^2 + 2 * (u(2) + 0.2)^2);
            bw = vital.uq.boundWorst(P, 'Method', 'grid');
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyEqual(bw.label, 'grid-certified (Lipschitz estimate)');
            tc.verifyTrue(bw.converged);
            tc.verifyTrue(bw.certificate.certified);
            tc.verifyWithin(bw.certificate.lowerBound, 0, 0.2, 'ANALYTIC', 'header 1: 0 <= bound <= true minimum', ...
                'Quantity', 'certified lower bound');
            tc.verifyWithin(bw.value, 0.2, 0.2 + 1e-3, 'ANALYTIC', 'header 1: refined minimum', 'Quantity', 'bound-worst');
        end

        function kinkedValleyDecided(tc)
            f = @(u) 0.10 + 0.6 * abs(u(1) - 0.3) + 0.4 * (u(2) + 0.2)^2;
            bw = vital.uq.boundWorst(tUqGridCert.problem(2, f), 'Method', 'grid');
            tc.verifyEqual(bw.status, 'OK', ['header 2: decided, not FC-901: ' bw.reason]);
            tc.verifyTrue(bw.certificate.certified);
            tc.verifyWithin(bw.certificate.lowerBound, 0, 0.10, 'ANALYTIC', 'header 2', 'Quantity', 'kink certified bound');
            tc.verifyWithin(bw.value, 0.10, 0.10 + 1e-3, 'ANALYTIC', 'header 2', 'Quantity', 'kink bound-worst');
            bw = vital.uq.boundWorst(tUqGridCert.problem(2, @(u) f(u) - 0.15), 'Method', 'grid');
            tc.verifyEqual(bw.status, 'VIOLATED', ['header 2 shifted: ' bw.reason]);
            tc.verifyWithin(bw.value, -0.05, -0.04, 'ANALYTIC', 'header 2 shifted', 'Quantity', 'shifted kink bound-worst');
        end

        function lipschitzSafetyFactor(tc)
            bw = vital.uq.boundWorst(tUqGridCert.problem(2, @(u) 0.5 + 0.1 * u(1) - 0.3 * u(2)), 'Method', 'grid');
            ce = bw.certificate;
            tc.verifyTol(ce.maxSlope, [0.2 0.6], 1e-12, 'abs', 'ANALYTIC', 'header 3: secant = gradient', 'Quantity', 'max slope');
            tc.verifyTol(ce.L, [0.4 1.2], 1e-12, 'abs', 'ANALYTIC', 'header 3: L = 2 x max slope', 'Quantity', 'Lipschitz estimate');
            tc.verifyEqual(ce.factor, 2);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTol(bw.value, 0.1, 1e-12, 'abs', 'ANALYTIC', 'header 3: vertex (-1, 1)', 'Quantity', 'bound-worst');
            tc.verifyWithin(ce.lowerBound, 0, bw.value, 'ANALYTIC', 'header 3', 'Quantity', 'certified bound');
        end

        function notCertifiable(tc)
            f = @(u) 1e-4 + 0.6 * abs(u(1) - 0.31) + 0.4 * (u(2) + 0.2)^2;
            bw = vital.uq.boundWorst(tUqGridCert.problem(2, f), 'Method', 'grid', 'GridMaxRefine', 4);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifyTrue(startsWith(bw.reason, 'GRID'), bw.reason);
            tc.verifyFalse(bw.certificate.certified);
            tc.verifyGreaterThanOrEqual(bw.value, 1e-4);
        end

        function nonOKGridPoint(tc)
            bw = vital.uq.boundWorst(tUqGridCert.problem(2, @(u) tUqGridCert.holes(u)), 'Method', 'grid');
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifySubstring(bw.reason, 'INFEASIBLE');
            tc.verifyNotEmpty(bw.nonOK);
            tc.verifyFalse(bw.certificate.certified);
        end

        function oneParameter(tc)
            bw = vital.uq.boundWorst(tUqGridCert.problem(1, @(u) 0.05 + 0.5 * abs(u - 0.2)), 'Method', 'grid');
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTrue(bw.certificate.certified);
            tc.verifyWithin(bw.value, 0.05, 0.05 + 1e-3, 'ANALYTIC', 'header 6', 'Quantity', '1-D bound-worst');
        end

        function gridPointSet(tc)
            P = tUqGridCert.problem(2, @(u) 0.2 + (u(1) - 0.3)^2 + 2 * (u(2) + 0.2)^2);
            bw = vital.uq.boundWorst(P, 'Method', 'grid');
            th = bw.points.theta;
            tc.verifyTrue(all(all(th >= P.lo & th <= P.hi)), 'header 7: inside the box');
            g = strcmp(bw.points.phase, 'grid');
            tc.verifyGreaterThanOrEqual(sum(g), 121, 'header 7: base grid evaluated');
            V = [0.8 0.8; 0.8 1.2; 1.2 0.8; 1.2 1.2];
            tc.verifyTrue(all(ismember(V, th, 'rows')), 'header 7: corners evaluated');
            bw2 = vital.uq.boundWorst(P, 'Method', 'grid');
            tc.verifyEqual(bw2.points, bw.points, 'header 7: deterministic');
        end

        function badGridOptions(tc)
            P = tUqGridCert.problem(2, @(u) 1);
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'grid', 'GridPoints', 1), 'vital:badInput');
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'grid', 'LipschitzFactor', 0.5), 'vital:badInput');
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'newton'), 'vital:badInput');
        end
    end
end
