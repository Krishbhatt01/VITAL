classdef Table
%TABLE  A DAVE-ML gridded table, callable by name (value class; D1, ADR-042).
%   t = vital.data.Table(varID, breakpoints, data, units, source, ...
%         'Name', n, 'Description', d, 'Extrapolate', {..}, 'Lo', lo, 'Hi', hi, ...
%         'FunctionName', f, 'TableName', g)
%     varID        the output variable (e.g. 'cxt'); name = its variableDef name ('CX0')
%     breakpoints  vital.data.Breakpoint array, IN TABLE ORDER; breakpoints(k).name
%                  is the input variable of dimension k (e.g. CXT: 'el', 'alpha')
%     data         N-D array, size(data, k) = numel(breakpoints(k).values) (a 1-D
%                  table is a row); data(i, j, ...) belongs to bp1(i), bp2(j), ...
%     units        units of the output;  source  the <function> element
%     extrapolate  per dimension 'neither' | 'min' | 'max' | 'both' (DAVE-ML);
%     lo, hi       independentVarRef min/max (default the breakpoint range)
%   [y, clamped] = t.at('alpha', 5, 'el', 0)   by input name, in ANY order
%   [y, clamped] = t.at([0 5])                 positional, in table order
%     Multilinear interpolation by vital.daveml.lookup, the function the generated
%     runtime code calls with the same arguments, so the value is BITWISE that of
%     vital.models.<aircraft>.<file> (tests/M9/data/tDataTables.m). A side that
%     does not allow extrapolation is clamped and clamped = true (FC-401).
%     Inputs may be arrays of one size: y has that size (evaluated point by point).
%   [bps, data] = t.grid()          breakpoint vectors (cell, table order) and data
%   G = t.toGriddedInterpolant()    MATLAB griddedInterpolant (linear, nearest
%                                   extrapolation = clamping); the INDEPENDENT check,
%                                   not used by the runtime
%   h = t.plot(ax)                  curves of the table (1-D: y(x); 2-D: one curve
%                                   per value of the first input)
%   t.validate()                    units, provenance, sizes (vital:data:noUnits,
%                                   noProvenance, badFormat)
%   Errors of at(): vital:data:missingInput, vital:data:unknownInput,
%   vital:data:badQuery.

    properties (SetAccess = private)
        varID (1,:) char = ''
        name (1,:) char = ''
        description (1,:) char = ''
        units (1,:) char = ''
        breakpoints = vital.data.Breakpoint.empty
        data double = []
        extrapolate cell = cell(1, 0)
        lo (1,:) double = zeros(1, 0)
        hi (1,:) double = zeros(1, 0)
        functionName (1,:) char = ''
        tableName (1,:) char = ''
        source = vital.data.Source.empty
    end

    properties (SetAccess = private, Hidden)
        bpValues cell = cell(1, 0)     % {breakpoints.values}, kept for speed
        inputNames cell = cell(1, 0)   % {breakpoints.name}
    end

    methods
        function obj = Table(varID, breakpoints, data, units, source, opts)
            arguments
                varID (1,:) char
                breakpoints
                data double
                units (1,:) char
                source
                opts.Name (1,:) char = ''
                opts.Description (1,:) char = ''
                opts.Extrapolate = {}
                opts.Lo double = []
                opts.Hi double = []
                opts.FunctionName (1,:) char = ''
                opts.TableName (1,:) char = ''
            end
            obj.varID = varID;
            obj.breakpoints = reshape(breakpoints, 1, []);
            obj.data = data;
            obj.units = units;
            obj.source = vital.data.Source.fromStruct(source);
            obj.name = opts.Name;
            obj.description = opts.Description;
            d = numel(obj.breakpoints);
            obj.bpValues = arrayfun(@(b) b.values, obj.breakpoints, 'UniformOutput', false);
            obj.inputNames = arrayfun(@(b) b.name, obj.breakpoints, 'UniformOutput', false);
            ex = vital.data.internal.asCellstr(opts.Extrapolate);
            if isempty(ex), ex = repmat({'neither'}, 1, d); end
            obj.extrapolate = ex;
            lo = reshape(opts.Lo, 1, []); hi = reshape(opts.Hi, 1, []);
            if isempty(lo), lo = cellfun(@(v) v(1), obj.bpValues); end
            if isempty(hi), hi = cellfun(@(v) v(end), obj.bpValues); end
            obj.lo = lo; obj.hi = hi;
            obj.functionName = opts.FunctionName;
            obj.tableName = opts.TableName;
            obj.checkShape();
        end

        function [y, clamped] = at(obj, varargin)
            d = numel(obj.breakpoints);
            if numel(varargin) == 1 && isnumeric(varargin{1})
                x = varargin{1};
                if numel(x) ~= d
                    error('vital:data:badQuery', 'table %s has %d inputs (%s); got %d values.', obj.varID, d, ...
                        strjoin(obj.inputNames, ', '), numel(x));
                end
                [y, clamped] = vital.daveml.lookup(obj.bpValues, obj.data, reshape(x, 1, []), obj.extrapolate, obj.lo, obj.hi);
                return
            end
            if mod(numel(varargin), 2) ~= 0
                error('vital:data:badQuery', 'table %s: give name, value pairs (inputs %s) or one vector.', obj.varID, ...
                    strjoin(obj.inputNames, ', '));
            end
            vals = cell(1, d);
            for k = 1:2:numel(varargin)
                nm = char(varargin{k});
                j = find(strcmp(obj.inputNames, nm), 1);
                if isempty(j), j = find(strcmp(arrayfun(@(b) b.bpID, obj.breakpoints, 'UniformOutput', false), nm), 1); end
                if isempty(j)
                    error('vital:data:unknownInput', 'table %s has no input "%s" (inputs: %s).', obj.varID, nm, ...
                        strjoin(obj.inputNames, ', '));
                end
                if ~isempty(vals{j})
                    error('vital:data:badQuery', 'table %s: input "%s" given twice.', obj.varID, nm);
                end
                vals{j} = double(varargin{k + 1});
            end
            miss = obj.inputNames(cellfun(@isempty, vals));
            if ~isempty(miss)
                error('vital:data:missingInput', 'table %s needs input(s) %s.', obj.varID, strjoin(miss, ', '));
            end
            if all(cellfun(@isscalar, vals))
                [y, clamped] = vital.daveml.lookup(obj.bpValues, obj.data, [vals{:}], obj.extrapolate, obj.lo, obj.hi);
                return
            end
            sz = size(vals{1});
            if ~all(cellfun(@(v) isequal(size(v), sz), vals))
                error('vital:data:badQuery', 'table %s: array inputs must all have the same size.', obj.varID);
            end
            y = zeros(sz); clamped = false(sz);
            for i = 1:numel(y)
                [y(i), clamped(i)] = vital.daveml.lookup(obj.bpValues, obj.data, cellfun(@(v) v(i), vals), ...
                    obj.extrapolate, obj.lo, obj.hi);
            end
        end

        function [bps, data] = grid(obj)
            bps = obj.bpValues;
            data = obj.data;
        end

        function G = toGriddedInterpolant(obj)
            if numel(obj.bpValues) == 1
                G = griddedInterpolant(obj.bpValues{1}, obj.data, 'linear', 'nearest');
            else
                G = griddedInterpolant(obj.bpValues, obj.data, 'linear', 'nearest');
            end
        end

        function h = plot(obj, ax)
            if nargin < 2 || isempty(ax), ax = gca; end
            b = obj.breakpoints;
            lab = @(k) sprintf('%s [%s]', b(k).name, b(k).units);
            if numel(b) == 1
                h = plot(ax, b(1).values, obj.data, '-o');
                xlabel(ax, lab(1));
            else
                held = ishold(ax); hold(ax, 'on');
                n = numel(b(1).values);
                h = gobjects(1, n);
                rest = repmat({1}, 1, numel(b) - 2);
                for i = 1:n
                    h(i) = plot(ax, b(2).values, reshape(obj.data(i, :, rest{:}), 1, []), '-o', ...
                        'DisplayName', sprintf('%s = %g', b(1).name, b(1).values(i)));
                end
                if ~held, hold(ax, 'off'); end
                xlabel(ax, lab(2));
                legend(ax, 'show', 'Location', 'best');
            end
            ylabel(ax, sprintf('%s [%s]', obj.varID, obj.units));
            src = '';
            if ~isempty(obj.source), src = char(obj.source); end
            title(ax, {sprintf('%s (%s)', obj.varID, obj.name), src}, 'Interpreter', 'none');
            grid(ax, 'on');
        end

        function t = withSource(obj, source)
            t = obj;
            t.source = vital.data.Source.fromStruct(source);
        end

        function validate(obj, where)
            if nargin < 2, where = ''; end
            for k = 1:numel(obj)
                t = obj(k);
                if isempty(t.units)
                    error('vital:data:noUnits', '%stable ''%s'' has no units.', where, t.varID);
                end
                if isempty(t.source) || ~t.source.isValid()
                    error('vital:data:noProvenance', '%stable ''%s'' has no valid source.', where, t.varID);
                end
                t.breakpoints.validate(sprintf('%stable ''%s'': ', where, t.varID));
                t.checkShape();
            end
        end

        function s = toStruct(obj)
            if isempty(obj.source), src = []; else, src = obj.source.toStruct(); end
            s = struct('varID', obj.varID, 'name', obj.name, 'description', obj.description, 'units', obj.units, ...
                'inputs', {obj.inputNames}, 'bpIDs', {arrayfun(@(b) b.bpID, obj.breakpoints, 'UniformOutput', false)}, ...
                'data', obj.data, 'extrapolate', {obj.extrapolate}, 'lo', obj.lo, 'hi', obj.hi, ...
                'functionName', obj.functionName, 'tableName', obj.tableName, 'source', src);
        end

        function disp(obj)
            for k = 1:numel(obj)
                t = obj(k);
                dims = strjoin(arrayfun(@(b) sprintf('%s [%s] (%d)', b.name, b.units, numel(b.values)), t.breakpoints, ...
                    'UniformOutput', false), ' x ');
                src = '(no source)';
                if ~isempty(t.source), src = char(t.source); end
                fprintf('  Table %s (%s) [%s]: %s\n    %s\n', t.varID, t.name, t.units, dims, src);
            end
        end
    end

    methods (Static)
        function t = fromStruct(s, bpDefs)
            %FROMSTRUCT  bpDefs: the model's breakpointDefs (vital.data.Breakpoint array);
            %   the table refers to them by bpID and names each by its input.
            g = @(f, d) vital.data.internal.field(s, f, d);
            ids = vital.data.internal.asCellstr(g('bpIDs', {}));
            ins = vital.data.internal.asCellstr(g('inputs', {}));
            if numel(ins) ~= numel(ids)
                error('vital:data:badFormat', 'table %s: %d inputs but %d bpIDs.', char(s.varID), numel(ins), numel(ids));
            end
            bps = vital.data.Breakpoint.empty;
            for k = 1:numel(ids)
                j = find(arrayfun(@(b) strcmp(b.bpID, ids{k}), bpDefs), 1);
                if isempty(j)
                    error('vital:data:badFormat', 'table %s refers to undefined breakpoints "%s".', char(s.varID), ids{k});
                end
                bps(k) = bpDefs(j).withName(ins{k});
            end
            num = @vital.data.internal.num;
            t = vital.data.Table(char(s.varID), bps, num(g('data', [])), char(g('units', '')), g('source', []), ...
                'Name', char(g('name', '')), 'Description', char(g('description', '')), ...
                'Extrapolate', g('extrapolate', {}), 'Lo', num(g('lo', [])), 'Hi', num(g('hi', [])), ...
                'FunctionName', char(g('functionName', '')), 'TableName', char(g('tableName', '')));
        end
    end

    methods (Access = private)
        function checkShape(obj)
            d = numel(obj.breakpoints);
            n = cellfun(@numel, obj.bpValues);
            if d == 1
                ok = isvector(obj.data) && numel(obj.data) == n;
            else
                sz = size(obj.data);
                sz(end+1:d) = 1;
                ok = numel(sz) == d && isequal(sz, n);
            end
            ok = ok && numel(obj.extrapolate) == d && numel(obj.lo) == d && numel(obj.hi) == d && ...
                all(ismember(obj.extrapolate, {'neither', 'min', 'max', 'both'}));
            if ~ok
                error('vital:data:badFormat', 'table %s: data of size %s does not fit breakpoints of sizes %s.', ...
                    obj.varID, mat2str(size(obj.data)), mat2str(n));
            end
        end
    end
end
