classdef FlightContext
%FLIGHTCONTEXT  Everything a component needs at one evaluation, computed ONCE and
%   shared by all components (value class; PLAN_CORE_FRAMES 2.9).
%   fl = vital.FlightContext(x, u, env, controlNames, ref)
%     x     13-state [v_b; w_b; q (N->B, scalar first); p_n] (CONVENTIONS 3)
%     u     controls: a vector ordered as controlNames, or a struct by name
%     env   struct g, wind_n, deltaT (as vital.plant.derivatives)
%     ref   struct with b and cbar (m) for the non-dimensional rates
%   fl = vital.FlightContext.fromAirData(ad, u, h, atm, controlNames)
%     the runtime bridge (AircraftModel.toRuntime): air data already computed by
%     vital.plant.derivatives; X, C_bn and Env are then empty
%   Properties: X, U (struct by name), UVector, ControlNames, C_bn (NED -> body),
%     H (geometric height, m), Atm (vital.env.atmosphere), Air
%     (vital.airdata.airData: V, alpha, beta, qbar, mach, w_air, ...), Env.
%   v = fl.control(name)   one control by name (unknown: vital:model:unknownControl)
%   The atmosphere and air data are computed exactly as in vital.plant.derivatives
%   (same functions, same order), so a model evaluates the same numbers.

    properties (SetAccess = private)
        X
        U
        UVector
        ControlNames
        C_bn
        H
        Atm
        Air
        Env
    end

    methods
        function obj = FlightContext(x, u, env, controlNames, ref)
            if nargin == 0, return; end
            if isstruct(u), u = vital.FlightContext.vectorFromStruct(u, controlNames); end
            vital.validate.finite(x, 'state');
            vital.validate.finite(u, 'controls');
            if numel(x) ~= 13
                error('vital:badInput', 'state must have 13 elements, got %d.', numel(x));
            end
            if numel(u) ~= numel(controlNames)
                error('vital:badInput', 'controls must be [%s], got %d elements.', strjoin(controlNames, ' '), numel(u));
            end
            x = x(:); u = u(:);
            q = x(7:10);
            nq = norm(q);
            if nq == 0, error('vital:badInput', 'zero quaternion in the state.'); end
            C = vital.frames.quat2dcm(q / nq);
            h = -x(13);
            atm = vital.env.atmosphere(h, 'DeltaT', env.deltaT);
            obj.Air = vital.airdata.airData(x(1:3), x(4:6), C, env.wind_n, atm, struct('b', ref.b, 'cbar', ref.cbar));
            obj.X = x;
            obj.UVector = u;
            obj.U = cell2struct(num2cell(u), controlNames(:), 1);
            obj.ControlNames = controlNames;
            obj.C_bn = C;
            obj.H = h;
            obj.Atm = atm;
            obj.Env = env;
        end

        function v = control(obj, name)
            if ~isfield(obj.U, name)
                error('vital:model:unknownControl', 'no control channel "%s" (have: %s).', name, strjoin(obj.ControlNames, ', '));
            end
            v = obj.U.(name);
        end
    end

    methods (Static)
        function fl = fromAirData(ad, u, h, atm, controlNames)
            fl = vital.FlightContext.bridge(ad, u(:), h, atm, controlNames);
        end
    end

    methods (Static, Access = private)
        function fl = bridge(ad, u, h, atm, names)
            fl = vital.FlightContext();
            fl = fl.setBridge(ad, u, h, atm, names);
        end

        function u = vectorFromStruct(s, names)
            u = zeros(numel(names), 1);
            for k = 1:numel(names)
                if ~isfield(s, names{k})
                    error('vital:model:unknownControl', 'control "%s" missing from the control struct.', names{k});
                end
                u(k) = s.(names{k});
            end
            extra = setdiff(fieldnames(s), names);
            if ~isempty(extra)
                error('vital:model:unknownControl', 'unknown control(s): %s.', strjoin(extra, ', '));
            end
        end
    end

    methods (Access = private)
        function obj = setBridge(obj, ad, u, h, atm, names)
            obj.Air = ad; obj.UVector = u; obj.U = cell2struct(num2cell(u), names(:), 1);
            obj.ControlNames = names; obj.H = h; obj.Atm = atm;
        end
    end
end
