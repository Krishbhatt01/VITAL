classdef (TestTags = {'M8'}) tUqR3Fixes < vital.test.VitalTestCase
%TUQR3FIXES  M8 design fixes after review R3 (docs/PLAN_M5_M8.md, "Amendment after
%   review R3", coordinator 2026-10-09): closed-form toys and pure functions, no
%   aircraft. Expected runtime: a few seconds.
%   Normalized coordinates u_i = (theta_i - 1)/h_i, h_i the box half-width.
%   Search defaults as tBoundWorstToys (centre, 2^d corners, 32 seeded LHS
%   points, fmincon sqp from the best points, 60 evaluations each).
%
%   PRE-REGISTERED (agent uq2, 2026-10-09, written with the stubs, before any
%   implementation of the amendment):
%   1. R3-M4 MOVING LIMIT RE-SEARCH (ANALYTIC; every value is a closed form below).
%      d = 2, h = [0.2 0.2], four conditions c1..c4 with linear margins
%        c1 = 1.00 - 0.1 u1 - 0.1 u2      c2 = 0.55 + 0.1 u1 + 0.1 u2
%        c3 = 0.55 - 0.1 u1 + 0.4 u2      c4 = 0.62 - 0.2 u1 + 0.4 u2
%      Only c1 is a candidate; the confirmation is the minimum over c1..c4 at
%      the arg-min (it returns the condition). A minimum of linear functions
%      over a box is attained at a vertex: V1 = u(1,1), V2 = u(-1,-1),
%      V3 = u(1,-1). NumStarts 1, NumLHS 8.
%        round 1 {c1}:          search 0.80 at V1 (c1); confirmation 0.75 at c2 -> moved
%        round 2 {c1,c2}:       search 0.35 at V2 (c2); confirmation 0.25 at c3 -> moved
%        round 3 {c1,c2,c3}:    search 0.05 at V3 (c3); confirmation 0.02 at c4 -> moved
%        round 4 {c1,..,c4}:    search 0.02 at V3 (c4); confirmation 0.02 at c4 -> not moved
%      a) default MaxRounds 3: status 'NOT_ASSESSABLE', reason starting
%         'MOVING_LIMIT'; 3 rounds recorded with exactly the values above
%         (search values, arg-min theta (exact vertices), conditions,
%         confirmation margins and conditions, moved = [1 1 1], candidate
%         labels {c1}, {c1 c2}, {c1 c2 c3}); the final confirmation REPLACES the
%         search value: value 0.02 at c4, confirmation.moved true. 1e-12 abs.
%      b) MaxRounds 4: status 'OK', 4 rounds, value = searchValue = 0.02 at c4,
%         theta = V3 = [1.2 0.8], final confirmation.moved false.
%      c) MaxRounds 1: status 'NOT_ASSESSABLE' ('MOVING_LIMIT'), 1 round, value
%         0.75 at c2. MaxRounds 0 or 1.5 -> vital:badInput.
%      d) Never VIOLATED: every margin is > 0 (reserve 0).
%   2. R3-M2 KINKED INTERIOR VALLEY. d = 2, h = [0.2 0.2],
%        m = 0.10 + 0.6 |u1 - 0.3| + 0.4 (u2 + 0.2)^2
%      Two planes meet along the interior crease u1 = 0.3 (a V across it; the
%      minimum 0.10 sits ON the crease at u = (0.3, -0.2)). NOTE: review R3
%      calls it a "min-of-two-planes valley"; a minimum of two planes is a ridge
%      whose box minimum is at a vertex, so the interior V is the larger of the
%      two planes (max) -- the shape R3 found for 3.2.2.1.2-CatA (margin falling
%      to a kink, then jumping). Expected (before the run):
%      a) ANALYTIC: every evaluated margin >= 0.10 (the closed-form minimum), so
%         bw.value >= 0.10: the bound-worst is an upper bound on the true
%         minimum; status is never 'VIOLATED'.
%      b) REG prediction: bw.value <= 0.13 (stratified LHS puts a u1 sample
%         within 1/32 of the crease; sqp descends towards it).
%      c) REG prediction of the STATUS: 'NOT_ASSESSABLE' with reason starting
%         'FC-901': the forward-difference gradient flips sign across the
%         crease, so sqp cannot meet its first-order optimality test there and
%         runs out of its 60-evaluation budget (or stops with a flag <= 0).
%      d) The same valley shifted down by 0.15 (minimum -0.05 on the crease,
%         negative only within |u1 - 0.3| < 0.083): status 'VIOLATED' (REG
%         prediction), value in [-0.05, 0) (the lower end ANALYTIC).
%   3. R3-M3(b) SURROGATE SEARCH (vital.uq.surrogateWorst; ANALYTIC). The
%      surrogate s (e.g. Re of the spiral root, 1/s) is MAXIMIZED over the box;
%      the true margin is the time-to-double margin m = (ln2/s - 12)/12 for
%      s > 0, +Inf for s <= 0 (requirement T2 >= 12 s, scale 12 s).
%      a) s = -0.002 + 0.001 u1 + 0.0005 u2 (max -0.0005 at u = (1, 1)):
%         status 'OK', value +Inf, surrogate.value -0.0005 (1e-12 abs), theta
%         [1.2 1.2] (exact vertex), reason starting 'stable over the box
%         (surrogate search)'; vital.uq.verdict with cpLower 0.99 -> 'ROBUST'.
%      b) s = 0.02 + 0.03 u1 + 0.001 u2 (max 0.051 at (1, 1)): status 'OK',
%         value (ln2/0.051 - 12)/12 = 0.13259 (closed form, 1e-12 abs), record
%         'T2': an unstable spiral that still meets the requirement.
%      c) s = 0.05 + 0.05 u1 + 0.001 u2 (max 0.101): status 'VIOLATED', value
%         (ln2/0.101 - 12)/12 = -0.42809 (closed form, 1e-12 abs).
%      d) s of (a) but the surrogate is not available (status 'MODE_MISSING')
%         where u1 > 0.9: status 'NOT_ASSESSABLE', reason mentions
%         'MODE_MISSING', value +Inf, verdict 'NOT_ASSESSABLE' (cpLower 0.99).
%      e) Moving limit of the surrogate (d = 1, h = 0.2; conditions c1, c2;
%         candidate c1 only): s1 = -0.003 + 0.001 u, s2 = -0.001 + 0.0005 u;
%         the confirmation (max over c1, c2) at the round-1 arg-max u = 1 finds
%         c2 (-0.0005 > -0.002) -> re-search with c2 -> round 2 not moved:
%         status 'OK', 2 rounds, value +Inf, surrogate.value -0.0005 (1e-12),
%         bw.cond 'c2'.
%   4. R3-M5 MAHALANOBIS DISTANCE (vital.uq.mahalanobis; ANALYTIC).
%      theta = the x1 lower corner of (Cm_q, Cm_table) with the lateral
%      multipliers at 1: [1 - k1 0.10, 1 - k1 0.05, 1, 1, 1, 1], sigma =
%      [0.10 0.05 0.10 0.10 0.05 0.05] (JUDGMENT, uq/f16_uncertainty.json),
%      k1 = sqrt(2) erfinv(0.99): D = sqrt(2) k1 = 3.6428 (1e-12 rel; R3 3.5
%      "3.64", 5e-3 abs). With 'Dof' 2 the tail P(chi2_2 >= D^2) =
%      exp(-D^2/2) = 1.31e-3 (1e-12 rel; R3 "about 1.3e-3"). Default Dof =
%      numel(theta) = 6: closed form exp(-x/2)(1 + x/2 + x^2/8), x = D^2.
%      sigma doubled -> D halved (1e-15 rel). sigma <= 0 or a size mismatch ->
%      vital:badInput.
%   5. m2 JOINT-BOX COVERAGE (vital.uq.boxCoverage; ANALYTIC + R3 3.3). For the
%      spec's x1 box: joint = prod_i erf(k_i/sqrt2) (1e-14 abs) = 0.97070
%      (R3 3.3; 5e-6 abs); groups: 0.99 for d = 1 (1e-12), erf(k2/sqrt2)^2 =
%      0.99519 for d = 2 (R3; 5e-6). The x1.5 box gives the identical numbers
%      (isequal): box and Monte Carlo sigma scale together.
%   6. R3-M3 SEARCH PLAN (vital.uq.searchPlan; contract amendment), fields
%      {Cm_q Cm_table Cl_p Cnr_table Cl_table Cnt_table}:
%        3.2.2.1.1-CatA {CAP, omega_nsp_rad_s}, margin 0.05 -> 'longitudinal',
%            idx [1 2], fields {Cm_q Cm_table}, sampledOnly false
%        3.2.1.2-CatA {T2_phugoid_s, zeta_p}, 0.49           -> 'longitudinal'
%        3.3.1.1-CatA-other {omega_nd_rad_s, zeta_d, ...}, 1.2 -> 'full', idx 1:6
%        3.3.1.3-CatA {spiral_T2_s}, +Inf                     -> 'surrogate',
%            idx 1:6, objective mentions 'spiral'
%        3.3.1.3-CatA {spiral_T2_s}, 0.95 (finite)            -> 'full'
%        3.3.1.4-CatA-other {coupled_roll_spiral_present}, 0  -> 'full',
%            sampledOnly true, sampledReason mentions 'binary'
%        a +Inf group with a non-spiral metric ({zeta_d})     -> 'full'
%        'LonOnly' false: 3.2.2.1.1-CatA                      -> 'full'
%        fields {Cnr_table} only: 3.2.2.1.1-CatA              -> 'full'
%        fields {Cl_p Cm_table Cm_q}: 3.2.2.1.1-CatA -> 'longitudinal', idx [2 3]

    methods (Static)
        function P = problem(d, h, fcn, labels)
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.lo = 1 - h; P.hi = 1 + h;
            P.conditions = num2cell(1:numel(labels));
            P.condLabels = labels;
            P.pointFcn = fcn;
            P.confirmFcn = [];
        end

        function m = chainMargins(th)
            u = (th - 1) / 0.2;
            m = [1.00 - 0.1 * u(1) - 0.1 * u(2), 0.55 + 0.1 * u(1) + 0.1 * u(2), ...
                 0.55 - 0.1 * u(1) + 0.4 * u(2), 0.62 - 0.2 * u(1) + 0.4 * u(2)];
        end

        function q = chainPoint(th, k)
            m = tUqR3Fixes.chainMargins(th);
            q = struct('status', 'OK', 'margin', m(k), 'record', 'R1', 'reason', '');
        end

        function c = chainConfirm(th)
            [mm, k] = min(tUqR3Fixes.chainMargins(th));
            c = struct('status', 'OK', 'margin', mm, 'condLabel', sprintf('c%d', k), 'cond', k, ...
                'record', 'R1', 'reason', '');
        end

        function q = kink(th, shift)
            u = (th - 1) / 0.2;
            m = 0.10 + 0.6 * abs(u(1) - 0.3) + 0.4 * (u(2) + 0.2)^2 - shift;
            q = struct('status', 'OK', 'margin', m, 'record', 'R1', 'reason', '');
        end

        function q = sur(th, a, missing)
            u = (th - 1) / 0.2;
            if missing && u(1) > 0.9
                q = struct('status', 'MODE_MISSING', 'value', NaN, 'record', '', 'reason', 'no spiral root (toy)');
                return
            end
            q = struct('status', 'OK', 'value', a(1) + a(2) * u(1) + a(3) * u(2), 'record', 'spiral root', 'reason', '');
        end

        function q = t2margin(s)
            if s > 0, m = (log(2) / s - 12) / 12; else, m = Inf; end
            q = struct('status', 'OK', 'margin', m, 'record', 'T2', 'reason', '');
        end

        function q = sur2(th, k)
            u = (th - 1) / 0.2;
            s = [-0.003 + 0.001 * u, -0.001 + 0.0005 * u];
            q = struct('status', 'OK', 'value', s(k), 'record', 'spiral root', 'reason', '');
        end

        function c = sur2Confirm(th)
            u = (th - 1) / 0.2;
            [s, k] = max([-0.003 + 0.001 * u, -0.001 + 0.0005 * u]);
            c = struct('status', 'OK', 'value', s, 'condLabel', sprintf('c%d', k), 'cond', k, ...
                'record', 'spiral root', 'reason', '');
        end

        function q = sur2Margin(th, k)
            u = (th - 1) / 0.2;
            s = [-0.003 + 0.001 * u, -0.001 + 0.0005 * u];
            q = tUqR3Fixes.t2margin(s(k));
        end
    end

    methods (Test)
        function movingLimitReSearch(tc)
            P = tUqR3Fixes.problem(2, [0.2 0.2], @(th, k) tUqR3Fixes.chainPoint(th, k), {'c1'});
            P.confirmFcn = @(th) tUqR3Fixes.chainConfirm(th);
            o = {'NumStarts', 1, 'NumLHS', 8};
            c = 'header 1 (ANALYTIC)';
            % a) default: 3 rounds, still moving
            bw = vital.uq.boundWorst(P, o{:});
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifyTrue(startsWith(bw.reason, 'MOVING_LIMIT'), bw.reason);
            tc.assertNumElements(bw.rounds, 3);
            sv = [0.80 0.35 0.05]; cv = [0.75 0.25 0.02];
            L = P.lo; H = P.hi;
            th = [H(1) H(2); L(1) L(2); H(1) L(2)];
            cands = {{'c1'}, {'c1', 'c2'}, {'c1', 'c2', 'c3'}};
            for k = 1:3
                R = bw.rounds(k);
                tc.verifyTol(R.searchValue, sv(k), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', sprintf('round %d search value', k));
                tc.verifyEqual(R.theta, th(k, :), sprintf('round %d arg-min vertex', k));
                tc.verifyEqual(R.cond, sprintf('c%d', k), sprintf('round %d search condition', k));
                tc.verifyEqual(R.candidates, cands{k}, sprintf('round %d candidates', k));
                tc.verifyTrue(R.confirmation.moved, sprintf('round %d moved', k));
                tc.verifyEqual(R.confirmation.cond, sprintf('c%d', k + 1));
                tc.verifyTol(R.confirmation.margin, cv(k), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', sprintf('round %d confirmation', k));
            end
            tc.verifyTrue(bw.confirmation.moved);
            tc.verifyTol(bw.value, 0.02, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'bound-worst (confirmation replaces)');
            tc.verifyEqual(bw.cond, 'c4');
            % b) one more round settles it
            bw = vital.uq.boundWorst(P, o{:}, 'MaxRounds', 4);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyNumElements(bw.rounds, 4);
            tc.verifyFalse(bw.confirmation.moved);
            tc.verifyTol(bw.value, 0.02, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'bound-worst, 4 rounds');
            tc.verifyTol(bw.searchValue, 0.02, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'search value, 4 rounds');
            tc.verifyEqual(bw.theta, [H(1) L(2)]);
            tc.verifyEqual(bw.cond, 'c4');
            % c) one round only
            bw = vital.uq.boundWorst(P, o{:}, 'MaxRounds', 1);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifyTrue(startsWith(bw.reason, 'MOVING_LIMIT'), bw.reason);
            tc.verifyNumElements(bw.rounds, 1);
            tc.verifyTol(bw.value, 0.75, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'bound-worst, 1 round');
            tc.verifyEqual(bw.cond, 'c2');
            tc.verifyError(@() vital.uq.boundWorst(P, 'MaxRounds', 0), 'vital:badInput');
            tc.verifyError(@() vital.uq.boundWorst(P, 'MaxRounds', 1.5), 'vital:badInput');
        end

        function kinkedValley(tc)
            P = tUqR3Fixes.problem(2, [0.2 0.2], @(th, c) tUqR3Fixes.kink(th, 0), {'c1'});
            bw = vital.uq.boundWorst(P);
            tc.verifyGreaterThanOrEqual(min(bw.points.margin), 0.10 - 1e-12, 'header 2a: no point below the true minimum');
            tc.verifyWithin(bw.value, 0.10 - 1e-12, 0.13, 'REG', 'header 2a (ANALYTIC lower end) / 2b (REG upper end)', ...
                'Quantity', 'kinked valley bound-worst');
            tc.verifyNotEqual(bw.status, 'VIOLATED', 'header 2a: no counterexample exists');
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', ['header 2c (REG prediction): ' bw.reason]);
            tc.verifyTrue(startsWith(bw.reason, 'FC-901'), ['header 2c: ' bw.reason]);
            P = tUqR3Fixes.problem(2, [0.2 0.2], @(th, c) tUqR3Fixes.kink(th, 0.15), {'c1'});
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'VIOLATED', ['header 2d: ' bw.reason]);
            tc.verifyWithin(bw.value, -0.05 - 1e-12, 0, 'REG', 'header 2d', 'Quantity', 'shifted kinked valley bound-worst');
            tc.verifyLessThan(bw.value, 0);
        end

        function surrogateSearch(tc)
            c = 'header 3 (ANALYTIC)';
            % a) stable over the box
            a = [-0.002 0.001 0.0005];
            P = tUqR3Fixes.problem(2, [0.2 0.2], @(th, k) tUqR3Fixes.sur(th, a, false), {'c1'});
            M = @(th, k) tUqR3Fixes.t2margin(a(1) + a(2) * (th(1) - 1) / 0.2 + a(3) * (th(2) - 1) / 0.2);
            bw = vital.uq.surrogateWorst(P, M);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyEqual(bw.value, Inf);
            tc.verifyTol(bw.surrogate.value, -0.0005, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'surrogate maximum (a)');
            tc.verifyEqual(bw.theta, P.hi);
            tc.verifyTrue(startsWith(bw.reason, 'stable over the box (surrogate search)'), bw.reason);
            tc.verifyEqual(vital.uq.verdict(bw, struct('cpLower', 0.99)).verdict, 'ROBUST');
            % b) unstable, requirement met
            a = [0.02 0.03 0.001];
            P.pointFcn = @(th, k) tUqR3Fixes.sur(th, a, false);
            M = @(th, k) tUqR3Fixes.t2margin(a(1) + a(2) * (th(1) - 1) / 0.2 + a(3) * (th(2) - 1) / 0.2);
            bw = vital.uq.surrogateWorst(P, M);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyTol(bw.value, (log(2) / 0.051 - 12) / 12, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'T2 margin (b)');
            tc.verifyEqual(bw.record, 'T2');
            % c) unstable, requirement violated
            a = [0.05 0.05 0.001];
            P.pointFcn = @(th, k) tUqR3Fixes.sur(th, a, false);
            M = @(th, k) tUqR3Fixes.t2margin(a(1) + a(2) * (th(1) - 1) / 0.2 + a(3) * (th(2) - 1) / 0.2);
            bw = vital.uq.surrogateWorst(P, M);
            tc.verifyEqual(bw.status, 'VIOLATED', bw.reason);
            tc.verifyTol(bw.value, (log(2) / 0.101 - 12) / 12, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'T2 margin (c)');
            % d) surrogate not available in part of the box
            a = [-0.002 0.001 0.0005];
            P.pointFcn = @(th, k) tUqR3Fixes.sur(th, a, true);
            M = @(th, k) tUqR3Fixes.t2margin(a(1) + a(2) * (th(1) - 1) / 0.2 + a(3) * (th(2) - 1) / 0.2);
            bw = vital.uq.surrogateWorst(P, M);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifySubstring(bw.reason, 'MODE_MISSING');
            tc.verifyEqual(bw.value, Inf);
            tc.verifyEqual(vital.uq.verdict(bw, struct('cpLower', 0.99)).verdict, 'NOT_ASSESSABLE');
            % e) moving limit of the surrogate
            P = tUqR3Fixes.problem(1, 0.2, @(th, k) tUqR3Fixes.sur2(th, k), {'c1'});
            P.confirmFcn = @(th) tUqR3Fixes.sur2Confirm(th);
            bw = vital.uq.surrogateWorst(P, @(th, k) tUqR3Fixes.sur2Margin(th, k));
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyNumElements(bw.rounds, 2);
            tc.verifyEqual(bw.value, Inf);
            tc.verifyTol(bw.surrogate.value, -0.0005, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'surrogate maximum (e)');
            tc.verifyEqual(bw.cond, 'c2');
        end

        function mahalanobisDistance(tc)
            k1 = sqrt(2) * erfinv(0.99);
            sig = [0.10 0.05 0.10 0.10 0.05 0.05];
            th = [1 - k1 * 0.10, 1 - k1 * 0.05, 1, 1, 1, 1];
            [D, p6] = vital.uq.mahalanobis(th, ones(1, 6), sig);
            c = 'header 4 (ANALYTIC)';
            tc.verifyTol(D, sqrt(2) * k1, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'Mahalanobis D');
            tc.verifyTol(D, 3.64, 5e-3, 'abs', 'INDEP', 'reports/review/R3_REVIEW.md 3.5', 'Quantity', 'Mahalanobis D (R3)');
            x = D^2;
            tc.verifyTol(p6, exp(-x / 2) * (1 + x / 2 + x^2 / 8), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'chi2_6 tail');
            [D2, p2] = vital.uq.mahalanobis(th, ones(1, 6), sig, 'Dof', 2);
            tc.verifyEqual(D2, D);
            tc.verifyTol(p2, exp(-x / 2), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'chi2_2 tail');
            tc.verifyTol(p2, 1.3e-3, 0.05e-3, 'abs', 'INDEP', 'reports/review/R3_REVIEW.md 3.5', 'Quantity', 'chi2_2 tail (R3)');
            Dh = vital.uq.mahalanobis(th, ones(1, 6), 2 * sig);
            tc.verifyTol(Dh, D / 2, 1e-15, 'rel', 'ANALYTIC', c, 'Quantity', 'D with sigma doubled');
            tc.verifyError(@() vital.uq.mahalanobis(th, ones(1, 6), [sig(1:5) 0]), 'vital:badInput');
            tc.verifyError(@() vital.uq.mahalanobis(th, ones(1, 6), sig(1:5)), 'vital:badInput');
        end

        function jointCoverage(tc)
            spec = vital.uq.loadSpec();
            B = vital.uq.box(spec);
            cv = vital.uq.boxCoverage(B);
            tc.verifyTol(cv.joint, prod(erf(B.kg / sqrt(2))), 1e-14, 'abs', 'ANALYTIC', 'header 5', 'Quantity', 'joint coverage');
            tc.verifyTol(cv.joint, 0.97070, 5e-6, 'abs', 'INDEP', 'reports/review/R3_REVIEW.md 3.3', 'Quantity', 'joint coverage (R3)');
            k2 = sqrt(chi2inv(0.99, 2));
            for g = cv.groups(:).'
                if g.d == 1
                    tc.verifyTol(g.coverage, 0.99, 1e-12, 'abs', 'ANALYTIC', 'header 5', 'Quantity', [g.name ' coverage']);
                else
                    tc.verifyTol(g.coverage, erf(k2 / sqrt(2))^2, 1e-14, 'abs', 'ANALYTIC', 'header 5', 'Quantity', [g.name ' coverage']);
                    tc.verifyTol(g.coverage, 0.99519, 5e-6, 'abs', 'INDEP', 'R3 3.3', 'Quantity', [g.name ' coverage (R3)']);
                end
            end
            tc.verifyNumElements(cv.groups, 4);
            tc.verifyTrue(isequal(vital.uq.boxCoverage(vital.uq.box(spec, 'WidthScale', 1.5)), cv), ...
                'header 5: the coverage does not depend on the width scale');
        end

        function searchPlanModes(tc)
            F = {'Cm_q', 'Cm_table', 'Cl_p', 'Cnr_table', 'Cl_table', 'Cnt_table'};
            sp = @(g, m, m0, varargin) vital.uq.searchPlan(g, m, m0, F, varargin{:});
            p = sp('3.2.2.1.1-CatA', {'CAP', 'omega_nsp_rad_s'}, 0.05);
            tc.verifyEqual(p.mode, 'longitudinal');
            tc.verifyEqual(p.idx, [1 2]);
            tc.verifyEqual(p.fields, {'Cm_q', 'Cm_table'});
            tc.verifyFalse(p.sampledOnly);
            tc.verifyEqual(sp('3.2.1.2-CatA', {'T2_phugoid_s', 'zeta_p'}, 0.49).mode, 'longitudinal');
            p = sp('3.3.1.1-CatA-other', {'omega_nd_rad_s', 'zeta_d', 'zeta_d_omega_nd_rad_s'}, 1.2);
            tc.verifyEqual(p.mode, 'full');
            tc.verifyEqual(p.idx, 1:6);
            p = sp('3.3.1.3-CatA', {'spiral_T2_s'}, Inf);
            tc.verifyEqual(p.mode, 'surrogate');
            tc.verifyEqual(p.idx, 1:6);
            tc.verifySubstring(p.objective, 'spiral');
            tc.verifyEqual(sp('3.3.1.3-CatA', {'spiral_T2_s'}, 0.95).mode, 'full');
            p = sp('3.3.1.4-CatA-other', {'coupled_roll_spiral_present'}, 0);
            tc.verifyEqual(p.mode, 'full');
            tc.verifyTrue(p.sampledOnly);
            tc.verifySubstring(p.sampledReason, 'binary');
            tc.verifyEqual(sp('3.3.1.1-CatB', {'zeta_d'}, Inf).mode, 'full');
            tc.verifyEqual(sp('3.2.2.1.1-CatA', {'CAP'}, 0.05, 'LonOnly', false).mode, 'full');
            tc.verifyEqual(vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, {'Cnr_table'}).mode, 'full');
            p = vital.uq.searchPlan('3.2.2.1.1-CatA', {'CAP'}, 0.05, {'Cl_p', 'Cm_table', 'Cm_q'});
            tc.verifyEqual(p.mode, 'longitudinal');
            tc.verifyEqual(p.idx, [2 3]);
        end
    end
end
