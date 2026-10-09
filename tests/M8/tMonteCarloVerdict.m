classdef (TestTags = {'M8'}) tMonteCarloVerdict < vital.test.VitalTestCase
%TMONTECARLOVERDICT  M8: vital.uq.monteCarlo (seeded, serial, success = Level at
%   least as good as the nominal headline Level) and vital.uq.verdict, on toy
%   point functions (no aircraft).
%
%   PRE-REGISTERED (with the stubs, before any implementation):
%   1. SAMPLES (INDEP replicate of the seeded stream): with defaults N = 200 and
%      Seed 2026, theta = nominal + sigma .* z where z = randn(N, d) drawn right
%      after rng(2026, 'twister') (the plan's seeding), exactly (isequal).
%      monteCarlo leaves the global random state unchanged.
%   2. SUCCESS COUNT (toy: d = 2, sigma = [0.1 0.2], level0 = 1, Level 1 if
%      theta1 <= 1.1 else 2, margin 1.1 - theta1): success == (z1 <= 1) per
%      sample (ANALYTIC on the replicated z), x = sum; x/N within [0.74, 0.94]
%      (REG: Phi(1) = 0.841, binomial standard error 0.026 at N = 200, about
%      +/- 4 sigma); cpLower = vital.uq.clopperPearson(x, N, 0.95, 'Sided',
%      'lower') exactly; inBox == all(|theta - 1| <= h) for the given box.
%   3. NON-OK SAMPLES ARE FAILURES: the same toy with status 'ERROR' where
%      theta2 > 1.3 (z2 > 1.5), and a point function that THROWS
%      (vital:toy:boom) where theta2 < 0.7 (z2 < -1.5): success ==
%      (z1 <= 1 & |z2| <= 1.5); every non-OK sample is listed in mc.failures
%      with its status and reason (the thrown identifier appears in the reason).
%   4. A Level better than nominal is a success (Level 1 with level0 = 2 at every
%      sample: x = N); a Level worse is a failure (Level 3 with level0 = 2:
%      x = 0, cpLower = 0).
%   5. VERDICT TRUTH TABLE (Reserve 0, Required 0.95):
%        bw OK, value 0.1, cpLower 0.96           -> ROBUST
%        bw OK, value 0,   cpLower 0.95           -> ROBUST (both bounds inclusive)
%        bw OK, value 0.1, cpLower 0.94           -> NOT_ROBUST
%        bw VIOLATED, value -0.1, cpLower 0.99    -> NOT_ROBUST
%        bw NOT_ASSESSABLE, value 0.2, cpLower 0.99 -> NOT_ASSESSABLE
%        bw NOT_ASSESSABLE, value 0.2, cpLower 0.90 -> NOT_ROBUST
%        bw OK, value 0.05, cpLower 0.99, Reserve 0.1 -> NOT_ROBUST (value below
%        the reserve is a violation)
%   6. FAILURE MODES: monteCarlo with N = 0 or a negative sigma -> vital:badInput;
%      verdict with a bw lacking 'status' -> vital:badInput.

    methods (Static)
        function P = toy(fcn, level0)
            if nargin < 2, level0 = 1; end
            P = struct('names', {{'a', 'b'}}, 'nominal', [1 1], 'sigma', [0.1 0.2], ...
                'lo', [0.75 0.5], 'hi', [1.25 1.5], 'cond', 1, 'condLabel', 'c1', 'level0', level0, 'pointFcn', fcn);
        end

        function q = step(th)
            q = struct('status', 'OK', 'level', 1 + (th(1) > 1.1), 'margin', 1.1 - th(1), 'record', 'R', 'reason', '');
        end

        function q = holes(th)
            if th(2) < 0.7, error('vital:toy:boom', 'toy point function failure'); end
            q = tMonteCarloVerdict.step(th);
            if th(2) > 1.3
                q.status = 'ERROR'; q.reason = 'toy: not OK'; q.level = NaN; q.margin = NaN;
            end
        end

        function q = fixed(L)
            q = struct('status', 'OK', 'level', L, 'margin', 0.5, 'record', 'R', 'reason', '');
        end

        function z = replica(N, d)
            prev = rng;
            rng(2026, 'twister');
            z = randn(N, d);
            rng(prev);
        end
    end

    methods (Test)
        function seededSamples(tc)
            prev = rng; rng(11, 'twister'); before = rng;
            mc = vital.uq.monteCarlo(tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.step(th)));
            after = rng; rng(prev);
            tc.verifyEqual(after, before, 'global random state unchanged');
            tc.verifyEqual(mc.N, 200);
            tc.verifyEqual(mc.seed, 2026);
            z = tMonteCarloVerdict.replica(200, 2);
            tc.verifyExact(mc.theta, [1 1] + [0.1 0.2] .* z, 'INDEP', 'header 1: rng(2026, ''twister''), randn(N, d)', ...
                'Quantity', 'samples');
        end

        function successCount(tc)
            mc = vital.uq.monteCarlo(tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.step(th)));
            z = tMonteCarloVerdict.replica(200, 2);
            th = [1 1] + [0.1 0.2] .* z;
            tc.verifyEqual(mc.success(:), th(:, 1) <= 1.1, 'success = Level <= level0');
            tc.verifyEqual(mc.x, sum(th(:, 1) <= 1.1));
            tc.verifyWithin(mc.x / mc.N, 0.74, 0.94, 'REG', 'header 2: Phi(1) +/- 4 standard errors', 'Quantity', 'success fraction');
            tc.verifyEqual(mc.cpLower, vital.uq.clopperPearson(mc.x, 200, 0.95, 'Sided', 'lower'));
            tc.verifyEqual(mc.inBox(:), all(abs(th - 1) <= [0.25 0.5], 2));
            tc.verifyEqual(mc.margin(:), 1.1 - th(:, 1));
        end

        function nonOKIsFailure(tc)
            mc = vital.uq.monteCarlo(tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.holes(th)));
            z = tMonteCarloVerdict.replica(200, 2);
            th = [1 1] + [0.1 0.2] .* z;
            bad = th(:, 2) > 1.3 | th(:, 2) < 0.7;
            tc.assertTrue(any(th(:, 2) > 1.3) && any(th(:, 2) < 0.7), 'the toy has both kinds of non-OK samples');
            tc.verifyEqual(mc.success(:), th(:, 1) <= 1.1 & ~bad);
            tc.verifyEqual(sort([mc.failures.index]), find(bad).', 'every non-OK sample listed');
            F = mc.failures;
            boom = th([F.index], 2) < 0.7;
            tc.verifyTrue(all(contains({F(boom).reason}, 'vital:toy:boom')), 'thrown identifier recorded');
            tc.verifyTrue(all(strcmp({F(~boom).status}, 'ERROR')), 'status recorded');
        end

        function betterLevelIsSuccess(tc)
            mc = vital.uq.monteCarlo(tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.fixed(1), 2), 'N', 20);
            tc.verifyEqual(mc.x, 20);
            mc = vital.uq.monteCarlo(tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.fixed(3), 2), 'N', 20);
            tc.verifyEqual(mc.x, 0);
            tc.verifyEqual(mc.cpLower, 0);
        end

        function verdictTruthTable(tc)
            b = @(s, v) struct('status', s, 'value', v);
            m = @(p) struct('cpLower', p);
            V = @(varargin) vital.uq.verdict(varargin{:});
            tc.verifyEqual(V(b('OK', 0.1), m(0.96)).verdict, 'ROBUST');
            tc.verifyEqual(V(b('OK', 0), m(0.95)).verdict, 'ROBUST');
            tc.verifyEqual(V(b('OK', 0.1), m(0.94)).verdict, 'NOT_ROBUST');
            tc.verifyEqual(V(b('VIOLATED', -0.1), m(0.99)).verdict, 'NOT_ROBUST');
            tc.verifyEqual(V(b('NOT_ASSESSABLE', 0.2), m(0.99)).verdict, 'NOT_ASSESSABLE');
            tc.verifyEqual(V(b('NOT_ASSESSABLE', 0.2), m(0.90)).verdict, 'NOT_ROBUST');
            tc.verifyEqual(V(b('OK', 0.05), m(0.99), 'Reserve', 0.1).verdict, 'NOT_ROBUST');
            v = V(b('OK', 0.1), m(0.94));
            tc.verifyNotEmpty(v.reason);
        end

        function badInputs(tc)
            P = tMonteCarloVerdict.toy(@(th, c) tMonteCarloVerdict.step(th));
            tc.verifyError(@() vital.uq.monteCarlo(P, 'N', 0), 'vital:badInput');
            Q = P; Q.sigma = [0.1 -0.2];
            tc.verifyError(@() vital.uq.monteCarlo(Q), 'vital:badInput');
            tc.verifyError(@() vital.uq.verdict(struct('value', 1), struct('cpLower', 1)), 'vital:badInput');
        end
    end
end
