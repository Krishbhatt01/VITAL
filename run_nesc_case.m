function r = run_nesc_case(id, opts)
%RUN_NESC_CASE  Run an NESC atmospheric check-case and compare it with the NASA simulations.
%
%   run_nesc_case('1')                 dragless sphere; prints the comparison
%   run_nesc_case('13.3', 'Plot', true) F-16 heading change; also plots VITAL
%                                      against every reference simulation
%   r = run_nesc_case(...)             returns id, res (vital.nesc.runCase),
%                                      cmp (vital.nesc.compare), pass
%
%   Cases: vital.nesc.caseIds() = 1-10 (spheres, bricks), 11, 12 (F-16 trim
%   flyouts), 13.1-13.4 (F16_control autopilot), 15, 16 (F16_gnc circles).
%   The comparison is the pre-registered envelope criterion (ADR-009/015):
%   VITAL must lie in [min_s ref_s - delta, max_s ref_s + delta] with delta
%   from docs/NESC_CASE_MATRIX.json. "excess" is the worst envelope excess
%   (<= 0 passes) and "excess/delta" the same in band half-widths.
%
%   Options
%     'Plot'      true to plot every band signal (default false)
%     'Signals'   cellstr of signals to plot (default all)
%     'dt'        RK4 step (default: the case's registered dt)
%     'Quiet'     true to suppress the printout
%   Works from any MATLAB session: it puts VITAL on the path itself.
arguments
    id (1,:) char
    opts.Plot (1,1) logical = false
    opts.Signals cell = {}
    opts.dt (1,1) double = NaN
    opts.Quiet (1,1) logical = false
end
addpath(fileparts(mfilename('fullpath')));
if isnan(opts.dt)
    res = vital.nesc.runCase(id);
else
    res = vital.nesc.runCase(id, 'dt', opts.dt);
end
cmp = vital.nesc.compare(res);
r.id = id; r.res = res; r.cmp = cmp;
r.pass = all(strcmp({cmp.status}, 'PASS'));
if ~opts.Quiet
    cd = res.caseDef;
    fprintf('NESC case %s: %s\n', id, cd.title);
    fprintf('  run %s, dt %g s, %g s simulated, %.1f s wall\n', res.status, res.dt, res.t(end), res.wallTime_s);
    if ~isempty(res.trim)
        fprintf('  trim %s: theta %.5f deg, elevator %.4f deg, throttle %.4f %%, %.3f KEAS\n', res.trim.status, ...
            rad2deg(res.trim.theta), rad2deg(res.trim.de), 100 * res.trim.throttle, res.trim.keas);
    end
    fprintf('  %-34s %-15s %-8s %13s %13s %9s\n', 'signal', 'status', 'sims', 'excess', 'excess/delta', 't (s)');
    for c = cmp(:).'
        fprintf('  %-34s %-15s %-8s %+13.4g %+13.3g %9.2f %s\n', c.signal, c.status, strjoin(string(c.sims), ','), ...
            c.worst, c.normWorst, c.tWorst, c.unit);
        if ~isempty(c.reason), fprintf('      %s\n', c.reason); end
    end
    fprintf('  %d of %d signals inside their pre-registered bands\n', sum(strcmp({cmp.status}, 'PASS')), numel(cmp));
end
if opts.Plot
    ref = vital.nesc.reference(id);
    sig = opts.Signals; if isempty(sig), sig = {cmp.signal}; end
    n = numel(sig); nc = ceil(sqrt(n)); nr = ceil(n / nc);
    figure('Name', ['NESC case ' id]);
    for i = 1:n
        subplot(nr, nc, i); hold on;
        for s = ref(:).'
            if any(strcmp(s.columns, sig{i}))
                plot(s.t, s.data.(sig{i}), '--', 'DisplayName', sprintf('SIM %d', s.sim));
            end
        end
        plot(res.t, res.sig.(sig{i}), 'k', 'LineWidth', 1, 'DisplayName', 'VITAL');
        title(strrep(sig{i}, '_', '\_'), 'FontSize', 8); grid on;
        if i == 1, legend('Location', 'best', 'FontSize', 6); end
    end
end
end
