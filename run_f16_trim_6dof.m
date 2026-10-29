function res = run_f16_trim_6dof(opts)
%RUN_F16_TRIM_6DOF  Fly the trimmed NASA F-16 for 10 s in the Simulink model
%   models/F16Trim6DOF.slx (Aerospace Blockset 6DOF (Quaternion)) and plot ITS result.
%
%   res = run_f16_trim_6dof()                    NESC case 11 / README trim point:
%                                                10013 ft, 565.6854 ft/s, heading 45 deg
%   res = run_f16_trim_6dof('Mach', 0.6, 'h_ft', 20000)
%   res = run_f16_trim_6dof(..., 'tFinal', 10, 'CG_PCT_MAC', 25, 'Rebuild', true)
%
%   This does the same as opening models/F16Trim6DOF.slx and pressing Run. The
%   script only chooses the flight condition and saves the figures:
%   1. vital.slx.trim6dofSetup builds the F-16 from the NASA data objects
%      (vital.aircraft.f16.data -> vital.AircraftModel.fromData) and trims it ONCE
%      for level flight (solving alpha = theta, elevator and throttle).
%   2. sim of models/F16Trim6DOF.slx: u-bar held -> loads -> 6DOF -> state -> ...
%   3. vital.slx.plotTrim6dof on the model's own logged signals (To Workspace
%      'sim6dof'). Figure 1 states, Figure 2 change from trim (log scale),
%      Figure 3 net load at the CG. Saved as PNG in reports/simulink/trim6dof.
%   No VITAL simulation is run or compared here; that cross-check lives in
%   tests/M9/tF16Trim6dof.m, T6.
arguments
    opts.h_ft (1,1) double = 10013
    opts.V_ftps (1,1) double = 565.6854
    opts.Mach (1,1) double = NaN
    opts.psi_deg (1,1) double = 45
    opts.CG_PCT_MAC (1,1) double = 25
    opts.tFinal (1,1) double = 10
    opts.dt (1,1) double = 0.01
    opts.Rebuild (1,1) logical = false
end
ft = 0.3048;
P = vital.slx.trim6dofSetup('h_ft', opts.h_ft, 'V_ftps', opts.V_ftps, 'Mach', opts.Mach, ...
    'psi_deg', opts.psi_deg, 'CG_PCT_MAC', opts.CG_PCT_MAC, 'dt', opts.dt, 'tFinal', opts.tFinal);
if opts.Rebuild || ~isfile(P.model)
    fprintf('building %s\n', P.model);
    vital.slx.buildTrim6dof();
end
tr = P.tr;
fprintf('\nTRIM, computed once before the run (x-bar, u-bar), from the NASA data objects\n');
fprintf('  h %.1f ft, V %.4f ft/s, Mach %.4f, heading %.1f deg, CG %g %% MAC, mass %.1f kg\n', ...
    P.h / ft, P.V / ft, P.Mach, opts.psi_deg, opts.CG_PCT_MAC, P.m);
fprintf('  alpha = theta %.4f deg   elevator %.4f deg   throttle %.4f %%   (NESC README: 2.6538, -3.2410, 13.9019)\n', ...
    rad2deg(tr.alpha), rad2deg(tr.u(1)), 100 * tr.u(4));
fprintf('  aileron %.3g deg, rudder %.3g deg\n', rad2deg(tr.u(2)), rad2deg(tr.u(3)));

out = vital.slx.simulateTrim6dof(P, 'tFinal', opts.tFinal, 'dt', opts.dt);
s = out.sl;
fprintf('\nSIMULINK RESULT (F16Trim6DOF, ode4, dt %g s): %s, %d steps in %.1f s\n', ...
    opts.dt, out.status, numel(s.t) - 1, out.wallTime_s);
fprintf('  largest change over %g s:\n', opts.tFinal);
fprintf('    V %.2e ft/s | alpha %.2e deg | theta %.2e deg | h %.2e ft | dh/dt %.2e ft/s\n', ...
    max(abs(s.V - P.V)) / ft, rad2deg(max(abs(s.alpha - tr.alpha))), rad2deg(max(abs(s.theta - tr.theta))), ...
    max(abs(s.h - P.h)) / ft, max(abs(s.hdot)) / ft);
fprintf('    p, q, r %.2e deg/s | beta, phi %.2e deg | heading %.2e deg\n', ...
    rad2deg(max(abs([s.p s.q s.r]))), rad2deg(max(abs([s.beta s.phi]))), rad2deg(max(abs(s.psi - P.eul0(3)))));
W = P.m * P.g;
fprintf('  net force / weight %.2e, net moment / (weight cbar) %.2e (largest over the run)\n', ...
    max(vecnorm(s.F)) / W, max(vecnorm(s.M)) / (W * P.cbar));
fprintf('  position after %g s: %.1f ft north, %.1f ft east (V t / sqrt 2 = %.1f ft)\n', ...
    opts.tFinal, s.xN(end) / ft, s.xE(end) / ft, P.V * opts.tFinal / sqrt(2) / ft);
[~, files] = vital.slx.plotTrim6dof(out.log, P);
fprintf('\nfigures (drawn from the Simulink log):\n'); fprintf('  %s\n', files{:});
res = struct('P', P, 'out', out, 'files', {files});
end
