function d = fit_nz_loop()
%FIT_NZ_LOOP  Numbers for nz_loop_mda.py: VITAL's controller-plant nz loop
%   (ADR-026) at VITAL's F-16 trim point, and VITAL's own answers to it.
%
%   Run in MATLAB from the SciComp folder:   fit_nz_loop
%   Writes nz_loop_data.json next to this file.
%
%   THE LOOP (same fixture as VITAL's test tests/M5/tClosedLoopR1.m):
%       controller:  de = de_ref + Knz (nz - nz0)          Knz = 0.05 rad/g
%       plant:       nz = -(body z force) / (m g)  at the frozen trim state,
%                    and the body z force depends on the elevator de.
%   The controller needs nz, nz needs de: an algebraic loop at one instant.
%
%   What it does, in plain steps:
%     1. Trims the F-16 in VITAL at 565.6854 ft/s, 10,013 ft, CG 25 % MAC.
%     2. Reads NASA's body-axis normal-force coefficient CZ at the trim state
%        and its elevator slope CZde (+/- 1e-6 rad; the NASA table is linear
%        in the elevator), and the plant's nz0 and d nz/d de.
%     3. VITAL's own answers:
%          a. vital.linear.linearize with the nz controller -> Kref(de,de),
%             VITAL's closed-loop gain du/du_ref = 1 / (1 - Knz dnz/dde);
%          b. the applied elevator for a +1 deg command step, solved with
%             fzero on VITAL's full plant (no straight-line approximation).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));                          % C:\VITAL on the path
Ft = 0.3048; g = 32.174 * Ft;
Knz = 0.05;                                        % rad/g, as tClosedLoopR1
step_deg = 1.0;                                    % pilot command step for 3b

% 1. VITAL trim (same call as tClosedLoopR1)
AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
env = struct('g', g, 'wind_n', [0; 0; 0], 'deltaT', 0);
cond = struct('type', 'level', 'V', 565.6854 * Ft, 'h', 10013 * Ft, 'gamma', 0, 'psi', 0);
tr = vital.trim.solve(AC, env, cond);
assert(strcmp(tr.status, 'OK'), 'VITAL trim failed: %s', tr.status);
x0 = tr.x; u0 = tr.u; de0 = u0(1);

% 2. plant numbers at the frozen trim state
    function [n, cz, fpz] = plant(de)
        u = u0; u(1) = de;
        [~, y] = vital.plant.derivatives(x0, u, AC, env);
        n = y.nz; cz = y.coeff(3);
        fpz = 0; if isfield(y, 'F_prop'), fpz = y.F_prop(3); end
    end
[nz0, cz0, fpz0] = plant(de0);
h = 1e-6;
[n1, c1] = plant(de0 + h); [n2, c2] = plant(de0 - h);
gde = (n1 - n2) / (2 * h);                         % g per rad
CZde = (c1 - c2) / (2 * h);                        % per rad
[~, y0] = vital.plant.derivatives(x0, u0, AC, env);
qSW = y0.qbar * AC.S / (AC.mass * g);              % qbar S / W (dimensionless)

% 3a. VITAL's closed-loop linearization (its own Newton solve of the loop)
c = struct('rate_hz', 100, 'init', 0, 'static', true, ...
    'step', @(t, x, y, uref, s) deal(uref + [Knz * (y.nz - nz0); 0; 0; 0], s));
lin = vital.linear.linearize(AC, env, tr, 'Controller', c);
assert(strcmp(lin.status, 'OK'), 'VITAL closed-loop linearization: %s', lin.reason);

% 3b. the +1 deg command step through VITAL's full plant
de_ref = de0 + deg2rad(step_deg);
de_app = fzero(@(de) de - (de_ref + Knz * (plant(de) - nz0)), de_ref, optimset('TolX', 1e-15));

d = struct();
d.source = 'VITAL F-16 (NASA NESC tables) at VITAL''s trim point; loop as tests/M5/tClosedLoopR1.m (ADR-026)';
d.condition = struct('V_ftps', 565.6854, 'h_ft', 10013, 'cg_pct_mac', 25, 'g_ftps2', 32.174);
d.trim = struct('alpha_deg', rad2deg(atan2(x0(3), x0(1))), ...
    'de0_deg', rad2deg(de0), 'nz0_g', nz0, 'CZ0', cz0, 'F_prop_z_N', fpz0);
d.plant = struct('CZde_per_rad', CZde, 'qbarS_over_W', qSW, 'dnz_dde_g_per_rad', gde);
d.controller = struct('Knz_rad_per_g', Knz);
d.vital = struct('Kref_de_de', lin.Kref(1, 1), 'loop_gain', Knz * gde, ...
    'step_deg', step_deg, 'de_ref_deg', rad2deg(de_ref), 'de_applied_deg', rad2deg(de_app), ...
    'nz_applied_g', plant(de_app));
fid = fopen(fullfile(here, 'nz_loop_data.json'), 'w');
fprintf(fid, '%s', jsonencode(d, 'PrettyPrint', true)); fclose(fid);
fprintf('nz loop data written to %s\n', fullfile(here, 'nz_loop_data.json'));
disp(d.trim); disp(d.plant); disp(d.vital);
end
