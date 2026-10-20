function atm = atmosphereUS76(h, opts)
%ATMOSPHEREUS76  COMPATIBILITY ALIAS (0.8.1-OOP, ADR-037): returns vital.env.atmosphere.
%   atm = vital.env.atmosphereUS76(h)
%   atm = vital.env.atmosphereUS76(h, 'DeltaT', dT)
%   Since 0.8.1-OOP VITAL's atmosphere is the Aerospace Toolbox atmosisa (ISA),
%   wrapped by vital.env.atmosphere (geometric -> geopotential conversion, range
%   error vital:env:altitudeOutOfRange). ISA equals US 1976 below 32 km (to
%   1e-6 relative, tests/M8/oop/tOopAtmosphere.m). This name is kept only so
%   existing scripts and tests keep working; no +vital file calls it. VITAL's
%   former US 1976 implementation lives test-side in tests/reference/us76Reference.m.
arguments
    h {mustBeNumeric}
    opts.DeltaT (1,1) double = 0
end
atm = vital.env.atmosphere(h, 'DeltaT', opts.DeltaT);
end
