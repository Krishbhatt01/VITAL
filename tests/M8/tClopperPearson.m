classdef (TestTags = {'M8'}) tClopperPearson < vital.test.VitalTestCase
%TCLOPPERPEARSON  M8: exact binomial (Clopper-Pearson) bounds,
%   vital.uq.clopperPearson(x, n, conf, 'Sided', 'lower'|'two').
%
%   PRE-REGISTERED (with the stub; every expected value is a closed form written
%   in this test; alpha = 1 - conf):
%   1. x = n (ANALYTIC: Beta(n, 1) has CDF t^n): one-sided lower bound
%      alpha^(1/n); n = 200, conf 0.95: 0.05^(1/200) = 0.985133 (the bound the
%      M8 verdict meets with 200/200 successes); two-sided [ (alpha/2)^(1/n), 1 ].
%      Tolerance 1e-12 rel (betainv's own accuracy is ~1e-15).
%   2. x = 0: one-sided lower bound 0 (exact), two-sided [0, 1 - (alpha/2)^(1/n)]
%      (Beta(1, n) has CDF 1 - (1-t)^n).
%   3. x = 1 (ANALYTIC): two-sided lower = 1 - (1 - alpha/2)^(1/n); n = 10,
%      conf 0.95: 0.0025286 (the textbook value 0.0025).
%   4. TWO-SIDED IDENTITY (ANALYTIC): the two-sided bounds at conf are the
%      one-sided bounds at (1 + conf)/2: lo_two(x, n, c) = lo_lower(x, n, (1+c)/2)
%      and hi_two(x, n, c) = 1 - lo_lower(n - x, n, (1+c)/2) (symmetry
%      x -> n - x, p -> 1 - p), for (x, n) = (7, 50), (37, 40), (199, 200), 1e-12 abs.
%   5. Monotone: the one-sided lower bound for 200 trials is increasing in x
%      (x = 180..200) and < x/n (ANALYTIC: a lower confidence bound is below the
%      point estimate for 0 < x).
%   6. The M8 decision threshold (used by vital.uq.verdict): with n = 200,
%      x = 196 gives a one-sided 95 % lower bound >= 0.95 (0.95482) and x = 195
%      gives < 0.95 (0.94816), i.e. ROBUST tolerates at most 4 failures in 200
%      (values computed with scipy.stats.beta.ppf while writing this header).
%      The bounds are checked against a direct bisection on the binomial tail
%      in the test, P(X >= x | p) = alpha at p = lower bound (INDEP of betainv).
%   7. FAILURE MODES: x > n, x < 0, x not an integer, n = 0, conf = 1, conf = 0,
%      Sided 'upper' -> vital:badInput.

    methods (Test)
        function allSuccesses(tc)
            n = 200; c = 0.95; a = 1 - c;
            [lo, hi] = vital.uq.clopperPearson(n, n, c, 'Sided', 'lower');
            tc.verifyTol(lo, a^(1/n), 1e-12, 'rel', 'ANALYTIC', 'Beta(n,1) CDF t^n: lower = alpha^(1/n)', 'Quantity', 'lower x=n');
            tc.verifyTol(lo, 0.985133, 1e-6, 'abs', 'ANALYTIC', '0.05^(1/200)', 'Quantity', 'lower 200/200');
            tc.verifyEqual(hi, 1);
            [lo, hi] = vital.uq.clopperPearson(n, n, c, 'Sided', 'two');
            tc.verifyTol(lo, (a/2)^(1/n), 1e-12, 'rel', 'ANALYTIC', 'two-sided: (alpha/2)^(1/n)', 'Quantity', 'two-sided lower x=n');
            tc.verifyEqual(hi, 1);
            [lo2, hi2] = vital.uq.clopperPearson(n, n, c);
            tc.verifyEqual([lo2 hi2], [lo hi], 'default Sided is two');
        end

        function noSuccesses(tc)
            n = 50; c = 0.9; a = 1 - c;
            lo = vital.uq.clopperPearson(0, n, c, 'Sided', 'lower');
            tc.verifyEqual(lo, 0);
            [lo, hi] = vital.uq.clopperPearson(0, n, c, 'Sided', 'two');
            tc.verifyEqual(lo, 0);
            tc.verifyTol(hi, 1 - (a/2)^(1/n), 1e-12, 'rel', 'ANALYTIC', 'Beta(1,n): 1 - (alpha/2)^(1/n)', 'Quantity', 'upper x=0');
        end

        function oneSuccess(tc)
            n = 10; c = 0.95; a = 1 - c;
            lo = vital.uq.clopperPearson(1, n, c, 'Sided', 'two');
            tc.verifyTol(lo, 1 - (1 - a/2)^(1/n), 1e-12, 'rel', 'ANALYTIC', 'Beta(1,n) inverse', 'Quantity', 'lower 1/10');
            tc.verifyTol(lo, 0.0025, 5e-5, 'abs', 'ANALYTIC', 'textbook 1/10 two-sided 95 %', 'Quantity', 'lower 1/10 (4 digits)');
        end

        function twoSidedIdentity(tc)
            c = 0.95; c1 = (1 + c) / 2;
            for xn = [7 50; 37 40; 199 200].'
                x = xn(1); n = xn(2);
                [lo, hi] = vital.uq.clopperPearson(x, n, c, 'Sided', 'two');
                l1 = vital.uq.clopperPearson(x, n, c1, 'Sided', 'lower');
                l2 = vital.uq.clopperPearson(n - x, n, c1, 'Sided', 'lower');
                q = sprintf('%d/%d', x, n);
                tc.verifyTol(lo, l1, 1e-12, 'abs', 'ANALYTIC', 'two-sided lower = one-sided lower at (1+c)/2', 'Quantity', ['lo ' q]);
                tc.verifyTol(hi, 1 - l2, 1e-12, 'abs', 'ANALYTIC', 'two-sided upper by symmetry', 'Quantity', ['hi ' q]);
            end
        end

        function monotoneAndBelowEstimate(tc)
            n = 200;
            lo = arrayfun(@(x) vital.uq.clopperPearson(x, n, 0.95, 'Sided', 'lower'), 180:200);
            tc.verifyTrue(all(diff(lo) > 0), 'lower bound increasing in x');
            tc.verifyTrue(all(lo < (180:200) / n), 'lower bound below x/n');
        end

        function decisionThreshold(tc)
            n = 200; a = 0.05;
            % independent: bisection on the binomial upper tail P(X >= x | p) = alpha
            tail = @(x, p) 1 - binocdf(x - 1, n, p);
            pl = @(x) fzero(@(p) tail(x, p) - a, [1e-6, 1 - 1e-12]);
            for x = [195 196]
                lo = vital.uq.clopperPearson(x, n, 0.95, 'Sided', 'lower');
                tc.verifyTol(lo, pl(x), 1e-9, 'abs', 'INDEP', 'binomial tail bisection (binocdf + fzero)', ...
                    'Quantity', sprintf('lower %d/200', x));
            end
            tc.verifyGreaterThanOrEqual(vital.uq.clopperPearson(196, n, 0.95, 'Sided', 'lower'), 0.95);
            tc.verifyLessThan(vital.uq.clopperPearson(195, n, 0.95, 'Sided', 'lower'), 0.95);
        end

        function badInputs(tc)
            f = @(varargin) vital.uq.clopperPearson(varargin{:});
            tc.verifyError(@() f(11, 10, 0.95), 'vital:badInput');
            tc.verifyError(@() f(-1, 10, 0.95), 'vital:badInput');
            tc.verifyError(@() f(2.5, 10, 0.95), 'vital:badInput');
            tc.verifyError(@() f(0, 0, 0.95), 'vital:badInput');
            tc.verifyError(@() f(3, 10, 1), 'vital:badInput');
            tc.verifyError(@() f(3, 10, 0), 'vital:badInput');
            tc.verifyError(@() f(3, 10, 0.95, 'Sided', 'upper'), 'vital:badInput');
        end
    end
end
