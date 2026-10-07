function c = fit_f16_coefficients()
%FIT_F16_COEFFICIENTS  Derive the 8 aerodynamic coefficients that trim_mda.py
%   uses, from NASA's F-16 tables (through VITAL), at VITAL's trim point.
%
%   Run in MATLAB from the SciComp folder:   fit_f16_coefficients
%   Writes f16_coefficients.json next to this file.
%
%   What it does, in plain steps:
%     1. Trims the F-16 in VITAL at 565.6854 ft/s, 10,013 ft, CG 25 % MAC.
%     2. Reads NASA's aerodynamic coefficients (CX, CZ, Cm) at that point.
%     3. Converts them to what trim_mda.py needs:
%          - body axes -> lift and drag:  CL = -CZ cos(a) + CX sin(a)
%                                         CD = -CX cos(a) - CZ sin(a)
%          - moment about the 35 % MAC reference point -> about the CG:
%                                         Cm_cg = Cm_ref + (DXCG / cbar) CZ
%     4. Takes slopes with small central differences (+/- 0.01 deg) in
%        alpha and elevator. NASA's tables are linear inside each table
%        cell, so these are the true local slopes.
%     5. Sets CL0, Cm0 so the values at the trim point match exactly, and
%        fits the drag polar CD = CD0 + K CL^2 so drag and its alpha-slope
%        match at the trim point.
%   The coefficients are exact AT the trim point; away from it they are an
%   approximation (straight lines through NASA's tables).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));                          % C:\VITAL on the path
u = vital.units.constants();
V = 565.6854; h = 10013; CG = 25; g = 32.174;

% 1. VITAL trim (the reference answer)
r = vital.aircraft.f16.trimLevel(V, h, 'CG', CG, 'g_ftps2', g);
assert(strcmp(r.status, 'OK'), 'VITAL trim failed: %s', r.status);
a0 = r.alpha_deg; e0 = r.elevator_deg;

% flight condition exactly as VITAL uses it
AC = vital.aircraft.f16.config('CG_PCT_MAC', CG);
atm = vital.env.atmosphereUS76(h * u.ft);
rho = atm.rho / u.slugft3;                         % slug/ft^3
ine = vital.models.f16.inertia(struct('CG_PCT_MAC', CG));
W = AC.mass / u.slug * g;                          % lbf
cbar = 11.32; S = 300;

    function [CL, CD, Cm] = coeffs(a_deg, e_deg)
        in = struct('vt', V, 'alpha', a_deg, 'beta', 0, 'p', 0, 'q', 0, 'r', 0, ...
                    'el', e_deg, 'ail', 0, 'rdr', 0);
        o = vital.models.f16.aero(in);
        a = deg2rad(a_deg);
        CL = -o.cz * cos(a) + o.cx * sin(a);
        CD = -o.cx * cos(a) - o.cz * sin(a);
        Cm = o.cm + (ine.DXCG / cbar) * o.cz;      % moment moved from 35 % MAC to the CG
    end

% 2-4. values and slopes at the trim point (per radian)
d = 0.01;                                          % deg
[CLt, CDt, Cmt] = coeffs(a0, e0);
[CLa1, CDa1, Cma1] = coeffs(a0 + d, e0); [CLa2, CDa2, Cma2] = coeffs(a0 - d, e0);
[CLe1, ~, Cme1] = coeffs(a0, e0 + d);   [CLe2, ~, Cme2] = coeffs(a0, e0 - d);
per = 1 / deg2rad(2 * d);
CLa = (CLa1 - CLa2) * per;  CLde = (CLe1 - CLe2) * per;
Cma = (Cma1 - Cma2) * per;  Cmde = (Cme1 - Cme2) * per;
dCDda = (CDa1 - CDa2) * per;

% 5. intercepts and drag polar
ar = deg2rad(a0); er = deg2rad(e0);
CL0 = CLt - CLa * ar - CLde * er;
Cm0 = Cmt - Cma * ar - Cmde * er;
K = dCDda / (2 * CLt * CLa);                       % slope of CD0 + K CL^2 along alpha
CD0 = CDt - K * CLt^2;
assert(abs(Cmt) < 1e-6, 'moment about the CG is not zero at the trim point (%g)', Cmt);

c = struct();
c.source = 'NASA NESC F-16 (F16_aero.dml, F16_inertia.dml) via VITAL, linearized at VITAL''s trim point';
c.condition = struct('V_ftps', V, 'h_ft', h, 'cg_pct_mac', CG, 'g_ftps2', g, ...
    'rho_slugft3', rho, 'W_lbf', W, 'S_ft2', S, 'cbar_ft', cbar);
c.coefficients_per_rad = struct('CL0', CL0, 'CLa', CLa, 'CLde', CLde, 'CD0', CD0, 'K', K, ...
    'Cm0', Cm0, 'Cma', Cma, 'Cmde', Cmde);
c.vital_trim = struct('alpha_deg', a0, 'elevator_deg', e0, 'thrust_lbf', r.thrust_lbf, ...
    'throttle_pct', r.throttle_pct, 'CL', CLt, 'CD', CDt);
fid = fopen(fullfile(here, 'f16_coefficients.json'), 'w');
fprintf(fid, '%s', jsonencode(c, 'PrettyPrint', true)); fclose(fid);
fprintf('coefficients written to %s\n', fullfile(here, 'f16_coefficients.json'));
disp(c.coefficients_per_rad); disp(c.vital_trim);
end
