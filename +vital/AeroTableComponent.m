classdef AeroTableComponent < vital.Component
%AEROTABLECOMPONENT  An aerodynamic coefficient database about its reference point
%   (MRC) axis (value class).
%   c = vital.AeroTableComponent(name, axis_mrc, coeffFcn, 'S', S, 'b', b, 'cbar', cbar)
%   c = vital.AeroTableComponent(..., 'Channels', {'de', 'da', 'dr'}, 'CoeffArgs', {AC})
%     coeffFcn  [coeff, info] = coeffFcn(flight, CoeffArgs{:}): coeff = [CX CY CZ Cl Cm Cn], the
%               body-axis coefficients in the component axis about its origin (the
%               MRC); info.outOfEnvelope. For the F-16 it wraps the generated NASA
%               DAVE-ML model (vital.aircraft.f16.aeroCoefficients).
%   Loads in the component axis:
%     F = qbar S [CX; CY; CZ],   M = qbar S [b Cl; cbar Cm; b Cn]
%   (the arithmetic of vital.aircraft.f16.loads, in the same order).

    properties (SetAccess = protected)
        CoeffFcn
        CoeffArgs cell = {}   % extra arguments: coeffFcn(flight, CoeffArgs{:})
        S (1,1) double = 1
        b (1,1) double = 1
        cbar (1,1) double = 1
    end

    methods
        function obj = AeroTableComponent(name, axis, coeffFcn, opts)
            arguments
                name
                axis
                coeffFcn
                opts.S (1,1) double {mustBePositive} = 1
                opts.b (1,1) double {mustBePositive} = 1
                opts.cbar (1,1) double {mustBePositive} = 1
                opts.Channels = {'de', 'da', 'dr'}
                opts.CoeffArgs cell = {}
                opts.MassProps = []
            end
            if ~isa(coeffFcn, 'function_handle')
                error('vital:badInput', 'coeffFcn must be a function handle.');
            end
            obj = obj.initComponent(name, axis, opts.Channels, opts.MassProps);
            obj.CoeffFcn = coeffFcn;
            obj.CoeffArgs = opts.CoeffArgs;
            obj.S = opts.S; obj.b = opts.b; obj.cbar = opts.cbar;
        end
    end

    methods (Hidden)
        function [F, M, info] = computeLoads(obj, flight)
            [c, info] = obj.CoeffFcn(flight, obj.CoeffArgs{:});
            qS = flight.Air.qbar * obj.S;
            F = qS * [c(1); c(2); c(3)];
            M = qS * [obj.b * c(4); obj.cbar * c(5); obj.b * c(6)];
            info.coeff = c;
        end
    end
end
