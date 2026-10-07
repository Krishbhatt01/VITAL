function atm = atmosphereUS76(h, opts)
%ATMOSPHEREUS76  US Standard Atmosphere 1976, 0-86 km, at geometric height h (m).
%   atm = vital.env.atmosphereUS76(h)                 standard day
%   atm = vital.env.atmosphereUS76(h, 'DeltaT', dT)   ISA + dT (K)
%   Returns a struct of arrays the size of h: T (K), p (Pa), rho (kg/m^3),
%   a (m/s), H (geopotential height, m), h (geometric height, m).
%
%   Method: the seven lower-atmosphere layers of NASA-TM-X-74335 in
%   geopotential height, with R = R*/M0 = 8314.32/28.9644 J/(kg K),
%   g0 = 9.80665 m/s^2, gamma = 1.4. Temperatures are molecular-scale
%   temperatures, which equal kinetic temperature below 80 km.
%   ISA + dT: T = T_std + dT, p = p_std (same pressure altitude),
%   rho = p/(R T), a = sqrt(gamma R T).
%
%   Range: geopotential H in [-5000, 84852] m. Outside it the function
%   raises vital:env:altitudeOutOfRange; it never clamps silently (FC-106;
%   AAMF isa1976 clamped to [-5, 47] km without warning).
arguments
    h {mustBeNumeric}
    opts.DeltaT (1,1) double = 0
end
vital.validate.finite(h, 'geometric height');
vital.validate.finite(opts.DeltaT, 'DeltaT');
H = vital.env.geometricToGeopotential(h);
if any(H(:) < -5000 | H(:) > 84852)
    error('vital:env:altitudeOutOfRange', ...
        'geopotential height outside [-5000, 84852] m (US 1976 lower atmosphere): min %.1f, max %.1f.', ...
        min(H(:)), max(H(:)));
end
g0 = 9.80665; R = 8314.32 / 28.9644; gam = 1.4;
Hb = [0 11000 20000 32000 47000 51000 71000];
Lb = [-6.5 0 1.0 2.8 0 -2.8 -2.0] * 1e-3;
Tb = zeros(1, 7); pb = zeros(1, 7);
Tb(1) = 288.15; pb(1) = 101325;
for i = 2:7
    dH = Hb(i) - Hb(i-1);
    Tb(i) = Tb(i-1) + Lb(i-1) * dH;
    pb(i) = layerPressure(pb(i-1), Tb(i-1), Lb(i-1), dH, g0, R);
end
T = zeros(size(H)); p = zeros(size(H));
for n = 1:numel(H)
    i = find(H(n) >= Hb, 1, 'last');
    if isempty(i), i = 1; end            % -5000 <= H < 0: first layer extended
    dH = H(n) - Hb(i);
    T(n) = Tb(i) + Lb(i) * dH;
    p(n) = layerPressure(pb(i), Tb(i), Lb(i), dH, g0, R);
end
T = T + opts.DeltaT;
atm.T = T;
atm.p = p;
atm.rho = p ./ (R * T);
atm.a = sqrt(gam * R * T);
atm.H = H;
atm.h = h;
end

function p = layerPressure(pb, Tb, L, dH, g0, R)
if L == 0
    p = pb * exp(-g0 * dH / (R * Tb));
else
    p = pb * (Tb / (Tb + L * dH))^(g0 / (R * L));
end
end
