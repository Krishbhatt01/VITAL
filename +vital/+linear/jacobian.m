function [J, info] = jacobian(f, z0, h0, opts)
%JACOBIAN  Central-difference Jacobian with a step study per column (FC-506).
%   [J, info] = vital.linear.jacobian(f, z0, h0)
%   [J, info] = vital.linear.jacobian(f, z0, h0, 'Name', value, ...)
%
%   f    function handle, y = f(z), y a real column vector (m)
%   z0   point (n x 1)                    h0  first step per column (n x 1 or scalar, > 0)
%
%   Step study (tests/M5/tLinearJacobian.m header, pre-registered):
%     h_k = h0 / Factor^(k-1), k = 1..Steps; D_k = (f(z+h_k e) - f(z-h_k e)) / (2 h_k)
%     weighted by W = diag(1./FScale) on rows and ZScale on the column;
%     agreement a_k = ||W (D_k - D_(k-1))||_inf; a PLATEAU is two consecutive
%     agreements a_k, a_(k+1) <= RelTol * ||W D||_inf + AbsTol; the accepted
%     estimate is the middle one, D_k.
%     KINK: one-sided asymmetry s_k = ||W (f(z+h) - 2 f(z) + f(z-h)) / h||_inf;
%     smooth f gives s_k / s_(k-1) = 1/Factor; at a breakpoint of a piecewise-
%     linear table s_k tends to the slope jump. At the accepted step, a kink is
%     s_k > KinkTol * ||W D||_inf + AbsTol and s_k >= 0.5 s_(k-1). The central
%     difference plateaus at the AVERAGE of the one-sided slopes there, so the
%     plateau alone cannot detect a breakpoint.
%     ROUND-OFF (review R1 B3): at the accepted step the derivative error caused by
%     rounding the function VALUES, eps * max|W f(z +/- h)| * ZScale / h, must be
%     <= 0.01 RelTol ||W D||_inf + AbsTol. Otherwise the plateau may be a
%     quantization artefact: f = 1e10 + sin z gives three estimates exactly 100,
%     10 and 1 ulp apart, which "agree" at a wrong value. Such a column is
%     NOT_CONVERGED ("round-off limited").
%     ACCURACY is column-relative (inf-norm; R1 MINOR 10): an entry is accurate
%     to about RelTol of the largest weighted entry of its column, and a kink
%     whose jump is below KinkTol of that maximum is averaged. Small entries
%     next to large ones are therefore accurate only in this absolute sense.
%
%   Options  'Steps' (7), 'Factor' (10), 'RelTol' (1e-6), 'AbsTol' (1e-10),
%            'KinkTol' (1e-6), 'FScale' (m x 1 or scalar, 1), 'ZScale' (n x 1 or
%            scalar, 1), 'Names' (column names for messages)
%
%   J     m x n; a column that failed the study is NaN (never a plausible number)
%   info  status   'OK' | 'NOT_CONVERGED' (FC-506)
%         reason   names each failed column and the cause (no plateau / kink /
%                  non-finite value)
%         columns  indices of the failed columns
%         stepStudy(j): name, steps, estimates (m x K), agreement, asymmetry
%                  (1 x K), accepted (index into steps, or NaN), step, status
%                  ('OK' | 'NO_PLATEAU' | 'KINK' | 'ROUNDOFF' | 'NON_FINITE'),
%                  left, right, roundoff (the round-off bound at the accepted step)
%                  (one-sided estimates at the accepted or the last step)
%   Errors: vital:badInput for non-finite z0/h0, h0 <= 0, size mismatch, a
%   non-finite or non-vector f(z0), or bad options.
arguments
    f (1,1) function_handle
    z0 double
    h0 double
    opts.Steps (1,1) double = 7
    opts.Factor (1,1) double = 10
    opts.RelTol (1,1) double = 1e-6
    opts.AbsTol (1,1) double = 1e-10
    opts.KinkTol (1,1) double = 1e-6
    opts.FScale double = 1
    opts.ZScale double = 1
    opts.Names cell = {}
end
vital.validate.finite(z0, 'z0');
vital.validate.finite(h0, 'h0');
vital.validate.finite([opts.Steps opts.Factor opts.RelTol opts.AbsTol opts.KinkTol], 'step-study options');
z0 = z0(:); n = numel(z0);
h0 = expand(h0, n, 'h0');
if any(h0 <= 0), error('vital:badInput', 'every initial step h0 must be > 0.'); end
if opts.Steps < 3 || opts.Steps ~= round(opts.Steps)
    error('vital:badInput', 'Steps must be an integer >= 3 (a plateau needs three estimates).');
end
if opts.Factor <= 1, error('vital:badInput', 'Factor must be > 1.'); end
f0 = f(z0);
if ~(isnumeric(f0) && isreal(f0) && isvector(f0)) || any(~isfinite(f0))
    error('vital:badInput', 'f(z0) must be a finite real vector.');
