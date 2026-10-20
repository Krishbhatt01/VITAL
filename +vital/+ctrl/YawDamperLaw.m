classdef YawDamperLaw < vital.ctrl.ControlLaw
%YAWDAMPERLAW  vital.ctrl.yawDamper as an object (0.8.1-OOP, ADR-037).
%   law = vital.ctrl.YawDamperLaw('Kr', 0.5, 'Kari', 0.1, 'Rate', 100)
%   dr = dr_ref + Kr (r - r0) + Kari (da_ref - da_trim); see vital.ctrl.yawDamper.
    properties (SetAccess = private)
        Kr (1,1) double
        Kari (1,1) double
        Rate (1,1) double
    end
    methods
        function obj = YawDamperLaw(opts)
            arguments
                opts.Kr (1,1) double = 0
                opts.Kari (1,1) double = 0
                opts.Rate (1,1) double = 100
            end
            obj.Name = 'yawDamper'; obj.Kr = opts.Kr; obj.Kari = opts.Kari; obj.Rate = opts.Rate;
        end
        function c = buildStruct(obj, AC, env, tr)
            c = vital.ctrl.yawDamper(AC, env, tr, 'Kr', obj.Kr, 'Kari', obj.Kari, 'Rate', obj.Rate);
        end
    end
end
