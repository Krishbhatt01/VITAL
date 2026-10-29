classdef ControlData < vital.data.DaveModel
%CONTROLDATA  A control law (gains, limits, schedules): one DAVE-ML file as objects
%   (value class; D1, docs/PLAN_DATA_LAYER.md, ADR-042). For the F-16: the NASA
%   NESC stability-augmentation law F16_control.dml (role 'control') and the
%   guidance law F16_gnc.dml (role 'gnc').
%   Everything of vital.data.DaveModel:
%     k = c.parameter('longLQR11')   a gain with units and source
%     out = c.evaluate(in)           the law (= vital.models.f16.control / gnc)

    methods
        function obj = ControlData(parts)
            if nargin == 0, parts = []; end
            obj@vital.data.DaveModel(parts);
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = vital.data.ControlData(vital.data.DaveModel.partsFromStruct(s));
        end
    end
end
