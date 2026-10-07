function eas = equivalentAirspeed(V, rho)
%EQUIVALENTAIRSPEED  EAS = TAS sqrt(rho/rho0), rho0 = US 1976 sea-level density (m/s).
%   eas = vital.nesc.equivalentAirspeed(V, rho)   V true airspeed (m/s), rho (kg/m^3)
%   The KEAS definition used with the NESC control laws (proposed ADR N6;
%   the TM gives none): it reproduces the TM's 287.98 KEAS at the case-11 IC
%   (Vol II p.256). Valid at any Mach (no pitot model), unlike
%   vital.airdata.tasToCasEas, which rejects M >= 1.
vital.validate.finite([V(:); rho(:)], 'V, rho');
rho0 = 101325 / (8314.32 / 28.9644 * 288.15);
eas = V .* sqrt(rho / rho0);
end
