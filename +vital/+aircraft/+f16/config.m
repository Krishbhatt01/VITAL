function AC = config(opts)
%CONFIG  Runtime configuration (SI) of the NESC F-16 for the VITAL plant.
%   AC = vital.aircraft.f16.config()                    CG at 25 % MAC (NESC tests)
%   AC = vital.aircraft.f16.config('CG_PCT_MAC', 30)    other CG, % MAC, 0..100
%   AC = vital.aircraft.f16.config(..., 'BfrpOffset', d) put the geometry datum
%        d (m, body axes) from the MRC; used to prove datum invariance
%   AC = vital.aircraft.f16.config(..., 'AeroScale', struct('Cm_q', 0.3))
%        multipliers for pre-registered mutations (M6), applied in
%        vital.aircraft.f16.loads to ONE term each of the NESC aero model:
%          Cm_q     cm = cmt + cq2v*(Cm_q*cmq)         (pitch damping only; the
%                   czq normal force and its moment arm to the CG are not scaled)
%          Cl_p     cl = cl1 + b2v*(Cl_p*clp*p + clr*r) (roll damping only)
%          Cnt_table  cn = Cnt_table*cnt + dcnda*dail + dcndr*drdr + b2v*(cnp*p + cnr*r)
%                   (the NESC static sideslip yawing-moment TABLE cnt(beta, alpha) about
%                   the MRC, zero at beta = 0; renamed from 'Cn_beta' on 2026-10-05:
%                   the airplane's N_beta about the CG also has the side-force transfer,
%                   so Cnt_table x 0.2 gives body N_beta x 0.335 at the README trim;
%                   Cm_q x 0.3 likewise gives M_q,cg x 0.556; review R2 M5)
%        M8 uncertainty multipliers (vital.uq; tests/M8/tAeroScaleUq.m):
%          Cm_table   cm = Cm_table*cmt + cq2v*(Cm_q*cmq)  (the pitching-moment
%                     table cmt(el, alpha): M_alpha and M_de together)
%          Cl_table   cl = (Cl_table*clt + dclda*dail + dcldr*drdr) + b2v*(Cl_p*clp*p + clr*r)
%                     (the static sideslip rolling-moment table clt(beta, alpha))
%          Cnr_table  cn = (Cnt_table*cnt + dcnda*dail + dcndr*drdr) + b2v*(cnp*p + (Cnr_table*cnr)*r)
%                     (the yaw-damping table cnr(alpha); the M8 plan's "Cn_r",
%                     renamed because tests/M6/tAeroScale.m uses 'Cn_r' as an
%                     unknown name)
%        Unlisted multipliers are 1; AC.aeroScale holds all six. Unknown
%        names or values that are not finite reals >= 0: vital:badInput.
%
%   Sources (hashed in data/MANIFEST.json):
%     reference geometry  F16_aero.dml:368-380  S = 300 ft2, b = 30 ft, cbar = 11.32 ft
%     mass, inertia, CG   F16_inertia.dml (generated vital.models.f16.inertia):
%                         637.1595 slug; Ixx 9496, Iyy 55814, Izz 63100, Ixz 982 slug ft2;
%                         CG DXCG = 0.01 cbar (35 - CG_PCT_MAC) ft forward of the MRC
%     aero moments        about the MRC at 35 % MAC (F16_aero.dml:170-175)
%     thrust              F16_prop.dml: along body x, zero moments about the MRC
%     control ranges      de: aero table range DE1 (F16_aero.dml:948);
%                         da, dr: the NESC control-law output scaling
%                         (F16_control.dml:1117-1185; docs/nesc/NESC_EXTRACT_F16.md
%                         C.2) ail = -21.5 totLatStk, rdr = -30 totPedal with the
%                         stick and pedal clamped to +/-1, so da in +/-21.5 deg,
%                         dr in +/-30 deg. The aileron-rudder interconnect
%                         (+0.008 ail) can add up to 0.172 deg of rudder; it is
%                         part of the law, not of the surface range, and is not
%                         included. (The aero model normalizes ail by 20 deg and
%                         rdr by 30 deg, F16_aero.dml; it defines no limits.)
%   The NESC model has NO engine power lag and NO engine gyroscopic term
%   (ADR-014); none is added here.
%
%   Positions are in BFRP coordinates (body-parallel axes). By default the
%   BFRP is the MRC, so r_mrc = 0 and r_cg = [DXCG; DYCG; DZCG].
arguments
    opts.CG_PCT_MAC (1,1) double = 25
    opts.BfrpOffset (3,1) double = [0; 0; 0]
    opts.AeroScale (1,1) struct = struct()
