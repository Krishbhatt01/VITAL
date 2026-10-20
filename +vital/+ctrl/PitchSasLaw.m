classdef PitchSasLaw < vital.ctrl.ControlLaw
%PITCHSASLAW  vital.ctrl.pitchSas as an object (0.8.1-OOP, ADR-037).
%   law = vital.ctrl.PitchSasLaw('Kq', 0.2, 'Ka', 0.5, 'Rate', 100)
%   de = de_ref + Kq (q - q0) + Ka (alpha - alpha0); see vital.ctrl.pitchSas.
    properties (SetAccess = private)
        Kq (1,1) double
        Ka (1,1) double
        Rate (1,1) double
    end
    methods
        function obj = PitchSasLaw(opts)
            arguments
                opts.Kq (1,1) double = 0
                opts.Ka (1,1) double = 0
                opts.Rate (1,1) double = 100
            end
            obj.Name = 'pitchSas'; obj.Kq = opts.Kq; obj.Ka = opts.Ka; obj.Rate = opts.Rate;
        end
        function c = buildStruct(obj, AC, env, tr)
            c = vital.ctrl.pitchSas(AC, env, tr, 'Kq', obj.Kq, 'Ka', obj.Ka, 'Rate', obj.Rate);
        end
    end
end
