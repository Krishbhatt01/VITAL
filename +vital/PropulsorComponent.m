classdef PropulsorComponent < vital.Component
%PROPULSORCOMPONENT  An engine, propeller or motor: thrust along its axis' +x and
%   an optional torque about +x (value class).
%   c = vital.PropulsorComponent(name, axis, thrustFcn, channel)
%     thrustFcn  [T, Q, info] = thrustFcn(flight, throttle): thrust T (N) along the
%                component axis' +x, torque Q (N m) about +x, info.outOfEnvelope
%     channel    the ONE control channel the component reads (e.g. 'throttle_le')
%   Loads in the component axis: F = [T; 0; 0], M = [Q; 0; 0]. The thrust line
%   passes through the axis origin (place the axis on the thrust line). A failed
%   engine is c.withEnabled(false), or zero thrust: no special code.

    properties (SetAccess = protected)
        ThrustFcn
    end

    methods
        function obj = PropulsorComponent(name, axis, thrustFcn, channel, opts)
            arguments
                name
                axis
                thrustFcn
                channel
                opts.MassProps = []
            end
            if ~isa(thrustFcn, 'function_handle')
                error('vital:badInput', 'thrustFcn must be a function handle.');
            end
            if ~(ischar(channel) || (isstring(channel) && isscalar(channel)))
                error('vital:badInput', 'a propulsor reads exactly one control channel.');
            end
            obj = obj.initComponent(name, axis, {char(channel)}, opts.MassProps);
            obj.Kind = 'propulsion';
            obj.ThrustFcn = thrustFcn;
        end
    end

    methods (Hidden)
        function [F, M, info] = computeLoads(obj, flight)
            th = flight.U.(obj.Channels{1});
            [T, Q, info] = obj.ThrustFcn(flight, th);
            F = [T; 0; 0];
            M = [Q; 0; 0];
            info.thrust = T;
        end
    end
end
