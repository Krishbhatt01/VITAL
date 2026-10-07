function [n, status, reason] = nAlphaSteady(Aair, Bair, V0, g, gamma0, opts)
%NALPHASTEADY  MIL-F-8785C n/alpha: steady-state normal load factor per alpha.
%   [n, status, reason] = vital.linear.nAlphaSteady(Aair, Bair, V0, g, gamma0)
%     Aair, Bair  longitudinal model in [V alpha q theta] form (4x4, 4xm; the
%                 first input column is the pitch control de), e.g.
%                 lin.lon.air.A / .B of vital.linear.linearize
%     V0, g       trim airspeed (m/s) and gravity (m/s^2)
%     gamma0      trim flight-path angle (rad)
%   MIL-F-8785C 6.2 (p.77; docs/MIL8785C_EXTRACT.md sec. 4): "the steady-state
%   normal acceleration change per unit change in angle of attack for an
%   incremental pitch control deflection at constant speed". With dV = 0 the
%   alpha and q rows give 0 = A_sp [alpha; q] + b_de de, with
%   A_sp = [Z_a, 1 + Z_q; M_a, M_q] and b_de = [Z_d; M_d]. Solving for q and de
%   per unit alpha,
%       q/alpha = (M_a Z_d - Z_a M_d) / (M_d (1 + Z_q) - M_q Z_d),
%   and n/alpha = (V0/g) q/alpha (g/rad). The elevator lift Z_d and Z_q are
%   included. This is the same definition as vital.fq.metrics
%   (n_alpha_g_per_rad).
%   status  'OK'
%           'NOT_LEVEL'  |gamma0| > GammaTol (default 1e-6): the gravity terms
%                        of alphadot do not vanish, and the definition is used
%                        here for level trims only
%           'SINGULAR'   rcond of the [q de] system < 1e-12
%   n is NaN unless status is 'OK' (never a plausible number).
%   Errors: vital:badInput (sizes, non-finite values).
arguments
    Aair double
    Bair double
    V0 (1,1) double
    g (1,1) double
    gamma0 (1,1) double
    opts.GammaTol (1,1) double = 1e-6
end
if ~isequal(size(Aair), [4 4]) || size(Bair, 1) ~= 4 || size(Bair, 2) < 1
    error('vital:badInput', 'Aair must be 4x4 and Bair 4xm ([V alpha q theta] form).');
end
vital.validate.finite(Aair, 'Aair'); vital.validate.finite(Bair(:, 1), 'Bair(:,1)');
vital.validate.finite([V0 g gamma0 opts.GammaTol], 'V0, g, gamma0, GammaTol');
n = NaN;
if abs(gamma0) > opts.GammaTol
    status = 'NOT_LEVEL';
    reason = sprintf('gamma0 = %.3g rad: the constant-speed steady state is used for level trims only', gamma0);
    return
end
Asp = Aair(2:3, 2:3);
bde = Bair(2:3, 1);
K = [Asp(:, 2), bde];                  % unknowns [q; de] per unit alpha
if rcond(K) < 1e-12
    status = 'SINGULAR';
    reason = 'the [alpha q] steady state per pitch control is singular';
    return
end
z = K \ (-Asp(:, 1));
n = (V0 / g) * z(1);
status = 'OK'; reason = '';
end
