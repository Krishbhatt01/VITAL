function [F_R, M_R, info] = loads(ad, u, h, atm, AC) %#ok<INUSD>
%LOADS  F-16 aerodynamic and propulsive loads about the BFRP, body axes (SI).
%   [F_R, M_R, info] = vital.aircraft.f16.loads(ad, u, h, atm, AC)
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
    % M6 mutations (vital.aircraft.f16.config 'AeroScale'): each multiplier that
    % is not 1 rebuilds ONE coefficient with ONE term scaled, in the generated
    % model's own order of operations; multipliers equal to 1 leave a untouched.
    s = AC.aeroScale;
    if s.Cm_q ~= 1
        a.cm = a.cmt + a.cq2v * (s.Cm_q * a.cmq);
    end
    if s.Cl_p ~= 1
        a.cl = a.cl1 + a.b2v * ((s.Cl_p * a.clp * a.p) + (a.clr * a.r));
    end
    if s.Cnt_table ~= 1
        a.cn = (s.Cnt_table * a.cnt + a.dcnda * a.dail + a.dcndr * a.drdr) + a.b2v * ((a.cnp * a.p) + (a.cnr * a.r));
    end
end
qS = ad.qbar * AC.S;
F_aero = qS * [a.cx; a.cy; a.cz];
M_aero = qS * [AC.b * a.cl; AC.cbar * a.cm; AC.b * a.cn];
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
