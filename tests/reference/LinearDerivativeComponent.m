classdef LinearDerivativeComponent < vital.Component
%LINEARDERIVATIVECOMPONENT  TEST-ONLY component (tests/reference, never in +vital):
%   constant dimensional stability and control derivatives, so that the aircraft
%   built from it (tests/reference/linearDerivativeAircraft.m) has closed-form
%   trim, Jacobian and modes (increment I0, ADR-041).
%   c = LinearDerivativeComponent(name, axis, P)
%     axis  the component axis; its origin is the point the moments are about
%           and its axes the components of F and M. linearDerivativeAircraft
%           puts it at the CG, body-parallel.
%     P     struct of the reference state and the derivatives (SI):
%           reference  Ue, We (m/s, body velocity at the reference state),
%                      de_e (rad), t_e (throttle, 0..1)
%           constants  Xe, Ze (N), Me (N m): the loads at the reference state
%           longitudinal (per m/s of u, w; per rad/s of q; per rad of de; per unit throttle)
%                      Xu Xw Xq Xde Xt   (N ...)
%                      Zu Zw Zq Zde Zt   (N ...)
%                      Mu Mw Mq Mde Mt   (N m ...)
%           lateral    Yv Yp Yr Yda Ydr  (N ...)
%                      Lv Lp Lr Lda Ldr  (N m ...)
%                      Nv Np Nr Nda Ndr  (N m ...)
%   Loads in the component axis, about its origin, with du = u - Ue, dw = w - We,
%   dde = de - de_e, dt = throttle - t_e and (u, v, w) = fl.Air.v_air,
%   (p, q, r) = fl.Air.w_air (air-relative, so the toRuntime bridge, whose
%   FlightContext has no state X, gives the same numbers):
%     X = Xe + Xu du + Xw dw + Xq q + Xde dde + Xt dt
%     Y =      Yv v  + Yp p  + Yr r + Yda da  + Ydr dr
%     Z = Ze + Zu du + Zw dw + Zq q + Zde dde + Zt dt
%     L =      Lv v  + Lp p  + Lr r + Lda da  + Ldr dr
%     M = Me + Mu du + Mw dw + Mq q + Mde dde + Mt dt
%     N =      Nv v  + Np p  + Nr r + Nda da  + Ndr dr
%   This is the body-axis small-disturbance aerodynamic model of Etkin & Reid,
%   Dynamics of Flight: Stability and Control, 3rd ed. (1996), sec. 4.9 (constant
%   derivatives; no alpha-dot terms; no density dependence), made exactly linear
%   in the body velocities, so the only non-linear terms of the aircraft are
%   those of the rigid-body equations (gravity, w x v, w x J w).
%   Channels {'de','da','dr','throttle'}: the 4 controls the pre-I1 consumers accept.

    properties (SetAccess = protected)
        P struct = struct()
    end

    methods
        function obj = LinearDerivativeComponent(name, axis, P)
            obj = obj.initComponent(name, axis, {'de', 'da', 'dr', 'throttle'}, []);
            need = {'Ue', 'We', 'de_e', 't_e', 'Xe', 'Ze', 'Me', ...
                'Xu', 'Xw', 'Xq', 'Xde', 'Xt', 'Zu', 'Zw', 'Zq', 'Zde', 'Zt', 'Mu', 'Mw', 'Mq', 'Mde', 'Mt', ...
                'Yv', 'Yp', 'Yr', 'Yda', 'Ydr', 'Lv', 'Lp', 'Lr', 'Lda', 'Ldr', 'Nv', 'Np', 'Nr', 'Nda', 'Ndr'};
            miss = need(~isfield(P, need));
            if ~isempty(miss)
                error('vital:badInput', 'LinearDerivativeComponent: missing parameter(s) %s.', strjoin(miss, ', '));
            end
            obj.P = P;
        end
    end

    methods (Hidden)
        function [F, M, info] = computeLoads(obj, fl)
            P = obj.P;
            va = fl.Air.v_air; w = fl.Air.w_air;
            du = va(1) - P.Ue; v = va(2); dw = va(3) - P.We;
            p = w(1); q = w(2); r = w(3);
            dde = fl.U.de - P.de_e; da = fl.U.da; dr = fl.U.dr; dt = fl.U.throttle - P.t_e;
            X = P.Xe + P.Xu * du + P.Xw * dw + P.Xq * q + P.Xde * dde + P.Xt * dt;
            Y = P.Yv * v + P.Yp * p + P.Yr * r + P.Yda * da + P.Ydr * dr;
            Z = P.Ze + P.Zu * du + P.Zw * dw + P.Zq * q + P.Zde * dde + P.Zt * dt;
            L = P.Lv * v + P.Lp * p + P.Lr * r + P.Lda * da + P.Ldr * dr;
            Mm = P.Me + P.Mu * du + P.Mw * dw + P.Mq * q + P.Mde * dde + P.Mt * dt;
            N = P.Nv * v + P.Np * p + P.Nr * r + P.Nda * da + P.Ndr * dr;
            F = [X; Y; Z];
            M = [L; Mm; N];
            info = struct('outOfEnvelope', false);
        end
    end
end
