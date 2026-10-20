function atm = atmosphere(h, opts)
%ATMOSPHERE  VITAL's atmosphere: the Aerospace Toolbox atmosisa (ISA) at geometric height h (m).
%   atm = vital.env.atmosphere(h)                 standard day
%   atm = vital.env.atmosphere(h, 'DeltaT', dT)   ISA + dT (K)
%   Returns a struct of arrays the size of h: T (K), p (Pa), rho (kg/m^3),
%   a (m/s), H (geopotential height, m), h (geometric height, m).
%
%   Since 0.8.1-OOP (ADR-037, user decision 3) this replaces VITAL's own US 1976
%   implementation everywhere in the core (the old one is kept test-side as
%   tests/reference/us76Reference.m, the independent oracle). ISA (ICAO) and US
%   1976 are identical below 32 km; atmosisa's constants (R = p0/(rho0 T0) with
%   rho0 = 1.225 kg/m^3) differ from US 1976's R*/M0 by ~7e-7 relative, so the
%   two agree to 1e-6 (tests/M8/oop/tOopAtmosphere.m).
%
%   WRAPPING (the two ways atmosisa differs from what VITAL needs):
%   1. atmosisa takes GEOPOTENTIAL height. VITAL states hold geometric height
%      (CONVENTIONS 4), so H = vital.env.geometricToGeopotential(h) first.
%   2. Outside H in [-5000, 84852] m atmosisa holds the boundary value and only
%      warns (the silent clamp VITAL fixed in M1, FC-106). Here the range is
%      checked FIRST and a violation is the error vital:env:altitudeOutOfRange;
%      atmosisa is then called with 'action', 'None', so it never warns.
%   ISA + dT: T = T_std + dT, p = p_std (same pressure altitude),
%   rho = p/(R T), a = sqrt(1.4 R T) with atmosisa's R (scaling its outputs).
%
%   SPEED: atmosisa validates its arguments (enumeration types) on every call
%   (~0.3 ms, 10x VITAL's former function). A one-entry cache on the exact
%   geopotential height of a scalar call returns the stored atmosisa result when
%   the altitude repeats (trim, linearization, flying qualities: the calls of one
%   solve share h). The cache is exact: atmosisa is a pure function of H.
arguments
    h {mustBeNumeric}
    opts.DeltaT (1,1) double = 0
end
persistent lastH lastT lastA lastP lastRho
vital.validate.finite(h, 'geometric height');
vital.validate.finite(opts.DeltaT, 'DeltaT');
H = vital.env.geometricToGeopotential(h);
if any(H(:) < -5000 | H(:) > 84852)
    error('vital:env:altitudeOutOfRange', ...
        'geopotential height outside [-5000, 84852] m (ISA/atmosisa range): min %.1f, max %.1f.', ...
        min(H(:)), max(H(:)));
end
if isscalar(H) && ~isempty(lastH) && H == lastH
    T = lastT; a = lastA; p = lastP; rho = lastRho;
else
    [T, a, p, rho] = atmosisa(H, 'action', 'None');
    if isscalar(H)
        lastH = H; lastT = T; lastA = a; lastP = p; lastRho = rho;
    end
end
if opts.DeltaT ~= 0
    Tstd = T;
    T = Tstd + opts.DeltaT;
    rho = rho .* (Tstd ./ T);
    a = a .* sqrt(T ./ Tstd);
end
atm.T = T;
atm.p = p;
atm.rho = rho;
atm.a = a;
atm.H = H;
atm.h = h;
end
