function [c, info] = aeroCoefficients(flight, AC)
%AEROCOEFFICIENTS  F-16 body-axis aero coefficients about the MRC for a
%   vital.AeroTableComponent (0.9.1-CORE).
%   [c, info] = vital.aircraft.f16.aeroCoefficients(flight, AC)
%     flight  vital.FlightContext (air data, controls de, da, dr by name)
%     AC      vital.aircraft.f16.config(...) (reference geometry and AeroScale)
%     c       [CX CY CZ Cl Cm Cn] with the AeroScale multipliers applied
%   ONE PHYSICS SOURCE: the coefficients come from vital.aircraft.f16.loads itself
%   (its 'aero' part, info.coeff), so the M6/M8 AeroScale build-up exists only
%   there (PLAN_DEVIATIONS D2). info.outOfEnvelope is the aero tables' flag; the
%   engine's flag comes from the engine component (vital.aircraft.f16.engineThrust).
u = [flight.U.de; flight.U.da; flight.U.dr; 0];
[~, ~, li] = vital.aircraft.f16.loads(flight.Air, u, flight.H, flight.Atm, AC, 'aero');
c = li.coeff;
info.outOfEnvelope = li.outOfEnvelope;
end
