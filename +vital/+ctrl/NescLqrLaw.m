classdef NescLqrLaw < vital.ctrl.ControlLaw
%NESCLQRLAW  vital.ctrl.nescLqr (NASA's NESC F-16 LQR SAS) as an object (0.8.1-OOP, ADR-037).
%   law = vital.ctrl.NescLqrLaw('Rate', 50)
    properties (SetAccess = private)
        Rate (1,1) double
    end
    methods
        function obj = NescLqrLaw(opts)
            arguments
                opts.Rate (1,1) double = 50
            end
            obj.Name = 'nescLqr'; obj.Rate = opts.Rate;
        end
        function c = buildStruct(obj, AC, env, tr)
            c = vital.ctrl.nescLqr(AC, env, tr, 'Rate', obj.Rate);
        end
    end
end
