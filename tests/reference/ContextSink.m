classdef ContextSink < handle
%CONTEXTSINK  TEST-ONLY recorder (increment I1): the vital.FlightContext objects a
%   ContextProbeComponent was given, in call order. A handle, so the value-class
%   component (and every copy of the model holding it) records into ONE sink.
%   s = ContextSink();  s.clear();  s.Contexts{k}

    properties
        Contexts cell = {}
    end

    methods
        function record(obj, fl)
            obj.Contexts{end+1} = fl;
        end

        function clear(obj)
            obj.Contexts = {};
        end
    end
end