end
f0 = f0(:); m = numel(f0);
fs = expand(opts.FScale, m, 'FScale'); zs = expand(opts.ZScale, n, 'ZScale');
vital.validate.finite(fs, 'FScale'); vital.validate.finite(zs, 'ZScale');
if any(fs <= 0) || any(zs <= 0), error('vital:badInput', 'FScale and ZScale must be > 0.'); end
names = opts.Names;
if isempty(names), names = arrayfun(@(j) sprintf('z%d', j), 1:n, 'UniformOutput', false); end
if numel(names) ~= n, error('vital:badInput', 'Names must have one entry per column (%d).', n); end
W = 1 ./ fs;
K = opts.Steps;

J = NaN(m, n);
tmpl = struct('name', '', 'steps', [], 'estimates', [], 'agreement', [], 'asymmetry', [], ...
    'accepted', NaN, 'step', NaN, 'status', '', 'left', [], 'right', [], 'roundoff', NaN);
study = repmat(tmpl, 1, n);
failed = []; why = {};
for j = 1:n
    e = zeros(n, 1); e(j) = 1;
    steps = h0(j) ./ opts.Factor .^ (0:K-1);
    D = NaN(m, K); Dp = NaN(m, K); Dm = NaN(m, K);
    agree = NaN(1, K); asym = NaN(1, K); fmag = NaN(1, K);
    st = 'NO_PLATEAU'; acc = NaN;
    for k = 1:K
        h = steps(k);
        fp = f(z0 + h * e); fm = f(z0 - h * e);
        fp = fp(:); fm = fm(:);
        if numel(fp) ~= m || numel(fm) ~= m || any(~isfinite(fp)) || any(~isfinite(fm))
            st = 'NON_FINITE'; break
        end
        D(:, k) = (fp - fm) / (2 * h);
        Dp(:, k) = (fp - f0) / h;
        Dm(:, k) = (f0 - fm) / h;
        fmag(k) = max(max(abs(W .* fp)), max(abs(W .* fm)));
        asym(k) = max(abs(W .* (Dp(:, k) - Dm(:, k)))) * zs(j);
        if k >= 2
            agree(k) = max(abs(W .* (D(:, k) - D(:, k-1)))) * zs(j);
        end
        if k >= 3 && agree(k-1) <= tolAt(k-1) && agree(k) <= tolAt(k)
            acc = k - 1; st = 'OK'; break
        end
    end
    s = tmpl;
    s.name = names{j}; s.steps = steps; s.estimates = D; s.agreement = agree; s.asymmetry = asym;
    if strcmp(st, 'OK')
        scale = max(abs(W .* D(:, acc))) * zs(j);
        s.roundoff = eps * fmag(acc) * zs(j) / steps(acc);
        if s.roundoff > 0.01 * opts.RelTol * scale + opts.AbsTol
            st = 'ROUNDOFF';
        elseif asym(acc) > opts.KinkTol * scale + opts.AbsTol && asym(acc) >= 0.5 * asym(acc-1)
            st = 'KINK';
        end
        s.left = Dm(:, acc); s.right = Dp(:, acc);
    else
        kl = find(~isnan(D(1, :)), 1, 'last');
        if ~isempty(kl), s.left = Dm(:, kl); s.right = Dp(:, kl); end
    end
    s.status = st; s.accepted = acc;
    if ~isnan(acc), s.step = steps(acc); end
    study(j) = s;
    switch st
        case 'OK'
            J(:, j) = D(:, acc);
        case 'KINK'
            failed(end+1) = j; %#ok<AGROW>
            why{end+1} = sprintf(['column %d (%s): one-sided derivatives differ (weighted jump %.3g, ' ...
                'not shrinking with the step) - a kink/breakpoint at the linearization point; ' ...
                'a central difference would only average the left and right slopes'], j, names{j}, asym(acc)); %#ok<AGROW>
        case 'ROUNDOFF'
            failed(end+1) = j; %#ok<AGROW>
            why{end+1} = sprintf(['column %d (%s): round-off limited - the rounding error of the function ' ...
                'values (%.3g) exceeds 1 %% of the plateau tolerance at step %.3g; the plateau may be a ' ...
                'quantization artefact'], j, names{j}, s.roundoff, steps(acc)); %#ok<AGROW>
        case 'NO_PLATEAU'
            failed(end+1) = j; %#ok<AGROW>
            why{end+1} = sprintf(['column %d (%s): no step plateau - successive central-difference ' ...
                'estimates never agreed within RelTol %.3g over steps %.3g..%.3g (noise or non-smooth function)'], ...
                j, names{j}, opts.RelTol, steps(1), steps(end)); %#ok<AGROW>
        case 'NON_FINITE'
            failed(end+1) = j; %#ok<AGROW>
            why{end+1} = sprintf('column %d (%s): f is not finite at a perturbed point', j, names{j}); %#ok<AGROW>
    end
end
info.stepStudy = study;
info.columns = failed;
if isempty(failed)
    info.status = 'OK'; info.reason = '';
else
    info.status = 'NOT_CONVERGED';
    info.reason = strjoin(why, '; ');
end

    function t = tolAt(k)
        t = opts.RelTol * max(max(abs(W .* D(:, k))), max(abs(W .* D(:, k-1)))) * zs(j) + opts.AbsTol;
    end
end

function v = expand(v, n, name)
v = v(:);
if isscalar(v), v = repmat(v, n, 1); end
if numel(v) ~= n
    error('vital:badInput', '%s must be a scalar or have %d elements, got %d.', name, n, numel(v));
end
end
