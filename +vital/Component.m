classdef (Abstract) Component
%COMPONENT  One source of loads on an aircraft (abstract value class;
%   PLAN_CORE_FRAMES 2.9): an aero database, an engine, a propeller, a motor,
%   later landing gear.
%   Every component implements ONE interface:
%     L = c.loads(flight)          vital.Loads in the component's OWN axis (about its
%                                  origin, in its components); zero when disabled
%     [F, M, info] = c.loadsNumeric(flight)   the same numbers (3x1, 3x1) without
%                                  objects, for the compiled path of AircraftModel;
%                                  info.outOfEnvelope (logical) at least
%   flight is a vital.FlightContext (computed once per evaluation). A component
%   reads only its own control channels (Channels) by name, so multi-engine and
%   engine-out need no special code: a failed engine is c.withEnabled(false).
%   Properties: Name, Axis (vital.Axis), Enabled, Channels (cellstr), MassProps
%   (vital.MassProperties or [], not yet used by the model's mass: see ADR-040),
%   Kind: what the loads ARE, for the model's diagnostics (ADR-043, I1 finding
%   F-7): 'aero' (summed into y.F_aero, y.M_aero), 'propulsion' (y.F_prop,
%   y.M_prop), 'other' (in neither sum, e.g. landing gear) or 'unclassified'
%   (the default for a new subclass: the sums are then NaN, never a silent 0).
%   AeroTableComponent is 'aero', PropulsorComponent 'propulsion';
%   c = c.withKind(kind) re-declares it (unknown kind: vital:badInput).
%   Subclasses implement computeLoads(c, flight) (Hidden: the loads of an ENABLED
%   component; AircraftModel's compiled path calls it directly for the components
%   that were enabled at compile time).

    properties (SetAccess = protected)
        Name (1,:) char = 'component'
        Axis
        Enabled (1,1) logical = true
        Channels cell = {}
        MassProps = []
        Kind (1,:) char = 'unclassified'
    end

    properties (Constant)
        KINDS = {'aero', 'propulsion', 'other', 'unclassified'}
    end

    methods (Abstract, Hidden)
        [F, M, info] = computeLoads(obj, flight)
    end

    methods
        function L = loads(obj, flight)
            [F, M] = obj.loadsNumeric(flight);
            L = vital.Loads(F, M, obj.Axis);
        end

        function [F, M, info] = loadsNumeric(obj, flight)
            if ~obj.Enabled
                F = zeros(3, 1); M = zeros(3, 1); info = struct('outOfEnvelope', false);
                return
            end
            [F, M, info] = obj.computeLoads(flight);
        end

        function c = withEnabled(obj, tf)
            c = obj;
            c.Enabled = logical(tf);
        end

        function c = withKind(obj, kind)
            %WITHKIND  The same component with its load kind re-declared (ADR-043).
            c = obj;
            c.Kind = vital.Component.checkKind(kind);
        end

        function c = withAxis(obj, axis)
            if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                error('vital:badInput', 'component axis must be a single vital.Axis.');
            end
            c = obj;
            c.Axis = axis;
        end

        function s = toStruct(obj)
            s = struct('name', obj.Name, 'class', class(obj), 'axis', obj.Axis.Name, 'enabled', obj.Enabled, ...
                'channels', {obj.Channels}, 'kind', obj.Kind);
        end
    end

    methods (Static, Hidden)
        function kind = checkKind(kind)
            if ~(ischar(kind) || (isstring(kind) && isscalar(kind))) || ~any(strcmp(char(kind), vital.Component.KINDS))
                error('vital:badInput', 'component kind must be one of %s.', strjoin(vital.Component.KINDS, ', '));
            end
            kind = char(kind);
        end
    end

    methods (Access = protected)
        function obj = initComponent(obj, name, axis, channels, massProps)
            if ~(ischar(name) || (isstring(name) && isscalar(name))) || strlength(name) == 0
                error('vital:badInput', 'component name must be non-empty text.');
            end
            if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                error('vital:badInput', 'component axis must be a single vital.Axis.');
            end
            channels = cellstr(channels);
            if ~isempty(massProps) && ~isa(massProps, 'vital.MassProperties')
                error('vital:badInput', 'component MassProps must be a vital.MassProperties or [].');
            end
            obj.Name = char(name);
            obj.Axis = axis;
            obj.Channels = channels(:).';
            obj.MassProps = massProps;
        end
    end
end
