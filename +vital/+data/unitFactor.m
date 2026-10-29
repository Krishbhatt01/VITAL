function [factor, siUnits] = unitFactor(units)
%UNITFACTOR  SI conversion of a DAVE-ML / VITAL units string (D1, ADR-042).
%   [factor, siUnits] = vital.data.unitFactor(units)    value_SI = value * factor
%   The factors are those of vital.units.constants (CONVENTIONS 1), computed in the
%   same way as the hand-written code, so a Parameter's si() is bitwise the number
%   vital.aircraft.f16.config computes (e.g. 'ft2': 300 * (0.3048^2)).
%   DAVE-ML units (ANSI/AIAA S-119 abbreviations used by the NASA NESC files):
%     nd frac            1         nd          deg   pi/180     rad
%     ft                 0.3048    m           rad   1          rad
%     ft2                0.3048^2  m2          _deg  180/pi     1/rad   (per degree)
%     ft_s               0.3048    m/s         _rad  1          1/rad
%     slug               14.59...  kg          rad_s 1          rad/s
%     slugft2            1.3558... kgm2        s_rad s_r  1     s/rad
%     lb lbf             4.4482... N           deg_deg 1        nd
%     ftlbf              lbf*ft    Nm          deg_rad pi/180   nd      (deg per rad)
%     pct                0.01      nd          deg_ft (pi/180)/ft  rad/m
%     nmi_h nim_h        1852/3600 m/s ('nim_h' is a typo in F16_control.dml:481)
%     h_nmi              3600/1852 s/m         ft_d  ft/(pi/180)  m/rad
%     s sec              1         s
%   and the SI units themselves: m m2 kg kgm2 N Nm m_s s.
%   Unknown units: vital:data:unknownUnits (never a silent factor 1).
arguments
    units (1,:) char
end
k = vital.units.constants();
d2r = pi / 180;
switch units
    case {'nd', 'frac', 'deg_deg'},  factor = 1;              siUnits = 'nd';
    case 'pct',                      factor = 0.01;           siUnits = 'nd';
    case 'deg',                      factor = d2r;            siUnits = 'rad';
    case 'rad',                      factor = 1;              siUnits = 'rad';
    case '_deg',                     factor = 1 / d2r;        siUnits = '1/rad';
    case '_rad',                     factor = 1;              siUnits = '1/rad';
    case 'rad_s',                    factor = 1;              siUnits = 'rad/s';
    case {'s_rad', 's_r'},           factor = 1;              siUnits = 's/rad';
    case 'deg_rad',                  factor = d2r;            siUnits = 'nd';
    case 'deg_ft',                   factor = d2r / k.ft;     siUnits = 'rad/m';
    case 'ft_d',                     factor = k.ft / d2r;     siUnits = 'm/rad';
    case 'ft',                       factor = k.ft;           siUnits = 'm';
    case 'ft2',                      factor = k.ft^2;         siUnits = 'm2';
    case 'ft_s',                     factor = k.ft;           siUnits = 'm/s';
    case 'slug',                     factor = k.slug;         siUnits = 'kg';
    case 'slugft2',                  factor = k.slugft2;      siUnits = 'kgm2';
    case {'lb', 'lbf'},              factor = k.lbf;          siUnits = 'N';
    case 'ftlbf',                    factor = k.lbf * k.ft;   siUnits = 'Nm';
    case {'nmi_h', 'nim_h'},         factor = k.kt;           siUnits = 'm/s';
    case 'h_nmi',                    factor = 1 / k.kt;       siUnits = 's/m';
    case {'s', 'sec'},               factor = 1;              siUnits = 's';
    case {'m', 'm2', 'kg', 'kgm2', 'N', 'Nm', 'm_s'}
        factor = 1; siUnits = units;
    otherwise
        error('vital:data:unknownUnits', 'unknown units "%s" (vital.data.unitFactor lists the known ones).', units);
end
end
