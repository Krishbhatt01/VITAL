function fac = f16Factory(opts)
%F16FACTORY  Aircraft factory for vital.fq.assess: the NESC F-16 at a condition.
%   fac = vital.fq.f16Factory()
%   fac = vital.fq.f16Factory('AeroScale', struct('Cm_q', 0.3))   a mutation
%   fac = vital.fq.f16Factory('Controller', b)     the AUGMENTED aircraft (M7):
%         b is a builder ctrl = b(AC, env, tr) of a STATIC controller in the
%         vital.sim.run form (e.g. @(AC, env, tr) vital.ctrl.pitchSas(AC, env, tr,
%         'Kq', 0.2)); vital.fq.evaluatePoint calls it after the trim and
%         linearizes the closed loop. Default [] = the bare airframe: ac then has
%         no controllerFcn field and every M6 result is unchanged (bit-identical;
%         tests/M7/tCtrlFq.m defaultPathBitIdentical).
%   ac  = fac(c)
%
%   c (a condition point of vital.fq.gridPoints) must have
%     h_ft          geometric altitude, ft
%     mach  or  V_ftps   Mach number (V = M a(h), US 1976 standard day) or true
%                   airspeed, ft/s (exactly one of the two)
%     cg_pct_mac    CG, % MAC
%   and may have g_ftps2 (default 32.174, the NESC README value) and gamma_deg
%   (default 0; the n/alpha metric needs level flight).
%   ac fields: AC (vital.aircraft.f16.config), env (flat Earth, zero wind,
%   standard day), trimCond (vital.trim.solve condition), V_ftps, mach_nominal,
%   keas (equivalent airspeed, kt: V sqrt(rho/rho0), US 1976; used by the
%   validity envelope, review R2 M8), and controllerFcn (the builder b; only
%   with 'Controller').
%   Errors: vital:fq:badConditions (missing or ambiguous axis); vital:badInput
%   ('Controller' not a function handle).
arguments
    opts.AeroScale (1,1) struct = struct()
    opts.Controller = []
end
if ~isempty(opts.Controller) && ~isa(opts.Controller, 'function_handle')
    error('vital:badInput', 'Controller must be a builder function handle ctrl = b(AC, env, tr), or [].');
end
s = opts.AeroScale;
ctrl = opts.Controller;
fac = @(c) build(c, s, ctrl);
end

function ac = build(c, s, ctrl)
ft = 0.3048;
if ~isfield(c, 'h_ft') || ~isfield(c, 'cg_pct_mac')
    error('vital:fq:badConditions', 'an F-16 condition needs h_ft and cg_pct_mac.');
end
hasM = isfield(c, 'mach'); hasV = isfield(c, 'V_ftps');
if hasM == hasV
    error('vital:fq:badConditions', 'an F-16 condition needs exactly one of mach and V_ftps.');
end
g = 32.174; if isfield(c, 'g_ftps2'), g = c.g_ftps2; end
gam = 0; if isfield(c, 'gamma_deg'), gam = c.gamma_deg; end
h = c.h_ft * ft;
atm = vital.env.atmosphereUS76(h);
if hasM
    V = c.mach * atm.a;
    mach = c.mach;
else
    V = c.V_ftps * ft;
    mach = V / atm.a;
end
atm0 = vital.env.atmosphereUS76(0);
ac.AC = vital.aircraft.f16.config('CG_PCT_MAC', c.cg_pct_mac, 'AeroScale', s);
ac.env = struct('g', g * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
if gam == 0, type = 'level'; else, type = 'climb'; end
ac.trimCond = struct('type', type, 'V', V, 'h', h, 'gamma', deg2rad(gam), 'psi', 0);
ac.V_ftps = V / ft;
ac.mach_nominal = mach;
ac.keas = V * sqrt(atm.rho / atm0.rho) / (1852 / 3600);
if ~isempty(ctrl), ac.controllerFcn = ctrl; end   % M7; absent for the bare airframe
end
