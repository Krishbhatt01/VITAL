classdef (TestTags = {'M8'}) tUqBracket < vital.test.VitalTestCase
%TUQBRACKET  M8 amendment R4b, item R4-7 (docs/PLAN_M5_M8.md, "Amendment R4b",
%   coordinator 2026-10-14): breakpoint bracketing of linearization failures,
%   on fakes (no aircraft; the F-16 known case is in tests/M8/tUqR4bF16.m).
%   Expected runtime: a few seconds.
%
%   Rule (contract, stated here before any implementation):
%   vital.uq.bracket(p, theta, sideFcn, 'Breakpoints', bp, 'Proximity', 0.01,
%   'Steps', [1e-3 2e-3 5e-3 1e-2]):
%   - ELIGIBLE only when the point's linearization is NOT_CONVERGED (p.status
%     'NOT_CONVERGED' AND p.stage 'linearize') and its trim alpha (p.alpha_deg)
%     or elevator (p.de_deg) lies within Proximity (0.01 deg, inclusive) of a
%     NESC aero-table breakpoint of that variable. Anything else is never
%     bracketed: status 'NOT_ELIGIBLE' and sideFcn is never called (physical
%     failures: trim INFEASIBLE / NOT_CONVERGED at stage 'trim', DIVERGENT,
%     non-classical modes, errors).
%   - For d = 1e-3, then (only if needed) 2e-3, 5e-3, 1e-2: the two sides
%     theta x (1 - d) and theta x (1 + d) (exactly these vectors) are evaluated
%     by sideFcn (one call each). Accepted ('BRACKETED') when both sides are
%     'OK' and, for EVERY breakpoint within Proximity of the point, the two
%     sides' values of that variable lie strictly on opposite sides of it.
%     A side that is a physical failure (stage 'trim', or status other than OK
%     and NOT_CONVERGED) stops the procedure: 'NOT_BRACKETED' (reason
%     containing 'physical'). Sides that are both OK but do not straddle, or a
%     side whose linearization is NOT_CONVERGED, move on to the next d.
%     After the last d: 'NOT_BRACKETED' (reason containing 'opposite sides'
%     when the last sides were OK but did not straddle).
%   - b fields: eligible, status, reason, variable ('alpha' | 'el'),
%     breakpoint, d, near (the breakpoints within Proximity), sides (1 x 2:
%     factor 1 - d / 1 + d, theta, status, stage, alpha_deg, de_deg, point),
%     tries (every d tried).
%   - The margin of a bracketed point is the WORSE of the two sides
%     (vital.uq.F16Evaluator.worseOf): per group, pointClass OK only if both
%     sides' pointClass are OK (else the first non-OK of the two), level =
%     max, marginTo = min per Level (NaN if either side is NaN), recordTo of
%     the worse side; spiralRe = max (NaN if either is NaN).
%   Breakpoints: vital.uq.breakpoints() reads the breakpoint vectors of every
%   table lookup of alpha and el from the GENERATED model
%   +vital/+models/+f16/aero.m (never retyped).
%
%   PRE-REGISTERED (agent uq4, 2026-10-14, with the stubs, before any
%   implementation):
%   1. BREAKPOINTS (PUB: NASA NESC F16_aero.dml, the Garza subsonic tables):
%      bp.alpha_deg = -10:5:45 and bp.el_deg = [-24 -12 0 12 24] (exact); bp.source
%      ends with fullfile('+f16', 'aero.m').
%   2. BRACKETED (the shape of the F-16 known case: alpha 5.000036, sides at
%      d = 1e-3 trim at 5.000692 / 4.999388): status 'BRACKETED', eligible
%      true, variable 'alpha', breakpoint 5, d 1e-3, exactly 2 side calls,
%      sides(1).factor = 1 - 1e-3, sides(2).factor = 1 + 1e-3, sides(k).theta
%      isequal theta x factor, the side alphas on opposite sides of 5.
%   3. A NON-BREAKPOINT LINEARIZATION FAILURE (alpha 5.3, de -5.9): 'NOT_ELIGIBLE',
%      0 side calls.
%   4. PHYSICAL FAILURES NEVER BRACKETED, even at alpha 5.00001: trim
%      INFEASIBLE (stage 'trim'), trim NOT_CONVERGED (stage 'trim'),
%      DIVERGENT (stage 'done'), NON_CLASSICAL (stage 'done'), ERROR (stage
%      'point'): each 'NOT_ELIGIBLE', 0 side calls (sabotage S8X-4).
%   5. SIDES THAT DO NOT STRADDLE (both above 5 at every d): 'NOT_BRACKETED',
%      8 side calls (4 steps x 2), tries = [1e-3 2e-3 5e-3 1e-2], reason
%      containing 'opposite sides'.
%   6. A SIDE NOT CONVERGED AT d = 1e-3, both OK at 2e-3: 'BRACKETED' with
%      d = 2e-3, 4 side calls.
%   7. A SIDE IS A PHYSICAL FAILURE (INFEASIBLE at stage 'trim'): 'NOT_BRACKETED',
%      2 side calls, reason containing 'physical'.
%   8. ELEVATOR BREAKPOINT (alpha 7.3, de 0.004): 'BRACKETED', variable 'el',
%      breakpoint 0.
%   9. TWO NEAR BREAKPOINTS (alpha 5.000036 and de 0.004), the sides straddle
%      alpha = 5 but not el = 0 at every d: 'NOT_BRACKETED'.
%   10. WORSE OF THE TWO SIDES (vital.uq.F16Evaluator.worseOf, ANALYTIC):
%      g1 OK/OK, levels 1/2, marginTo [0.3 0.5 0.7] / [0.2 0.6 Inf], recordTo
%      {a1 a2 a3} / {b1 b2 b3} -> OK, level 2, marginTo [0.2 0.5 0.7], recordTo
%      {b1 a2 a3}; g2 OK / NOT_APPLICABLE -> NOT_APPLICABLE; g3 marginTo
%      [0.4 NaN 1] / [0.5 0.2 1] -> [0.4 NaN 1]; spiralRe -0.01 / -0.02 ->
%      -0.01; NaN / -0.02 -> NaN (sabotage S8X-3: the better side).
%   11. FAILURE MODES: 'Proximity' 0, 'Steps' [1e-3 2e-2] (above 1e-2),
%      'Steps' [2e-3 1e-3] (not increasing) -> vital:badInput.

    methods (Static)
        function p = pt(status, stage, a, e)
            p = struct('status', status, 'stage', stage, 'alpha_deg', a, 'de_deg', e);
        end

        function s = side(th, th0, cnt, fa, fe, fst)
            % fake side point: f = th(1)/th0(1) - 1 (= -d or +d)
            k = 'calls';
            if isKey(cnt, k), cnt(k) = cnt(k) + 1; else, cnt(k) = 1; end
            f = th(1) / th0(1) - 1;
            [st, sg] = fst(f);
            s = struct('status', st, 'stage', sg, 'alpha_deg', fa(f), 'de_deg', fe(f));
        end

        function [st, sg] = ok(~), st = 'OK'; sg = 'done'; end

        function [st, sg] = nc1(f)
            if abs(f) < 1.5e-3, st = 'NOT_CONVERGED'; sg = 'linearize'; else, st = 'OK'; sg = 'done'; end
        end

        function [st, sg] = infeas(f)
            if f < 0, st = 'INFEASIBLE'; sg = 'trim'; else, st = 'OK'; sg = 'done'; end
        end

        function n = calls(cnt)
            if isKey(cnt, 'calls'), n = cnt('calls'); else, n = 0; end
        end

        function g = grp(name, pc, lev, m, r)
            g = struct('group', name, 'pointClass', pc, 'why', '', 'level', lev, 'marginTo', m, 'recordTo', {r});
        end
    end

    methods (Access = private)
        function [b, n] = runFake(tc, p, fa, fe, fst) %#ok<INUSL>
            th0 = [0.95 0.86 1.06 0.79 0.79 1.02 1.12];
            cnt = containers.Map('KeyType', 'char', 'ValueType', 'double');
            b = vital.uq.bracket(p, th0, @(th) tUqBracket.side(th, th0, cnt, fa, fe, fst));
            n = tUqBracket.calls(cnt);
        end
    end

    methods (Test)
        function breakpointsFromGeneratedModel(tc)
            bp = vital.uq.breakpoints();
            tc.verifyExact(bp.alpha_deg, -10:5:45, 'PUB', 'NASA NESC F16_aero.dml (Garza): alpha breakpoints', ...
                'Quantity', 'alpha breakpoints', 'Unit', 'deg');
            tc.verifyExact(bp.el_deg, [-24 -12 0 12 24], 'PUB', 'NASA NESC F16_aero.dml (Garza): el breakpoints', ...
                'Quantity', 'el breakpoints', 'Unit', 'deg');
            tc.verifyTrue(endsWith(bp.source, fullfile('+f16', 'aero.m')), bp.source);
        end

        function bracketedKnownShape(tc)
            th0 = [0.95 0.86 1.06 0.79 0.79 1.02 1.12];
            cnt = containers.Map('KeyType', 'char', 'ValueType', 'double');
            p = tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.000036, -5.9096);
            b = vital.uq.bracket(p, th0, @(th) tUqBracket.side(th, th0, cnt, @(f) 5.000036 - 0.65 * f, ...
                @(f) -5.9096 + 5 * f, @tUqBracket.ok));
            tc.verifyEqual(b.status, 'BRACKETED', b.reason);
            tc.verifyTrue(b.eligible);
            tc.verifyEqual({b.variable, b.breakpoint, b.d}, {'alpha', 5, 1e-3}, 'header 2');
            tc.verifyEqual(tUqBracket.calls(cnt), 2, 'header 2: two side calls');
            tc.verifyEqual([b.sides.factor], [1 - 1e-3, 1 + 1e-3], 'header 2');
            tc.verifyEqual(b.sides(1).theta, th0 * (1 - 1e-3), 'header 2');
            tc.verifyEqual(b.sides(2).theta, th0 * (1 + 1e-3), 'header 2');
            a = [b.sides.alpha_deg];
            tc.verifyLessThan(prod(a - 5), 0, 'header 2: sides straddle 5');
        end

        function nonBreakpointFailureStays(tc)
            [b, n] = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.3, -5.9), @(f) 5.3 - f, @(f) -5.9, @tUqBracket.ok);
            tc.verifyEqual(b.status, 'NOT_ELIGIBLE', b.reason);
            tc.verifyFalse(b.eligible);
            tc.verifyEqual(n, 0, 'header 3: no side evaluated');
        end

        function trimFailureNeverBracketed(tc)
            cases = {'INFEASIBLE', 'trim'; 'NOT_CONVERGED', 'trim'; 'DIVERGENT', 'done'; 'NON_CLASSICAL', 'done'; ...
                'ERROR', 'point'};
            for k = 1:size(cases, 1)
                [b, n] = tc.runFake(tUqBracket.pt(cases{k, 1}, cases{k, 2}, 5.00001, -5.9), @(f) 5.00001 - 0.65 * f, ...
                    @(f) -5.9, @tUqBracket.ok);
                tc.verifyEqual(b.status, 'NOT_ELIGIBLE', sprintf('header 4: %s/%s', cases{k, :}));
                tc.verifyEqual(n, 0, sprintf('header 4: %s/%s: no side evaluated', cases{k, :}));
            end
        end

        function sidesNotStraddling(tc)
            [b, n] = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.000036, -5.9), @(f) 5.000036 + 0.5 * abs(f), ...
                @(f) -5.9, @tUqBracket.ok);
            tc.verifyEqual(b.status, 'NOT_BRACKETED', b.reason);
            tc.verifyEqual(n, 8, 'header 5: 4 steps x 2 sides');
            tc.verifyEqual(b.tries, [1e-3 2e-3 5e-3 1e-2], 'header 5');
            tc.verifySubstring(b.reason, 'opposite sides');
        end

        function largerStepWhenNeeded(tc)
            [b, n] = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.000036, -5.9), @(f) 5.000036 - 0.65 * f, ...
                @(f) -5.9, @tUqBracket.nc1);
            tc.verifyEqual(b.status, 'BRACKETED', b.reason);
            tc.verifyEqual(b.d, 2e-3, 'header 6');
            tc.verifyEqual(n, 4, 'header 6');
        end

        function physicalSideStops(tc)
            [b, n] = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.000036, -5.9), @(f) 5.000036 - 0.65 * f, ...
                @(f) -5.9, @tUqBracket.infeas);
            tc.verifyEqual(b.status, 'NOT_BRACKETED', b.reason);
            tc.verifyEqual(n, 2, 'header 7');
            tc.verifySubstring(b.reason, 'physical');
        end

        function elevatorBreakpoint(tc)
            b = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 7.3, 0.004), @(f) 7.3 + f, @(f) 0.004 - 6 * f, ...
                @tUqBracket.ok);
            tc.verifyEqual(b.status, 'BRACKETED', b.reason);
            tc.verifyEqual({b.variable, b.breakpoint}, {'el', 0}, 'header 8');
        end

        function everyNearBreakpointStraddled(tc)
            b = tc.runFake(tUqBracket.pt('NOT_CONVERGED', 'linearize', 5.000036, 0.004), @(f) 5.000036 - 0.65 * f, ...
                @(f) 0.004 + abs(f), @tUqBracket.ok);
            tc.verifyEqual(b.status, 'NOT_BRACKETED', ['header 9: ' b.reason]);
        end

        function worseOfTwoSides(tc)
            A.status = 'OK'; B.status = 'OK';
            A.groups = [tUqBracket.grp('g1', 'OK', 1, [0.3 0.5 0.7], {'a1', 'a2', 'a3'}), ...
                tUqBracket.grp('g2', 'OK', 1, [1 1 1], {'x', 'x', 'x'}), ...
                tUqBracket.grp('g3', 'OK', 1, [0.4 NaN 1], {'c', '', 'c'})];
            B.groups = [tUqBracket.grp('g1', 'OK', 2, [0.2 0.6 Inf], {'b1', 'b2', 'b3'}), ...
                tUqBracket.grp('g2', 'NOT_APPLICABLE', NaN, [Inf Inf Inf], {'', '', ''}), ...
                tUqBracket.grp('g3', 'OK', 1, [0.5 0.2 1], {'d', 'd', 'd'})];
            A.spiralRe = -0.01; B.spiralRe = -0.02;
            S = vital.uq.F16Evaluator.worseOf(A, B);
            g = S.groups;
            tc.verifyEqual(g(1).pointClass, 'OK');
            tc.verifyEqual(g(1).level, 2, 'header 10: worse Level');
            tc.verifyEqual(g(1).marginTo, [0.2 0.5 0.7], 'header 10: smaller margin per Level');
            tc.verifyEqual(g(1).recordTo, {'b1', 'a2', 'a3'}, 'header 10: record of the worse side');
            tc.verifyEqual(g(2).pointClass, 'NOT_APPLICABLE', 'header 10');
            tc.verifyTrue(isequaln(g(3).marginTo, [0.4 NaN 1]), 'header 10: NaN wins');
            tc.verifyEqual(S.spiralRe, -0.01, 'header 10: larger spiral Re');
            A.spiralRe = NaN;
            S = vital.uq.F16Evaluator.worseOf(A, B);
            tc.verifyTrue(isnan(S.spiralRe), 'header 10: NaN spiral');
        end

        function badBracketOptions(tc)
            p = tUqBracket.pt('NOT_CONVERGED', 'linearize', 5, 0);
            f = @(th) struct('status', 'OK', 'stage', 'done', 'alpha_deg', 5, 'de_deg', 0);
            tc.verifyError(@() vital.uq.bracket(p, 1, f, 'Proximity', 0), 'vital:badInput');
            tc.verifyError(@() vital.uq.bracket(p, 1, f, 'Steps', [1e-3 2e-2]), 'vital:badInput');
            tc.verifyError(@() vital.uq.bracket(p, 1, f, 'Steps', [2e-3 1e-3]), 'vital:badInput');
        end
    end
end
