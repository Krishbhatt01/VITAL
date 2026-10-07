function H = geometricToGeopotential(h)
%GEOMETRICTOGEOPOTENTIAL  US 1976 geopotential height H = r0 h / (r0 + h), r0 = 6356766 m.
%   The US Standard Atmosphere 1976 is defined in geopotential height;
%   VITAL states are in geometric height (CONVENTIONS.md section 4). The
%   NESC consensus simulations use the same conversion (checked in M1).
vital.validate.finite(h, 'geometric height');
r0 = 6356766;
H = r0 * h ./ (r0 + h);
end
