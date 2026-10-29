classdef AeroDatabase < vital.data.DaveModel
%AERODATABASE  An aerodynamic database: one DAVE-ML aero file as objects
%   (value class; D1, docs/PLAN_DATA_LAYER.md, ADR-042).
%   Everything of vital.data.DaveModel (variables, breakpoints, tables, checkCases,
%   variable/table/equation/list/evaluate/runChecks), plus
%     reference       struct of vital.data.Parameter: S, b, cbar (the reference
%                     geometry, each with units and source)
%     mrcAxis         name of the axis the moments are about (the moment reference
%                     centre), e.g. 'mrc'
%     coefficientMap  struct array (role, varID, axes): which variable is which
%                     coefficient and in which axes the data are given, e.g.
%                     F-16: CX..Cn -> cx..cn, 'body'; brick: CD -> CD, 'wind'
%   c = a.coefficients(in)   the build-up evaluated at in (= evaluate)
%   [c, v] = a.coefficients(in)   v: the coefficientMap values in its order

    properties (SetAccess = private)
        reference struct = struct()
        mrcAxis (1,:) char = 'mrc'
        coefficientMap struct = struct('role', {}, 'varID', {}, 'axes', {})
    end

    methods
        function obj = AeroDatabase(parts, reference, mrcAxis, coefficientMap)
            if nargin == 0, parts = []; end
            obj@vital.data.DaveModel(parts);
            if isempty(parts), return; end
            obj.reference = reference;
            obj.mrcAxis = char(mrcAxis);
            cm = struct('role', {}, 'varID', {}, 'axes', {});
            for c = vital.data.internal.asList(coefficientMap)
                cm(end+1) = struct('role', char(c{1}.role), 'varID', char(c{1}.varID), 'axes', char(c{1}.axes)); %#ok<AGROW>
            end
            obj.coefficientMap = reshape(cm, 1, []);
        end

        function [c, v] = coefficients(obj, in)
            c = obj.evaluate(in);
            if nargout > 1
                v = cellfun(@(id) c.(id), {obj.coefficientMap.varID});
            end
        end

        function validate(obj, where)
            if nargin < 2, where = obj.where(); end
            validate@vital.data.DaveModel(obj, where);
            for f = {'S', 'b', 'cbar'}
                if ~isfield(obj.reference, f{1})
                    error('vital:data:badFormat', '%sreference geometry %s missing.', where, f{1});
                end
                obj.reference.(f{1}).validate(where);
            end
            for c = obj.coefficientMap
                obj.variable(c.varID);
                if ~any(strcmp(c.axes, {'body', 'stability', 'wind'}))
                    error('vital:data:badFormat', '%scoefficient %s: axes "%s" is not body, stability or wind (CONVENTIONS 8).', ...
                        where, c.role, c.axes);
                end
            end
        end
    end

    methods (Access = protected)
        function s = extraStruct(obj, s)
            for f = fieldnames(obj.reference).'
                s.reference.(f{1}) = obj.reference.(f{1}).toStruct();
            end
            s.mrcAxis = obj.mrcAxis;
            s.coefficientMap = obj.coefficientMap;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            parts = vital.data.DaveModel.partsFromStruct(s);
            ref = struct();
            r = vital.data.internal.field(s, 'reference', struct());
            for f = fieldnames(r).'
                ref.(f{1}) = vital.data.Parameter.fromStruct(r.(f{1}));
            end
            obj = vital.data.AeroDatabase(parts, ref, vital.data.internal.field(s, 'mrcAxis', 'mrc'), ...
                vital.data.internal.field(s, 'coefficientMap', []));
        end
    end
end
