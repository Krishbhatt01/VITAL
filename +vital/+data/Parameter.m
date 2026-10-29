classdef Parameter
%PARAMETER  A number (scalar or array) with its units and its source (value class;
%   D1, docs/PLAN_DATA_LAYER.md, ADR-042).
%   p = vital.data.Parameter(name, value, units, source, 'Description', text)
%     value    double array in the units of the SOURCE (e.g. 300 for 'ft2'); the data
%              object keeps the published number, SI comes from si()
%     units    DAVE-ML units string (vital.data.unitFactor), e.g. 'ft2', 'slugft2', 'nd'
%     source   vital.data.Source (file, line, SHA-256, varID)
%   v = p.si()            value * factor in SI (bitwise the hand-written conversion)
%   u = p.siUnits()
%   p.validate()          vital:data:noUnits (empty units),
%                         vital:data:noProvenance (no or an invalid source)
%   q = p.withSource(s), q = p.withUnits(u)    edited copies
%   s = p.toStruct(), p = vital.data.Parameter.fromStruct(s)
%   disp(p): name = value units (SI value) [file:line varID, sha256]

    properties (SetAccess = protected)
        name (1,:) char = ''
        value double = []
        units (1,:) char = ''
        description (1,:) char = ''
        source = vital.data.Source.empty
    end

    methods
        function obj = Parameter(name, value, units, source, opts)
            arguments
                name (1,:) char
                value double
                units (1,:) char
                source
                opts.Description (1,:) char = ''
            end
            obj.name = name;
            obj.value = value;
            obj.units = units;
            obj.source = vital.data.Source.fromStruct(source);
            obj.description = opts.Description;
        end

        function v = si(obj)
            f = vital.data.unitFactor(obj.units);
            if f == 1
                v = obj.value;
            else
                v = obj.value * f;
            end
        end

        function u = siUnits(obj)
            [~, u] = vital.data.unitFactor(obj.units);
        end

        function validate(obj, where)
            if nargin < 2, where = ''; end
            for k = 1:numel(obj)
                p = obj(k);
                if isempty(p.units)
                    error('vital:data:noUnits', '%s%s ''%s'' has no units.', where, class(p), p.name);
                end
                if isempty(p.source) || ~p.source.isValid()
                    error('vital:data:noProvenance', '%s%s ''%s'' has no valid source (file, line, SHA-256).', ...
                        where, class(p), p.name);
                end
            end
        end

        function p = withSource(obj, source)
            p = obj;
            p.source = vital.data.Source.fromStruct(source);
        end

        function p = withUnits(obj, units)
            p = obj;
            p.units = units;
        end

        function s = toStruct(obj)
            s = struct('name', obj.name, 'value', obj.value, 'units', obj.units, 'description', obj.description, ...
                'source', srcStruct(obj.source));
        end

        function disp(obj)
            for k = 1:numel(obj)
                p = obj(k);
                fprintf('  %s = %s %s', p.name, valueText(p.value), p.units);
                try
                    [f, u] = vital.data.unitFactor(p.units);
                    if f ~= 1 || ~strcmp(u, p.units), fprintf(' (%s %s)', valueText(p.si()), u); end
                catch
                end
                if isempty(p.source), fprintf('  [no source]\n'); else, fprintf('  [%s]\n', char(p.source)); end
            end
        end
    end

    methods (Static)
        function p = fromStruct(s)
            g = @(f, d) vital.data.internal.field(s, f, d);
            p = vital.data.Parameter(char(g('name', '')), vital.data.internal.num(g('value', [])), char(g('units', '')), ...
                g('source', []), 'Description', char(g('description', '')));
        end
    end
end

function s = srcStruct(src)
if isempty(src), s = []; else, s = src.toStruct(); end
end

function t = valueText(v)
if isscalar(v)
    t = sprintf('%.6g', v);
elseif numel(v) <= 6
    t = mat2str(v, 6);
else
    t = sprintf('[%s double]', strjoin(arrayfun(@num2str, size(v), 'UniformOutput', false), 'x'));
end
end
