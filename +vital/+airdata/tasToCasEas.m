function [cas, eas] = tasToCasEas(tas, atm)
%TASTOCASEAS  Calibrated and equivalent airspeed from true airspeed (subsonic).
%   Impact pressure (isentropic, gamma = 1.4):
%     qc  = p [ (1 + 0.2 M^2)^3.5 - 1 ],  M = TAS / a
%     CAS = a0 sqrt( 5 [ (qc/p0 + 1)^(2/7) - 1 ] )
%     EAS = TAS sqrt(rho / rho0)
%   with sea-level US 1976 values p0 = 101325 Pa, a0 and rho0 from
%   T0 = 288.15 K. M >= 1 raises vital:airdata:supersonic (FC-108): the
%   subsonic pitot relation does not apply behind a normal shock.
vital.validate.finite(tas, 'true airspeed');
vital.validate.finite([atm.p atm.rho atm.a], 'atmosphere');
M = tas ./ atm.a;
if any(M(:) >= 1)
    error('vital:airdata:supersonic', 'Mach %.3f: subsonic CAS relation not valid.', max(M(:)));
end
R = 8314.32 / 28.9644; T0 = 288.15; p0 = 101325;
a0 = sqrt(1.4 * R * T0); rho0 = p0 / (R * T0);
qc = atm.p .* ((1 + 0.2 * M.^2).^3.5 - 1);
cas = a0 * sqrt(5 * ((qc / p0 + 1).^(2/7) - 1));
eas = tas .* sqrt(atm.rho / rho0);
end
