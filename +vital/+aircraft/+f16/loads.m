function [F_R, M_R, info] = loads(ad, u, h, atm, AC, part) %#ok<INUSD>
%LOADS  F-16 aerodynamic and propulsive loads about the BFRP, body axes (SI).
%   [F_R, M_R, info] = vital.aircraft.f16.loads(ad, u, h, atm, AC)
%   [F_R, M_R, info] = vital.aircraft.f16.loads(..., 'aero')   aero column only
%     (0.9.1-CORE, for the AeroTableComponent of vital.aircraft.f16.model; the
%     engine model is not evaluated, u(4) unused; info has F_aero, M_aero, coeff
%     and the aero table outOfEnvelope only). Without 'part' nothing changes.
%     ad  air data (vital.airdata.airData); u = [de da dr throttle] (rad, 0..1)
%     h   geometric altitude (m)
%   Unit conversion happens only here, at the boundary of the NASA models:
%     aero inputs  vt ft/s, alpha/beta deg, p q r rad/s, el/ail/rdr deg
%     prop inputs  PWR = 100*throttle (% PLA), ALT ft, RMACH
%   Aero:  F = qbar S [CX; CY; CZ],  M_mrc = qbar S [b Cl; cbar Cm; b Cn]
%   Prop:  F = [FEX; FEY; FEZ] lbf,  M_mrc = [TEL; TEM; TEN] ft lbf (all zero in F16_prop.dml)
%   Both are given about the MRC and moved to the BFRP: M_R = M_mrc + r_mrc x F.
%   Control signs of the NESC model equal VITAL's (CONVENTIONS 7; tested in tF16Plant).
k = vital.units.constants();
in = struct('vt', ad.V / k.ft, 'alpha', rad2deg(ad.alpha), 'beta', rad2deg(ad.beta), ...
    'p', ad.w_air(1), 'q', ad.w_air(2), 'r', ad.w_air(3), ...
    'el', rad2deg(u(1)), 'ail', rad2deg(u(2)), 'rdr', rad2deg(u(3)));
a = vital.models.f16.aero(in);
if isfield(AC, 'aeroScale')
    % M6 mutations and M8 uncertainty multipliers (vital.aircraft.f16.config
    % 'AeroScale'): each multiplier that is not 1 scales ONE term of the generated
    % model and the coefficient is rebuilt in the model's own order of operations;
    % multipliers equal to 1 leave a untouched.
    s = AC.aeroScale;
    split = s.Cm_basic ~= 1 || s.Cm_de ~= 1;
    if split
        % M8 amendment R4-5 (aero-database build-up): cmt0 = cmt(el = 0, alpha) is
        % the static part, cmt - cmt0 the elevator increment (elevator power)
        in0 = in; in0.el = 0;
        a0 = vital.models.f16.aero(in0);
        a.cmt = s.Cm_basic * a0.cmt + s.Cm_de * (a.cmt - a0.cmt);
    end
    if s.Cm_table ~= 1
        a.cmt = s.Cm_table * a.cmt;                       % M8: pitching-moment table cmt(el, alpha)
    end
    if s.Cm_q ~= 1 || s.Cm_table ~= 1 || split
        a.cm = a.cmt + a.cq2v * (s.Cm_q * a.cmq);
    end
    if s.Cl_table ~= 1
        a.cl1 = (s.Cl_table * a.clt + (a.dclda * a.dail) + (a.dcldr * a.drdr));   % M8: rolling-moment table clt(beta, alpha)
    end
    if s.Cl_p ~= 1 || s.Cl_table ~= 1
        a.cl = a.cl1 + a.b2v * ((s.Cl_p * a.clp * a.p) + (a.clr * a.r));
    end
    if s.Cn_r ~= 1
        a.cnr = s.Cn_r * a.cnr;                           % M8: yaw-damping table cnr(alpha) (was Cnr_table, R4-6)
    end
    if s.Cnt_table ~= 1
        a.cn = (s.Cnt_table * a.cnt + a.dcnda * a.dail + a.dcndr * a.drdr) + a.b2v * ((a.cnp * a.p) + (a.cnr * a.r));
    elseif s.Cn_r ~= 1
        a.cn = a.cn1 + a.b2v * ((a.cnp * a.p) + (a.cnr * a.r));
    end
end
qS = ad.qbar * AC.S;
F_aero = qS * [a.cx; a.cy; a.cz];
M_aero = qS * [AC.b * a.cl; AC.cbar * a.cm; AC.b * a.cn];
if nargin >= 6 && strcmp(part, 'aero')
    % 0.9.1-CORE (ADR-040): aero only, for vital.aircraft.f16.aeroCoefficients; the
    % engine is its own component there, so the engine model is not evaluated here
    F_R = F_aero;
    M_R = M_aero + cross(AC.r_mrc, F_aero);
    info.F_aero = F_aero; info.M_aero = M_aero;
    info.coeff = [a.cx a.cy a.cz a.cl a.cm a.cn];
    info.outOfEnvelope = a.outOfEnvelope;
    return
end
p = vital.models.f16.prop(struct('PWR', 100 * u(4), 'ALT', h / k.ft, 'RMACH', ad.mach));
F_prop = [p.FEX; p.FEY; p.FEZ] * k.lbf;
M_prop = [p.TEL; p.TEM; p.TEN] * k.lbf * k.ft;
F_R = [F_aero, F_prop];
M_R = [M_aero + cross(AC.r_mrc, F_aero), M_prop + cross(AC.r_mrc, F_prop)];
info.F_aero = F_aero; info.M_aero = M_aero;
info.F_prop = F_prop; info.M_prop = M_prop;
info.coeff = [a.cx a.cy a.cz a.cl a.cm a.cn];
info.thrust_lbf = p.FEX;
info.outOfEnvelope = a.outOfEnvelope || p.outOfEnvelope;
end
