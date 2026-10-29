classdef Variable < vital.data.Parameter
%VARIABLE  One DAVE-ML variableDef: a Parameter (value = initialValue, units,
%   source) plus its role in the build-up (value class; D1, ADR-042).
%   v = vital.data.Variable(varID, name, units, source, 'Kind', k, 'Value', v0, ...
%         'MinValue', lo, 'MaxValue', hi, 'IsInput', tf, 'IsOutput', tf, ...
%         'Expression', expr, 'Deps', {..}, 'Description', text)
%     varID       the DAVE-ML varID (unique in its file); name = the variableDef name
%     kind        'input'    an input (value = its default initialValue, NaN if none)
%                 'constant' a constant (value = initialValue)
%                 'calc'     a MathML calculation, compiled by vital.daveml.read into
%                            the MATLAB expression 'expression' over v_<varID> names
%                 'table'    the output of a gridded table (vital.data.Table)
%     minValue / maxValue    saturations applied after the variable is computed
%                 (ADR-014), -Inf / Inf when the file gives none
%     deps        varIDs the expression or the table uses
%   Every Variable is a Parameter, so it has units, a source, si(), validate().

    properties (SetAccess = protected)
        varID (1,:) char = ''
        kind (1,:) char = 'constant'
        minValue (1,1) double = -Inf
        maxValue (1,1) double = Inf
        isInput (1,1) logical = false
        isOutput (1,1) logical = false
        expression (1,:) char = ''
        deps cell = cell(1, 0)
    end

    methods
        function obj = Variable(varID, name, units, source, opts)
            arguments
                varID (1,:) char
                name (1,:) char
                units (1,:) char
                source
                opts.Kind (1,:) char = 'constant'
                opts.Value double = NaN
                opts.MinValue (1,1) double = -Inf
                opts.MaxValue (1,1) double = Inf
                opts.IsInput (1,1) logical = false
                opts.IsOutput (1,1) logical = false
                opts.Expression (1,:) char = ''
                opts.Deps = cell(1, 0)
                opts.Description (1,:) char = ''
            end
            obj@vital.data.Parameter(name, opts.Value, units, source, 'Description', opts.Description);
            if ~any(strcmp(opts.Kind, {'input', 'constant', 'calc', 'table'}))
                error('vital:data:badFormat', 'variable "%s": kind "%s" is not input, constant, calc or table.', varID, opts.Kind);
            end
            obj.varID = varID;
            obj.kind = opts.Kind;
            obj.minValue = opts.MinValue;
            obj.maxValue = opts.MaxValue;
            obj.isInput = opts.IsInput;
            obj.isOutput = opts.IsOutput;
            obj.expression = opts.Expression;
            obj.deps = vital.data.internal.asCellstr(opts.Deps);
        end

        function s = toStruct(obj)
            s = toStruct@vital.data.Parameter(obj);
            s.varID = obj.varID;
            s.kind = obj.kind;
            s.minValue = obj.minValue;
            s.maxValue = obj.maxValue;
            s.isInput = obj.isInput;
            s.isOutput = obj.isOutput;
            s.expression = obj.expression;
            s.deps = obj.deps;
        end
    end

    methods (Static)
        function v = fromStruct(s)
            g = @(f, d) vital.data.internal.field(s, f, d);
            num = @vital.data.internal.num;
            expr = char(g('expression', ''));
            kind = char(g('kind', ''));
            if isempty(kind)
                if ~isempty(expr), kind = 'calc';
                elseif logical(g('isInput', false)), kind = 'input';
                else, kind = 'constant';
                end
            end
            v = vital.data.Variable(char(s.varID), char(g('name', '')), char(g('units', '')), g('source', []), ...
                'Kind', kind, 'Value', num(g('value', NaN)), 'MinValue', num(g('minValue', -Inf)), ...
                'MaxValue', num(g('maxValue', Inf)), 'IsInput', logical(g('isInput', strcmp(kind, 'input'))), ...
                'IsOutput', logical(g('isOutput', false)), 'Expression', expr, 'Deps', g('deps', cell(1, 0)), ...
                'Description', char(g('description', '')));
        end
    end
end
