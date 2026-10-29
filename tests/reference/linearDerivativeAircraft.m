function [m, P] = linearDerivativeAircraft()
%LINEARDERIVATIVEAIRCRAFT  The analytic "linear-derivative" aircraft (TEST FIXTURE,
%   not a real aircraft; increment I0, ADR-041).
%   [m, P] = linearDerivativeAircraft()
%     m  a compiled vital.AircraftModel with ONE tests/reference/LinearDerivativeComponent
%        at the CG (body-parallel) and controls {'de','da','dr','throttle'}
%     P  the parameters: mass m_kg, inertia Ixx Iyy Izz Ixz (kg m^2, Ixz the
%        positive integral, J13 = -Ixz), g, the reference state Ve, alpha_e,
%        Ue, We, theta_e, de_e, t_e, h_e, the dimensional derivatives of the
%        component (SI; see LinearDerivativeComponent) and a_*: the same
%        derivatives per unit mass (forces) or per unit inertia (L/Ixx, M/Iyy,
%        N/Izz), the numbers chosen below.
%   The reference state is a wings-level, unaccelerated flight at Ve, alpha_e,
%   theta_e = alpha_e (gamma = 0), de_e, t_e. The constant loads are chosen so it
%   is an equilibrium exactly (Etkin & Reid 1996, sec. 4.9, the reference steady
%   state):  Xe = m g sin(theta_e),  Ze = -m g cos(theta_e),  Me = 0
%   (the body-axis weight is m g [-sin(theta); 0; cos(theta)] at phi = 0).
%   Numbers: a light-aircraft-like set (short period, phugoid, Dutch roll pairs;
%   roll and spiral real roots), not a published aircraft.

P.m_kg = 1200;
P.Ixx = 1800; P.Iyy = 3500; P.Izz = 4800; P.Ixz = 250;
P.g = 9.80665;
P.Ve = 50; P.alpha_e = 0.08; P.theta_e = P.alpha_e;
P.Ue = P.Ve * cos(P.alpha_e); P.We = P.Ve * sin(P.alpha_e);
P.de_e = -0.04; P.t_e = 0.45; P.h_e = 1000;
% per unit mass (m/s^2 per m/s, per rad/s, per rad, per unit throttle)
a.Xu = -0.045; a.Xw = 0.12;  a.Xq = 0.3;  a.Xde = 0.0;  a.Xt = 6.0;
a.Zu = -0.40;  a.Zw = -2.2;  a.Zq = -1.5; a.Zde = -4.0; a.Zt = -0.3;
a.Yv = -0.25;  a.Yp = 0.1;   a.Yr = 0.4;  a.Yda = 0.0;  a.Ydr = 2.5;
% per unit inertia (rad/s^2 per ...): M/Iyy, L/Ixx, N/Izz
a.Mu = 0.002;  a.Mw = -0.12; a.Mq = -2.1; a.Mde = -11.0; a.Mt = 0.05;
a.Lv = -0.06;  a.Lp = -4.5;  a.Lr = 0.6;  a.Lda = 9.0;   a.Ldr = 0.6;
a.Nv = 0.025;  a.Np = -0.12; a.Nr = -0.35; a.Nda = -0.3; a.Ndr = -2.2;
P.a = a;
for f = {'Xu', 'Xw', 'Xq', 'Xde', 'Xt', 'Zu', 'Zw', 'Zq', 'Zde', 'Zt', 'Yv', 'Yp', 'Yr', 'Yda', 'Ydr'}
    P.(f{1}) = P.m_kg * a.(f{1});
end
for f = {'Mu', 'Mw', 'Mq', 'Mde', 'Mt'}, P.(f{1}) = P.Iyy * a.(f{1}); end
for f = {'Lv', 'Lp', 'Lr', 'Lda', 'Ldr'}, P.(f{1}) = P.Ixx * a.(f{1}); end
for f = {'Nv', 'Np', 'Nr', 'Nda', 'Ndr'}, P.(f{1}) = P.Izz * a.(f{1}); end
P.Xe = P.m_kg * P.g * sin(P.theta_e);
P.Ze = -P.m_kg * P.g * cos(P.theta_e);
P.Me = 0;
P.r_cg = [0.4; 0; 0.15];

bfrp = vital.Axis.root('bfrp');
cg = vital.Axis(P.r_cg, eye(3), bfrp, 'Name', 'cg');
ref = vital.Axis([0; 0; 0], eye(3), cg, 'Name', 'derivRef');
comp = LinearDerivativeComponent('derivatives', ref, P);
J = [P.Ixx 0 -P.Ixz; 0 P.Iyy 0; -P.Ixz 0 P.Izz];
mp = vital.MassProperties(P.m_kg, cg, vital.InertiaTensor(J, cg));
lim = struct('alpha_deg', [-10 30], 'beta_deg', [-20 20], 'de_deg', [-25 25], 'da_deg', [-21.5 21.5], ...
    'dr_deg', [-30 30], 'throttle', [0 1]);
m = vital.AircraftModel('ANALYTIC linear-derivative aircraft (test fixture)', [bfrp cg ref], {comp}, mp, ...
    {'de', 'da', 'dr', 'throttle'}, 'Ref', struct('S', 16, 'b', 10, 'cbar', 1.6), 'Limits', lim);
m = m.compile();
end
