classdef Breakpoint
%BREAKPOINT  A breakpoint vector of a gridded table (value class; D1, ADR-042).
%   b = vital.data.Breakpoint(name, bpID, units, values, source, 'Description', text)
%     name    the INPUT variable it indexes (the independentVarRef varID, e.g.
%             'alpha', 'el'); for a file's breakpointDef list it is the
%             breakpointDef name attribute
%     bpID    the DAVE-ML breakpointDef id (e.g. 'ALPHA1', 'DE1')
%     units   units of the values (e.g. 'deg');  values  strictly increasing row
%     source  vital.data.Source of the breakpointDef
%   b.validate(): vital:data:noUnits, vital:data:noProvenance,
%   vital:data:badFormat (values not a strictly increasing row).

    properties (SetAccess = private)
        name (1,:) char = ''
        bpID (1,:) char = ''
        units (1,:) char = ''
        values (1,:) double = zeros(1, 0)
        description (1,:) char = ''
        source = vital.data.Source.empty
    end

    methods
        function obj = Breakpoint(name, bpID, units, values, source, opts)
            arguments
                name (1,:) char
                bpID (1,:) char
                units (1,:) char
                values
                source
                opts.Description (1,:) char = ''
            end
            obj.name = name;
            obj.bpID = bpID;
            obj.units = units;
            obj.values = reshape(values, 1, []);
            obj.source = vital.data.Source.fromStruct(source);
            obj.description = opts.Description;
        end

        function b = withName(obj, name)
            b = obj;
            b.name = name;
        end

        function validate(obj, where)
            if nargin < 2, where = ''; end
            for k = 1:numel(obj)
                b = obj(k);
                if isempty(b.units)
                    error('vital:data:noUnits', '%sbreakpoints ''%s'' have no units.', where, b.bpID);
                end
                if isempty(b.source) || ~b.source.isValid()
                    error('vital:data:noProvenance', '%sbreakpoints ''%s'' have no valid source.', where, b.bpID);
                end
                if isempty(b.values) || any(diff(b.values) <= 0) || any(~isfinite(b.values))
                    error('vital:data:badFormat', '%sbreakpoints ''%s'' must be finite and strictly increasing.', where, b.bpID);
                end
            end
        end

        function s = toStruct(obj)
            if isempty(obj.source), src = []; else, src = obj.source.toStruct(); end
            s = struct('bpID', obj.bpID, 'name', obj.name, 'units', obj.units, 'values', obj.values, ...
                'description', obj.description, 'source', src);
        end

        function disp(obj)
            for k = 1:numel(obj)
                b = obj(k);
                fprintf('  %s (%s) [%s]: %d values %s .. %s\n', b.name, b.bpID, b.units, numel(b.values), ...
                    num2str(b.values(1)), num2str(b.values(end)));
            end
        end
    end

    methods (Static)
        function b = fromStruct(s)
            g = @(f, d) vital.data.internal.field(s, f, d);
            b = vital.data.Breakpoint(char(g('name', '')), char(s.bpID), char(g('units', '')), ...
                vital.data.internal.num(g('values', zeros(1, 0))), g('source', []), 'Description', char(g('description', '')));
        end
    end
end