end
vital.validate.finite(opts.CG_PCT_MAC, 'CG_PCT_MAC');
vital.validate.finite(opts.BfrpOffset, 'BfrpOffset');
if opts.CG_PCT_MAC < 0 || opts.CG_PCT_MAC > 100
    error('vital:badInput', 'CG_PCT_MAC = %g must lie in [0, 100] %% MAC.', opts.CG_PCT_MAC);
end
u = vital.units.constants();
ine = vital.models.f16.inertia(struct('CG_PCT_MAC', opts.CG_PCT_MAC));
AC.name = 'F-16 (NASA NESC DAVE-ML, Stevens & Lewis / Garza & Morelli)';
AC.S = 300 * u.ft^2;
AC.b = 30 * u.ft;
AC.cbar = 11.32 * u.ft;
AC.cgPctMac = opts.CG_PCT_MAC;
AC.mass = ine.XMASS * u.slug;
AC.J = vital.mass.inertiaTensor(ine.XIXX, ine.XIYY, ine.XIZZ, ine.XIXY, ine.XIZX, ine.XIYZ) * u.slugft2;
r_cg_wrt_mrc = [ine.DXCG; ine.DYCG; ine.DZCG] * u.ft;
AC.r_mrc = -opts.BfrpOffset;
AC.r_cg = r_cg_wrt_mrc - opts.BfrpOffset;
AC.loadsFcn = @vital.aircraft.f16.loads;
% Limits that bound trim unknowns. Only limits present in the NESC model are
% given; the others are left unbounded (the model defines none).
AC.limits.alpha_deg = [-10 45];        % aero table range ALPHA1 (F16_aero.dml:952)
AC.limits.de_deg = [-24 24];           % aero table range DE1, el min/max (F16_aero.dml:948)
AC.limits.throttle = [0 1];            % PLA 0..100 % (F16_prop.dml:44)
AC.limits.beta_deg = [-30 30];         % aero table range BETA2
AC.limits.da_deg = [-21.5 21.5];      % NESC control law ail = -21.5 latStk, |latStk| <= 1 (F16_control.dml:1117-1185)
AC.limits.dr_deg = [-30 30];          % NESC control law rdr = -30 pedal, |pedal| <= 1 (same lines; ARI excluded, see header)
AC.controlNames = {'de', 'da', 'dr', 'throttle'};
% Aerodynamic multipliers for pre-registered mutations (M6) and the M8
% uncertainty analysis. Default 1 = the
% NESC model unchanged (vital.aircraft.f16.loads then skips them entirely).
AC.aeroScale = struct('Cm_q', 1, 'Cl_p', 1, 'Cnt_table', 1, 'Cm_table', 1, 'Cl_table', 1, 'Cnr_table', 1);
for f = fieldnames(opts.AeroScale).'
    if ~isfield(AC.aeroScale, f{1})
        error('vital:badInput', 'unknown AeroScale multiplier "%s" (allowed: Cm_q, Cl_p, Cnt_table, Cm_table, Cl_table, Cnr_table; ''Cn_beta'' was renamed Cnt_table on 2026-10-05).', f{1});
    end
    v = opts.AeroScale.(f{1});
    if ~(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v >= 0)
        error('vital:badInput', 'AeroScale.%s must be a finite real scalar >= 0.', f{1});
    end
    AC.aeroScale.(f{1}) = double(v);
end
end
