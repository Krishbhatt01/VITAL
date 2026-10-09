function [lo, hi] = clopperPearson(x, n, conf, opts)
%CLOPPERPEARSON  Exact (Clopper-Pearson) binomial confidence bounds.
%   [lo, hi] = vital.uq.clopperPearson(x, n, conf)                   two-sided
%   [lo, hi] = vital.uq.clopperPearson(x, n, conf, 'Sided', 'lower') one-sided
%
%   x successes in n trials, confidence conf in (0, 1), alpha = 1 - conf.
%   'two'   lo = betainv(alpha/2, x, n-x+1) (0 when x = 0),
%           hi = betainv(1-alpha/2, x+1, n-x) (1 when x = n)
%   'lower' lo = betainv(alpha, x, n-x+1) (0 when x = 0), hi = 1
%   Closed forms (used by tests/M8/tClopperPearson.m): x = n gives the one-sided
%   lower bound alpha^(1/n) and the two-sided (alpha/2)^(1/n); x = 0 gives the
%   two-sided upper bound 1 - (alpha/2)^(1/n).
%   Source: C. J. Clopper and E. S. Pearson, Biometrika 26 (1934) 404-413.
%   Errors: vital:badInput (x not an integer in [0, n], n not a positive
%   integer, conf outside (0, 1), Sided not 'lower' or 'two').
arguments
    x (1,1) double
    n (1,1) double
    conf (1,1) double
    opts.Sided (1,:) char = 'two'
end
if ~(isfinite(n) && n >= 1 && n == round(n))
    error('vital:badInput', 'n must be a positive integer.');
end
if ~(isfinite(x) && x >= 0 && x <= n && x == round(x))
    error('vital:badInput', 'x must be an integer in [0, n].');
end
if ~(isfinite(conf) && conf > 0 && conf < 1)
    error('vital:badInput', 'conf must lie in (0, 1).');
end
alpha = 1 - conf;
switch opts.Sided
    case 'lower'
        a = alpha;            % one-sided: the whole alpha in the lower tail
        hi = 1;
    case 'two'
        a = alpha / 2;
        if x == n, hi = 1; else, hi = betainv(1 - a, x + 1, n - x); end
    otherwise
        error('vital:badInput', 'Sided must be ''lower'' or ''two'', not ''%s''.', opts.Sided);
end
if x == 0, lo = 0; else, lo = betainv(a, x, n - x + 1); end
end
