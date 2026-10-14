classdef (TestTags = {'M8'}) tUqHybrid < vital.test.VitalTestCase
%TUQHYBRID  M8 amendment R4-4 (docs/PLAN_M5_M8.md, "Amendment R4", 2026-10-13):
%   hybrid global + local search for groups with more than 2 searched
%   parameters, vital.uq.boundWorst(problem, 'Method', 'hybrid'): centre, 2^d
%   corners, seeded LHS, then a seeded differential evolution
%   (vital.uq.diffEvolution: DE/rand/1/bin, own implementation, the Global
%   Optimization Toolbox is not installed; the LHS points are its initial
%   population), then fminsearch (Nelder-Mead) with a bound transform
%   theta = lo + (hi - lo)(1 + sin z)/2 from the NumStarts best distinct points
%   of all earlier stages; every point is kept; convergence is reported per
%   stage; the status needs the local stage converged (fminsearch exit flag 1)
%   on every start, else FC-901. The method rule vital.uq.searchMethod: 'grid'
%   for at most GridMaxDim (2) searched parameters, 'hybrid' above.
%   Closed-form margins, no aircraft. Expected runtime: about 10 s.
%
%   PRE-REGISTERED (agent uq3, 2026-10-13, with the stubs, before any
%   implementation):
%   1. MULTIMODAL (d = 3, u = (theta - 1)/0.2 in [-1, 1]^3, c = (0.35, -0.36,
%      0.37)): m = -0.05 + sum_i [0.5 (u_i - c_i)^2 + 0.04 (1 - cos(4 pi
%      (u_i - c_i)))]; global minimum -0.05 at u = c (ANALYTIC); about 0.1 %
%      of the box has m < 0. The centre (0.287) and the corner (1, -1, 1)
%      (0.707) are the two best points of centre + corners (ANALYTIC, checked
%      in the test).
%      a) INDEP characterization of the toy (MATLAB's own fminsearch,
%         unconstrained, from those two starts): it stops in local minima with
%         m > 0 (characterized before this file: 0.2703 and 0.0568).
%      b) REG prediction: the local-only VITAL search from the same starts
%         ('Method' 'hybrid', 'NumLHS' 0, 'DEPopulation' 0, 'NumStarts' 2,
%         'MaxEvals' 300) misses the global minimum: value > 0, status not
%         'VIOLATED'.
%      c) REG prediction: the hybrid with 'NumLHS' 32, 'DEPopulation' 20,
%         'DEGenerations' 40, 'NumStarts' 2, 'MaxEvals' 300 finds it:
%         status 'VIOLATED', value in [-0.05, -0.04], arg-min within 0.05 of
%         c (Euclidean, in u).
%   2. BOUNDS (sabotage target "DE ignores bounds"): the cliff toy of
%      tests/M8/tBoundWorstToys.m header 1 lifted to d = 3 (m = 0.5 - 0.3
%      (theta1 - 1) + 0.2 (theta2 - 1) + 0.1 (theta3 - 1) inside |theta - 1|
%      <= 0.2501, -5 beyond; box h = 0.25) with 'DEPopulation' 12,
%      'DEGenerations' 15: every evaluated point (in particular every 'de'
%      point) inside [lo, hi] (exact); the cliff is never seen; value 0.35 at
%      the corner (1.25, 0.75, 0.75) (1e-12 abs); status 'OK'.
%   3. PER-STAGE CONVERGENCE (convex, interior minimum, d = 3; default DE
%      budget, 'MaxEvals' 300 per Nelder-Mead start):
%      m = 1 + (u1 - 0.3)^2 + 2 (u2 + 0.2)^2 + (u3 - 0.1)^2: status 'OK',
%      bw.label 'search estimate (hybrid: differential evolution + Nelder-Mead)',
%      bw.stages names {'centre', 'corner', 'lhs', 'de', 'local'} in that order,
%      each with nEval >= 0 and a 'converged' field; the local stage converged;
%      the 'de' stage reports its generations; value within 1e-3 of 1 and
%      arg-min within 0.02 (in u) of (0.3, -0.2, 0.1).
%   4. NOT CONVERGED -> FC-901: the same toy with 'MaxEvals' 3 (a Nelder-Mead
%      start needs d + 1 = 4 evaluations for its first simplex): status
%      'NOT_ASSESSABLE', reason starting 'FC-901', converged false.
%      A counterexample stays definitive: the toy minus 1.5 with 'MaxEvals' 3
%      -> 'VIOLATED'.
%   5. SEEDED: two runs of item 3 give identical points (isequal).
%   6. vital.uq.diffEvolution ON ITS OWN (sphere f = sum((x - 0.3)^2) on
%      [-1, 1]^2, 'Population' 10, 'Generations' 30, 'Seed' 7): best f <= 1e-4
%      (REG), every evaluated x inside the bounds (exact), nEval = 10 x 31
%      (the initial population and 30 generations; exact); the same seed gives
%      identical results; with 'Init' (10 x 2 given points and their values)
%      nEval = 10 x 30 (the initial population is not re-evaluated).
%   7. METHOD SELECTION (R4-3/R4-4 rule): vital.uq.searchMethod(1) and (2) ->
%      'grid', (3) and (7) -> 'hybrid'; with 'GridMaxDim' 3, (3) -> 'grid'.
%      vital.uq.searchPlan over the R4 fields {Cm_q Cm_basic Cm_de Cl_p Cn_r
%      Cl_table Cnt_table}: 3.2.2.1.1-CatA -> mode 'longitudinal', idx [1 2 3],
%      method 'hybrid'; 3.3.1.1-CatA-other -> 'full', idx 1:7, 'hybrid'. Over
%      the legacy fields {Cm_q Cm_table Cl_p Cn_r Cl_table Cnt_table}:
%      3.2.2.1.1-CatA -> 'longitudinal', idx [1 2], 'grid'.
%   8. FAILURE MODES: 'DEPopulation' 3 (DE/rand/1 needs 4 members), 'DEF' 0,
%      'DECR' 1.5 -> vital:badInput.
%
%   FAILED HYPOTHESES (first runs of the implementation, 2026-10-13, after the
%   RED gate and before the GREEN gate; the originals above are kept, no
%   tolerance changed):
%   1b. FAILED: the local-only VITAL search from the centre and the corner
%       (1, -1, 1) reached the global minimum (value -0.0499996). Cause: the
%       VITAL local stage starts every Nelder-Mead simplex with steps of
%       0.07-0.23 rad in z (the offset 3 of its bound transform, which keeps
%       a centre start from fminsearch's 0.00025-wide first simplex and its
%       immediate false convergence; NOTES.md), i.e. up to ~0.2 in u, while
%       the unconstrained fminsearch of 1a starts from u = 0 with a 0.00025
%       step. The wide first simplex hops the ridges of this Rastrigin-like toy
%       (basins about 0.25 wide). 1a and 1c still hold and are kept.
%   1b'. CORRECTED (ANALYTIC design, independent of the implementation): a
%       start that is a strict local minimum inside a basin wider than any
%       Nelder-Mead step. d = 3, u in [-1, 1]^3, a = (0.8, 0, -0.8):
%         m = min(0.3 + 0.05 |u|^2, 0.6 |u - a| - 0.15)
%       global minimum -0.15 at u = a (the cone tip, a kink); the bowl's
%       minimum 0.3 at the centre (a strict local minimum: the cone there is
%       0.6 x 1.131 - 0.15 = 0.53, and within 0.3 of the centre it stays above
%       the bowl, 0.6 x 0.83 - 0.15 = 0.35 > 0.3 + 0.05 x 0.09). Every corner
%       has the bowl value 0.45 (the corners nearest a have cone 0.474), so the
%       two starts of the local-only search (NumLHS 0, DEPopulation 0) are the
%       centre and the first corner (-1, -1, -1), whose descent to the centre
%       stays at |u - a| >= 1.13 (cone >= 0.53). REG predictions: the
%       local-only search gives value 0.3 (1e-6 abs) and is not 'VIOLATED'; the
%       hybrid of 1c (NumLHS 32, DEPopulation 20, DEGenerations 40,
%       NumStarts 2, MaxEvals 300; the cone basin |u - a| < ~0.75 holds about
%       10 % of the box, so the LHS seeds DE inside it) gives 'VIOLATED', value
%       in [-0.15, -0.13] and an arg-min within 0.05 of a.
%   1b'' FAILED as well (same run of the corrected file, before GREEN): the
%       local-only VITAL search again reached the cone tip (value -0.149867 at
%       u = (0.80, 0.00, -0.80)), so even a start inside a 0.3-wide bowl is
%       left by the Nelder-Mead stage (its reflections and expansions are not
%       confined to the first simplex). Not corrected again: the claim "the
%       VITAL local stage alone misses" is NOT established by these toys and
%       is reported as an open point. What stands: 1a (INDEP: a plain local
%       search from the given starts misses the global minimum), 1c and the
%       hybrid part of 1b' (the hybrid finds it).
%   2.  FAILED: 'OK' with the default local budget (MaxEvals 60): status
%       NOT_ASSESSABLE (FC-901), the second Nelder-Mead start exhausted 60
%       evaluations at the vertex value 0.35. Cause (characterized with
%       MATLAB's fminsearch on the same bound transform): at a box vertex the
%       transform is flat (d theta/dz = 0), and Nelder-Mead needs about
%       60-140 evaluations in 3-D to meet TolX 1e-3 and TolFun 1e-4 there.
%       The bound, cliff and vertex expectations held.
%   2'. CORRECTED: the same toy with 'MaxEvals' 300 (the budget of items 1c
%       and 3): status 'OK'; the other expectations of 2 unchanged.
%   9. CENTRE START (added during the implementation, 2026-10-13, as the
%      regression test of a defect found while characterizing 1b: a
%      Nelder-Mead start whose transformed coordinate is exactly 0 gets
%      fminsearch's 0.00025-wide first simplex and stops at once; fixed by the
%      offset 3 in z). ANALYTIC: m = 0.5 + 0.1 |u|^2 - 0.15 u1 (d = 3): the
%      centre (0.5) is better than every corner (>= 0.65), so the single start
%      (NumLHS 0, DEPopulation 0, NumStarts 1, MaxEvals 1000) is the centre;
%      the minimum is 0.44375 at u = (0.75, 0, 0). Expected: status 'OK',
%      value within 1e-3 of 0.44375, arg-min within 0.05 of (0.75, 0, 0).

    properties (Constant)
        C = [0.35 -0.36 0.37]
    end

    methods (Static)
        function P = problem(d, h, fcn)
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.lo = 1 - h * ones(1, d); P.hi = 1 + h * ones(1, d);
            P.conditions = {1};
            P.condLabels = {'c1'};
            P.pointFcn = @(th, c) struct('status', 'OK', 'margin', fcn(th), 'record', 'R1', 'reason', '');
            P.confirmFcn = [];
        end

        function m = multi(u)
            c = tUqHybrid.C;
            m = -0.05 + sum(0.5 * (u - c).^2 + 0.04 * (1 - cos(4 * pi * (u - c))));
        end

        function m = cliff3(th)
            if any(abs(th - 1) > 0.2501)
                m = -5;
            else
                m = 0.5 - 0.3 * (th(1) - 1) + 0.2 * (th(2) - 1) + 0.1 * (th(3) - 1);
            end
        end

        function m = quad3(th, shift)
            u = (th - 1) / 0.2;
            m = 1 + (u(1) - 0.3)^2 + 2 * (u(2) + 0.2)^2 + (u(3) - 0.1)^2 - shift;
        end
    end

    methods (Test)
        function multimodalNeedsGlobalStage(tc)
            f = @(u) tUqHybrid.multi(u);
            tc.verifyTol(f(tUqHybrid.C), -0.05, 1e-15, 'abs', 'ANALYTIC', 'header 1: global minimum', 'Quantity', 'm(c)');
            V = 2 * (dec2bin(0:7) - '0') - 1;
            fv = arrayfun(@(i) f(V(i, :)), 1:8);
            [fc, ic] = min(fv);
            tc.verifyEqual(V(ic, :), [1 -1 1], 'header 1: best corner');
            tc.verifyLessThan(f([0 0 0]), fc, 'header 1: the centre is the best point');
            o = optimset('Display', 'off', 'TolX', 1e-6, 'TolFun', 1e-8, 'MaxFunEvals', 5000);
            for s = {[0 0 0], [1 -1 1]}
                [~, fl] = fminsearch(f, s{1}, o);
                tc.verifyGreaterThan(fl, 0, 'header 1a (INDEP): plain local search misses the global minimum');
            end
            P = tUqHybrid.problem(3, 0.2, @(th) f((th - 1) / 0.2));
            bl = vital.uq.boundWorst(P, 'Method', 'hybrid', 'NumLHS', 0, 'DEPopulation', 0, 'NumStarts', 2, 'MaxEvals', 300);
            % header 1b FAILED (see the header); kept as a record, not checked: bl.value > 0
            tc.log(1, sprintf('header 1b (failed hypothesis): local-only value %.6g, %s', bl.value, bl.status));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'NumLHS', 32, 'DEPopulation', 20, 'DEGenerations', 40, ...
                'NumStarts', 2, 'MaxEvals', 300);
            tc.verifyEqual(bw.status, 'VIOLATED', ['header 1c (REG): ' bw.reason]);
            tc.verifyWithin(bw.value, -0.05, -0.04, 'ANALYTIC', 'header 1c: global minimum found', 'Quantity', 'hybrid bound-worst');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - tUqHybrid.C), 0.05, 'header 1c: arg-min');
        end

        function deRespectsBounds(tc)
            P = tUqHybrid.problem(3, 0.25, @(th) tUqHybrid.cliff3(th));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'DEPopulation', 12, 'DEGenerations', 15);
            th = bw.points.theta;
            tc.verifyTrue(all(all(th >= P.lo & th <= P.hi)), 'header 2: every point inside the box');
            de = strcmp(bw.points.phase, 'de');
            tc.verifyGreaterThan(sum(de), 0, 'header 2: DE points evaluated');
            tc.verifyFalse(any(bw.points.margin == -5), 'header 2: the cliff is never seen');
            tc.verifyTol(bw.value, 0.35, 1e-12, 'abs', 'ANALYTIC', 'header 2: corner minimum', 'Quantity', 'bound-worst');
            tc.verifyEqual(bw.theta, [1.25 0.75 0.75]);
            tc.log(1, sprintf('header 2 (failed hypothesis with MaxEvals 60): %s', bw.status));
            % header 2' (corrected): the local budget of items 1c and 3
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'DEPopulation', 12, 'DEGenerations', 15, 'MaxEvals', 300);
            th = bw.points.theta;
            tc.verifyTrue(all(all(th >= P.lo & th <= P.hi)), 'header 2'': every point inside the box');
            tc.verifyFalse(any(bw.points.margin == -5), 'header 2'': the cliff is never seen');
            tc.verifyTol(bw.value, 0.35, 1e-12, 'abs', 'ANALYTIC', 'header 2'': corner minimum', 'Quantity', 'bound-worst (2'')');
            tc.verifyEqual(bw.status, 'OK', ['header 2'': ' bw.reason]);
        end

        function localMinimumBasinNeedsGlobalStage(tc)
            % header 1b' (corrected toy)
            a = [0.8 0 -0.8];
            f = @(u) min(0.3 + 0.05 * sum(u.^2), 0.6 * norm(u - a) - 0.15);
            tc.verifyTol(f(a), -0.15, 1e-15, 'abs', 'ANALYTIC', 'header 1b'': global minimum', 'Quantity', 'm(a)');
            tc.verifyTol(f([0 0 0]), 0.3, 1e-15, 'abs', 'ANALYTIC', 'header 1b'': bowl minimum', 'Quantity', 'm(0)');
            V = 2 * (dec2bin(0:7) - '0') - 1;
            tc.verifyTol(arrayfun(@(i) f(V(i, :)), 1:8), 0.45 * ones(1, 8), 1e-12, 'abs', 'ANALYTIC', ...
                'header 1b'': every corner on the bowl', 'Quantity', 'corner margins');
            P = tUqHybrid.problem(3, 0.2, @(th) f((th - 1) / 0.2));
            bl = vital.uq.boundWorst(P, 'Method', 'hybrid', 'NumLHS', 0, 'DEPopulation', 0, 'NumStarts', 2, 'MaxEvals', 300);
            % header 1b' local-only prediction FAILED (see the header); kept as a record, not checked
            tc.log(1, sprintf('header 1b'' (failed hypothesis): local-only value %.6g, %s, starts %s', bl.value, ...
                bl.status, mat2str(vertcat(bl.optimizer.start), 4)));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'NumLHS', 32, 'DEPopulation', 20, 'DEGenerations', 40, ...
                'NumStarts', 2, 'MaxEvals', 300);
            tc.verifyEqual(bw.status, 'VIOLATED', ['header 1b'' (REG): ' bw.reason]);
            tc.verifyWithin(bw.value, -0.15, -0.13, 'ANALYTIC', 'header 1b'': cone tip found', 'Quantity', 'hybrid bound-worst (1b'')');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - a), 0.05, 'header 1b'': arg-min');
        end

        function centreStartDoesNotStopAtOnce(tc)
            % header 9 (regression test added during the implementation)
            f = @(u) 0.5 + 0.1 * sum(u.^2) - 0.15 * u(1);
            V = 2 * (dec2bin(0:7) - '0') - 1;
            tc.verifyGreaterThan(min(arrayfun(@(i) f(V(i, :)), 1:8)), f([0 0 0]), 'header 9: the centre is the best start');
            P = tUqHybrid.problem(3, 0.2, @(th) f((th - 1) / 0.2));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'NumLHS', 0, 'DEPopulation', 0, 'NumStarts', 1, 'MaxEvals', 1000);
            tc.verifyEqual(bw.optimizer(1).start, P.nominal, 'header 9: the start is the centre');
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTol(bw.value, 0.44375, 1e-3, 'abs', 'ANALYTIC', 'header 9: interior minimum', 'Quantity', 'bound-worst (centre start)');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - [0.75 0 0]), 0.05, 'header 9: arg-min');
        end

        function perStageConvergence(tc)
            P = tUqHybrid.problem(3, 0.2, @(th) tUqHybrid.quad3(th, 0));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'MaxEvals', 300);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyEqual(bw.label, 'search estimate (hybrid: differential evolution + Nelder-Mead)');
            tc.verifyEqual({bw.stages.name}, {'centre', 'corner', 'lhs', 'de', 'local'});
            tc.verifyTrue(all(isfield(bw.stages, {'nEval', 'converged', 'message'})));
            tc.verifyTrue(all([bw.stages.nEval] >= 0));
            st = bw.stages(strcmp({bw.stages.name}, 'local'));
            tc.verifyTrue(isequal(st.converged, true), 'header 3: local stage converged');
            de = bw.stages(strcmp({bw.stages.name}, 'de'));
            tc.verifyTrue(isfield(de, 'generations') && de.generations >= 1, 'header 3: DE generations reported');
            tc.verifyTol(bw.value, 1, 1e-3, 'abs', 'ANALYTIC', 'header 3: interior minimum', 'Quantity', 'bound-worst');
            tc.verifyLessThanOrEqual(norm((bw.theta - 1) / 0.2 - [0.3 -0.2 0.1]), 0.02, 'header 3: arg-min');
            bw2 = vital.uq.boundWorst(P, 'Method', 'hybrid', 'MaxEvals', 300);
            tc.verifyEqual(bw2.points, bw.points, 'header 5: seeded');
        end

        function notConvergedIsFC901(tc)
            P = tUqHybrid.problem(3, 0.2, @(th) tUqHybrid.quad3(th, 0));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'MaxEvals', 3);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifyTrue(startsWith(bw.reason, 'FC-901'), bw.reason);
            tc.verifyFalse(bw.converged);
            P = tUqHybrid.problem(3, 0.2, @(th) tUqHybrid.quad3(th, 1.5));
            bw = vital.uq.boundWorst(P, 'Method', 'hybrid', 'MaxEvals', 3);
            tc.verifyEqual(bw.status, 'VIOLATED', bw.reason);
        end

        function diffEvolutionUnit(tc)
            f = @(x) sum((x - 0.3).^2);
            [x, fb, info] = vital.uq.diffEvolution(f, [-1 -1], [1 1], 'Population', 10, 'Generations', 30, 'Seed', 7);
            tc.verifyLessThanOrEqual(fb, 1e-4, 'header 6 (REG)');
            tc.verifyEqual(fb, f(x));
            tc.verifyTrue(all(all(info.X >= -1 & info.X <= 1)), 'header 6: inside the bounds');
            tc.verifyEqual(info.nEval, 10 * 31);
            [x2, fb2, info2] = vital.uq.diffEvolution(f, [-1 -1], [1 1], 'Population', 10, 'Generations', 30, 'Seed', 7);
            tc.verifyEqual({x2, fb2, info2.X}, {x, fb, info.X}, 'header 6: seeded');
            X0 = [linspace(-1, 1, 10).' linspace(1, -1, 10).'];
            F0 = arrayfun(@(i) f(X0(i, :)), (1:10).');
            [~, ~, info3] = vital.uq.diffEvolution(f, [-1 -1], [1 1], 'Population', 10, 'Generations', 30, 'Seed', 7, ...
                'Init', X0, 'InitF', F0);
            tc.verifyEqual(info3.nEval, 10 * 30, 'header 6: the given population is not re-evaluated');
        end

        function methodSelection(tc)
            tc.verifyEqual(vital.uq.searchMethod(1), 'grid');
            tc.verifyEqual(vital.uq.searchMethod(2), 'grid');
            tc.verifyEqual(vital.uq.searchMethod(3), 'hybrid');
            tc.verifyEqual(vital.uq.searchMethod(7), 'hybrid');
            tc.verifyEqual(vital.uq.searchMethod(3, 'GridMaxDim', 3), 'grid');
            F = {'Cm_q', 'Cm_basic', 'Cm_de', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'};
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP', 'omega_nsp_rad_s'}, 0.05, F);
            tc.verifyEqual(p.mode, 'longitudinal');
            tc.verifyEqual(p.idx, [1 2 3]);
            tc.verifyEqual(p.method, 'hybrid');
            p = vital.uq.searchPlan('3.3.1.1-CatA-other', {'zeta_d'}, 1.2, F);
            tc.verifyEqual(p.mode, 'full');
            tc.verifyEqual(p.idx, 1:7);
            tc.verifyEqual(p.method, 'hybrid');
            F1 = {'Cm_q', 'Cm_table', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'};
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, F1);
            tc.verifyEqual(p.idx, [1 2]);
            tc.verifyEqual(p.method, 'grid');
        end

        function badHybridOptions(tc)
            P = tUqHybrid.problem(3, 0.2, @(th) tUqHybrid.quad3(th, 0));
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'hybrid', 'DEPopulation', 3), 'vital:badInput');
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'hybrid', 'DEF', 0), 'vital:badInput');
            tc.verifyError(@() vital.uq.boundWorst(P, 'Method', 'hybrid', 'DECR', 1.5), 'vital:badInput');
        end
    end
end
