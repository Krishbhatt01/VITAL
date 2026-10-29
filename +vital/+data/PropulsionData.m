classdef PropulsionData < vital.data.DaveModel
%PROPULSIONDATA  A propulsion model: one DAVE-ML propulsion file as objects
%   (value class; D1, docs/PLAN_DATA_LAYER.md, ADR-042).
%   Everything of vital.data.DaveModel, plus
%     engineAxis   name of the axis the thrust acts along (+x) and about
%     outputMap    struct array (role, varID): FX FY FZ L M N -> the variables
%                  (F-16: FEX FEY FEZ TEL TEM TEN, F16_prop.dml), and
%                  'powerLevel' -> the power-lever input (PWR)
%   out = p.thrust(in)       the model evaluated at in (= evaluate)
%   t = p.table('T_MIL')     a thrust table by name
%   (Later aircraft add torque, h_rot and propeller data here.)

    properties (SetAccess = private)
        engineAxis (1,:) char = 'engine'
        outputMap struct = struct('role', {}, 'varID', {})
    end

    methods
        function obj = PropulsionData(parts, engineAxis, outputMap)
            if nargin == 0, parts = []; end
            obj@vital.data.DaveModel(parts);
            if isempty(parts), return; end
            obj.engineAxis = char(engineAxis);
            om = struct('role', {}, 'varID', {});
            for c = vital.data.internal.asList(outputMap)
                om(end+1) = struct('role', char(c{1}.role), 'varID', char(c{1}.varID)); %#ok<AGROW>
            end
            obj.outputMap = reshape(om, 1, []);
        end

        function out = thrust(obj, in)
            out = obj.evaluate(in);
        end

        function validate(obj, where)
            if nargin < 2, where = obj.where(); end
            validate@vital.data.DaveModel(obj, where);
            for c = obj.outputMap
                obj.variable(c.varID);
            end
        end
    end

    methods (Access = protected)
        function s = extraStruct(obj, s)
            s.engineAxis = obj.engineAxis;
            s.outputMap = obj.outputMap;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = vital.data.PropulsionData(vital.data.DaveModel.partsFromStruct(s), ...
                vital.data.internal.field(s, 'engineAxis', 'engine'), vital.data.internal.field(s, 'outputMap', []));
        end
    end
end
