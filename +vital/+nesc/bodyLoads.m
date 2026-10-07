function [F_R, M_R, info] = bodyLoads(ad, u, h, atm, AC) %#ok<INUSL>
%BODYLOADS  Aerodynamic loads of the NESC sphere and brick (body axes, about the CM).
%   [F_R, M_R, info] = vital.nesc.bodyLoads(ad, u, h, atm, AC)
%   The M3 loads signature (AC.loadsFcn). AC from vital.nesc.vehicle.
%     drag    F = -qbar S CD v_air/|v_air|  (zero at zero airspeed)
%     moments M = qbar S [b Cl; cbar Cm; b Cn] (brick: Cl = Clp pb/2V + Clr rb/2V,
%             Cm = Cmq qc/2V, Cn = Cnp pb/2V + Cnr rb/2V, rates w.r.t. the
%             airmass = ad.w_air; VRW clamped at 0.5 ft/s by the model's minValue)
%   qbar uses the true airspeed. Coefficients come from the compiled DAVE-ML
%   models; AC.overrides replaces output coefficients as a case prescribes
%   (proposed ADR N9). CL and CY are 0 in both models; a non-zero value would
%   need wind axes that are undefined at zero airspeed and raises
%   vital:nesc:unsupportedCoefficient.
k = vital.units.constants();
if strcmp(AC.name, 'brick')
    c = AC.aeroModel(struct('VRW', ad.V / k.ft, 'PB', ad.w_air(1), 'QB', ad.w_air(2), 'RB', ad.w_air(3)));
else
    c = AC.aeroModel(struct());
end
for f = fieldnames(AC.overrides).'
    if ~isfield(c, f{1})
        error('vital:badInput', 'override %s is not an output of the %s aero model.', f{1}, AC.name);
    end
    c.(f{1}) = AC.overrides.(f{1});
end
if c.CL ~= 0 || c.CY ~= 0
    error('vital:nesc:unsupportedCoefficient', 'CL/CY must be 0 for the NESC sphere and brick.');
end
if ad.V > 0
    F = -ad.qbar * AC.S * c.CD * ad.v_air / ad.V;
else
    F = [0; 0; 0];
end
M = ad.qbar * AC.S * [AC.b * c.Cl; AC.cbar * c.Cm; AC.b * c.Cn];
F_R = F; M_R = M;
info = struct('F_aero', F, 'M_aero', M, 'coeff', [c.CD c.Cl c.Cm c.Cn], 'outOfEnvelope', logical(c.outOfEnvelope));
end
