function u = constants()
%CONSTANTS  Exact unit conversion factors (docs/CONVENTIONS.md section 1).
%   Multiply a value in the named unit by the factor to get SI.
%   u.ft      foot -> m                  0.3048 (exact, international foot)
%   u.lbm     pound-mass -> kg           0.45359237 (exact)
%   u.g0      standard gravity, m/s^2    9.80665 (exact)
%   u.lbf     pound-force -> N           lbm * g0
%   u.slug    slug -> kg                 lbf / ft (1 slug = 1 lbf s^2/ft)
%   u.slugft2 slug ft^2 -> kg m^2
%   u.psf     lbf/ft^2 -> Pa
%   u.slugft3 slug/ft^3 -> kg/m^3
%   u.kt      knot -> m/s                1852/3600 (exact)
%   u.degR    degree Rankine -> K        5/9 (exact)
u.ft = 0.3048;
u.lbm = 0.45359237;
u.g0 = 9.80665;
u.lbf = u.lbm * u.g0;
u.slug = u.lbf / u.ft;
u.slugft2 = u.slug * u.ft^2;
u.psf = u.lbf / u.ft^2;
u.slugft3 = u.slug / u.ft^3;
u.kt = 1852/3600;
u.degR = 5/9;
end
