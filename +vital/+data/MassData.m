classdef MassData < vital.data.DaveModel
%MASSDATA  Mass, inertia and CG: one DAVE-ML inertia file as objects (value class;
%   D1, docs/PLAN_DATA_LAYER.md, ADR-042).
%   Everything of vital.data.DaveModel, plus
%     inputs   struct: the inputs the mass model is evaluated at (F-16:
%              CG_PCT_MAC = 25, the NESC test CG; F16_inertia.dml's own default is 35)
%   The quantities are found by their ANSI/AIAA S-119 standard NAMES (the variableDef
%   name attribute), so any DAVE-ML inertia file works:
%     totalMass, bodyMomentOfInertia_Roll/_Pitch/_Yaw,
%     bodyProductOfInertia_XY/_ZX/_YZ (positive integrals, CONVENTIONS 6),
%     bodyPositionOfCmWrtMrc_X/_Y/_Z (body axes, x forward, z down, from the MRC)
%   m    = md.massSI()          kg            (value * vital.data.unitFactor)
%   J    = md.inertiaSI()       kg m^2, vital.mass.inertiaTensor(Ixx, Iyy, Izz,
%                               Ixy, Izx, Iyz) * factor, exactly as
%                               vital.aircraft.f16.config computes it
%   r    = md.cgSI()            m, CG from the MRC in body axes
%   p    = md.evaluated(name)   a Parameter holding the value AT md.inputs (a
%                               calculated variable such as DXCG has no fixed
%                               value), source = its variableDef + the inputs
%   mp   = md.massProperties(axis_cg)   vital.MassProperties(m, axis_cg,
%                               InertiaTensor(J, axis_cg))

    properties (SetAccess = private)
        inputs struct = struct()
    end

    properties (Constant, Hidden)
        STD = struct('mass', 'totalMass', 'Ixx', 'bodyMomentOfInertia_Roll', 'Iyy', 'bodyMomentOfInertia_Pitch', ...
            'Izz', 'bodyMomentOfInertia_Yaw', 'Ixy', 'bodyProductOfInertia_XY', 'Izx', 'bodyProductOfInertia_ZX', ...
            'Iyz', 'bodyProductOfInertia_YZ', 'x', 'bodyPositionOfCmWrtMrc_X', 'y', 'bodyPositionOfCmWrtMrc_Y', ...
            'z', 'bodyPositionOfCmWrtMrc_Z')
    end

    methods
        function obj = MassData(parts, inputs)
            if nargin == 0, parts = []; end
            obj@vital.data.DaveModel(parts);
            if isempty(parts), return; end
            if nargin < 2 || isempty(inputs), inputs = struct(); end
            in = struct();
            for f = fieldnames(inputs).'
                in.(f{1}) = vital.data.internal.num(inputs.(f{1}));
            end
            obj.inputs = in;
        end

        function m = massSI(obj)
            [v, f] = obj.std('mass');
            m = v * f;
        end

        function J = inertiaSI(obj)
            [Ixx, f] = obj.std('Ixx');
            [Iyy, f2] = obj.std('Iyy'); [Izz, f3] = obj.std('Izz');
            [Ixy, f4] = obj.std('Ixy'); [Izx, f5] = obj.std('Izx'); [Iyz, f6] = obj.std('Iyz');
            if ~isequal(f, f2, f3, f4, f5, f6)
                error('vital:data:badFormat', '%sthe inertia components must share their units.', obj.where());
            end
            J = vital.mass.inertiaTensor(Ixx, Iyy, Izz, Ixy, Izx, Iyz) * f;
        end

        function r = cgSI(obj)
            [x, f] = obj.std('x'); [y, f2] = obj.std('y'); [z, f3] = obj.std('z');
            if ~isequal(f, f2, f3)
                error('vital:data:badFormat', '%sthe CG components must share their units.', obj.where());
            end
            r = [x; y; z] * f;
        end

        function p = evaluated(obj, name)
            v = obj.variable(name);
            out = obj.evaluate(obj.inputs);
            note = '';
            if strcmp(v.kind, 'calc')
                note = ['evaluated at ' strjoin(cellfun(@(f) sprintf('%s = %g', f, obj.inputs.(f)), ...
                    fieldnames(obj.inputs).', 'UniformOutput', false), ', ')];
            end
            s = v.source;
            p = vital.data.Parameter(v.varID, out.(v.varID), v.units, ...
                vital.data.Source(s.file, s.line, s.sha256, s.varID, s.element, note), 'Description', v.name);
        end

        function mp = massProperties(obj, cgAxis)
            J = obj.inertiaSI();
            mp = vital.MassProperties(obj.massSI(), cgAxis, vital.InertiaTensor(J, cgAxis));
        end
    end

    methods (Access = protected)
        function s = extraStruct(obj, s)
            s.inputs = obj.inputs;
        end
    end

    methods (Access = private)
        function [v, f] = std(obj, key)
            nm = vital.data.MassData.STD.(key);
            k = find(strcmp({obj.variables.name}, nm), 1);
            if isempty(k)
                error('vital:data:unknownName', '%sno variable named %s (ANSI/AIAA S-119).', obj.where(), nm);
            end
            out = obj.evaluate(obj.inputs);
            v = out.(obj.variables(k).varID);
            f = vital.data.unitFactor(obj.variables(k).units);
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = vital.data.MassData(vital.data.DaveModel.partsFromStruct(s), vital.data.internal.field(s, 'inputs', struct()));
        end
    end
end
