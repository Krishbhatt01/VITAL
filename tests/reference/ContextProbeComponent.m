classdef ContextProbeComponent < vital.Component
%CONTEXTPROBECOMPONENT  TEST-ONLY component (tests/reference, never in +vital;
%   increment I1): ZERO loads, and it records the vital.FlightContext it is given
%   into a ContextSink, so a test can compare the context a component receives
%   on every path (model.derivatives, vital.plant.derivatives with the model or
%   its toRuntime struct, derivativesRotating) with the direct constructor's.
%   c = ContextProbeComponent(name, axis, sink)

    properties (SetAccess = protected)
        Sink
    end

    methods
        function obj = ContextProbeComponent(name, axis, sink)
            obj = obj.initComponent(name, axis, {}, []);
            obj.Sink = sink;
        end
    end

    methods (Hidden)
        function [F, M, info] = computeLoads(obj, fl)
            obj.Sink.record(fl);
            F = zeros(3, 1); M = zeros(3, 1);
            info = struct('outOfEnvelope', false);
        end
    end
end
