classdef FlightContext
%FLIGHTCONTEXT  Everything a component needs at one evaluation, computed ONCE and
%   shared by all components (value class; PLAN_CORE_FRAMES 2.9).
%   fl = vital.FlightContext(x, u, env, controlNames, ref)
%     x     13-state [v_b; w_b; q (N->B, scalar first); p_n] (CONVENTIONS 3)
%     u     controls: a vector ordered as controlNames, or a struct by name
%     env   struct g, wind_n, deltaT (as vital.plant.derivatives)
%     ref   struct with b and cbar (m) for the non-dimensional rates
%   fl = vital.FlightContext(x, u, env, controlNames, ref, kin)
%     the same constructor for a plant that computes its OWN kinematics (the
%     rotating-Earth plant vital.plant.derivativesRotating): kin is a struct with
%     C_bn, H, Atm, Air and StateLayout; x is then that plant's state (layout
%     kin.StateLayout, e.g. 'rotating13') and env its env.
%   This constructor is the ONLY way to fill a context (ADR-043, increment I1):
%   model.derivatives, vital.plant.derivatives with a model or with a toRuntime
%   struct, and derivativesRotating all build it here, so a component sees the
%   same X, U, C_bn, H, Atm, Air and Env on every path (I0 finding F-3: the old
%   runtime bridge fromAirData left X, C_bn and Env empty; it is retired).
%   Properties: X, U (struct by name), UVector, ControlNames, C_bn (NED -> body),
%     H (geometric height, m), Atm (vital.env.atmosphere), Air
%     (vital.airdata.airData: V, alpha, beta, qbar, mach, w_air, ...), Env,
%     StateLayout ('flat13' for the flat-Earth state; else the plant's).
%   v = fl.control(name)   one control by name (unknown: vital:model:unknownControl)
%   u = vital.FlightContext.controlVector(s, names)   a control struct by name ->
%       the vector in the order of names (missing or unknown name:
%       vital:model:unknownControl)
%   Errors: vital:badInput (state not 13 long, non-finite, zero quaternion, or a
%   control vector whose width is not numel(controlNames); the message names the
%   channels).
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
        StateLayout
    end

    methods
        function obj = FlightContext(x, u, env, controlNames, ref, kin)
            if nargin == 0, return; end
            if isstruct(u), u = vital.FlightContext.controlVector(u, controlNames); end
            vital.validate.finite(x, 'state');
            vital.validate.finite(u, 'controls');
            if numel(x) ~= 13
                error('vital:badInput', 'state must have 13 elements, got %d.', numel(x));
            end
            if numel(u) ~= numel(controlNames)
                error('vital:badInput', 'controls must be [%s] (%d channels), got %d elements.', ...
                    strjoin(cellstr(controlNames), ' '), numel(controlNames), numel(u));
            end
            x = x(:); u = u(:);
            if nargin < 6
                q = x(7:10);
                nq = norm(q);
                if nq == 0, error('vital:badInput', 'zero quaternion in the state.'); end
                C = vital.frames.quat2dcm(q / nq);
                h = -x(13);
                atm = vital.env.atmosphere(h, 'DeltaT', env.deltaT);
                obj.Air = vital.airdata.airData(x(1:3), x(4:6), C, env.wind_n, atm, ref);
                obj.StateLayout = 'flat13';
            else
                C = kin.C_bn; h = kin.H; atm = kin.Atm;
                obj.Air = kin.Air;
                obj.StateLayout = kin.StateLayout;
            end
            obj.X = x;
            obj.UVector = u;
            if isempty(u)
                obj.U = cell2struct(cell(0, 1), cell(0, 1), 1);
            else
                U = struct();
                for k = 1:numel(u), U.(controlNames{k}) = u(k); end
                obj.U = U;
            end
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
        function u = controlVector(s, names)
            names = cellstr(names);
            u = zeros(numel(names), 1);
            for k = 1:numel(names)
                if ~isfield(s, names{k})
                    error('vital:model:unknownControl', 'control "%s" missing from the control struct (channels: %s).', ...
                        names{k}, strjoin(names, ', '));
                end
                u(k) = s.(names{k});
            end
            extra = setdiff(fieldnames(s), names);
            if ~isempty(extra)
                error('vital:model:unknownControl', 'unknown control(s): %s (channels: %s).', strjoin(extra, ', '), strjoin(names, ', '));
            end
        end
    end
end
