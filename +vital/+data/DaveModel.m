classdef DaveModel
%DAVEMODEL  The contents of one DAVE-ML file as objects, callable by name (value
%   class; D1, docs/PLAN_DATA_LAYER.md, ADR-042). Base of vital.data.AeroDatabase,
%   PropulsionData, MassData and ControlData.
%   Properties
%     name         the file header name;  role  'aero' | 'propulsion' | 'mass' | ...
%     source       vital.data.Source of the whole file (path, SHA-256)
%     variables    vital.data.Variable array, one per variableDef, in file order
%     breakpoints  vital.data.Breakpoint array, one per breakpointDef
%     tables       vital.data.Table array, one per <function> (gridded table)
%     checkCases   struct array (name, line, inputs, outputs, internal), the file's
%                  checkData static shots (inputs/outputs: varID, value, tol)
%   Calls (names: varID, then variable name, then either case-insensitively;
%   tables also by function or table name):
%     v = m.variable('sref')       vital.data.Variable (a Parameter)
%     p = m.parameter('sref')      the same; for constants and inputs
%     t = m.table('CXT')           vital.data.Table
%     b = m.breakpoint('ALPHA1')   vital.data.Breakpoint (a breakpointDef)
%     e = m.equation('cx')         the MATLAB expression of a calculation
%     T = m.list()                 a MATLAB table of the variables (printed if no output)
%     out = m.evaluate(in)         the whole build-up at inputs in (struct by varID, in
%                                  the file's units): every variable plus
%                                  out.outOfEnvelope. EXACTLY the evaluation of the
%                                  generated code vital.daveml.compile writes (same
%                                  expressions, same lookup, same saturations), so the
%                                  two are bitwise equal (tests/M9/data/tDataCheckCases).
%                                  Missing input without a default:
%                                  vital:daveml:missingInput (as the generated code).
%     rep = m.runChecks()          the checkData replay (vital.daveml.runCheckData)
%   Build: vital.data.DaveModel.partsFromDaveML(relPath, 'DataRoot', root) reads a file
%   listed in data/MANIFEST.json (hash checked: vital:data:hashMismatch) and returns
%   the parts every subclass constructor takes. NOTHING in the plant's hot loop
%   calls these methods: the runtime keeps the generated code.

    properties (SetAccess = protected)
        name (1,:) char = ''
        role (1,:) char = ''
        source = vital.data.Source.empty
        variables = vital.data.Variable.empty
        breakpoints = vital.data.Breakpoint.empty
        tables = vital.data.Table.empty
        checkCases struct = struct('name', {}, 'line', {}, 'inputs', {}, 'outputs', {}, 'internal', {})
    end

    properties (SetAccess = protected, Hidden)
        plan struct = struct()       % compiled evaluation order (never serialized)
    end

    methods
        function obj = DaveModel(parts)
            if nargin == 0 || isempty(parts), return; end
            obj.name = char(parts.name);
            obj.role = char(parts.role);
            obj.source = vital.data.Source.fromStruct(parts.source);
            obj.variables = reshape(parts.variables, 1, []);
            obj.breakpoints = reshape(parts.breakpoints, 1, []);
            obj.tables = reshape(parts.tables, 1, []);
            obj.checkCases = normalizeChecks(parts.checkCases);
            obj.plan = compilePlan(obj.variables, obj.tables, obj.where());
        end

        function v = variable(obj, name)
            k = resolve(obj, {obj.variables.varID}, {obj.variables.name}, name, 'variable');
            v = obj.variables(k);
        end

        function p = parameter(obj, name)
            p = obj.variable(name);
        end

        function t = table(obj, name)
            t = obj.tables(resolve(obj, {obj.tables.varID}, ...
                [{obj.tables.name}, {obj.tables.functionName}, {obj.tables.tableName}], name, 'table'));
        end

        function b = breakpoint(obj, bpID)
            k = resolve(obj, {obj.breakpoints.bpID}, {obj.breakpoints.name}, bpID, 'breakpoint set');
            b = obj.breakpoints(k);
        end

        function e = equation(obj, name)
            v = obj.variable(name);
            switch v.kind
                case 'calc'
                    e = v.expression;
                case 'table'
                    t = obj.table(v.varID);
                    e = sprintf('table %s(%s)', t.varID, strjoin({t.breakpoints.name}, ', '));
                otherwise
                    e = '';
            end
        end

        function T = list(obj)
            v = obj.variables;
            lines = arrayfun(@(x) x.source.line, v);
            T = table(string({v.varID}).', string({v.name}).', string({v.kind}).', string({v.units}).', lines(:), ...
                'VariableNames', {'varID', 'name', 'kind', 'units', 'line'});
            if nargout == 0
                fprintf('  %s (%s): %d variables, %d tables, %d breakpoint sets, %d check cases\n', obj.name, obj.role, ...
                    numel(obj.variables), numel(obj.tables), numel(obj.breakpoints), numel(obj.checkCases));
                disp(T);
                clear T
            end
        end

        function out = evaluate(obj, in)
            %EVALUATE  The build-up; bitwise the generated code (see the class header).
            if nargin < 2, in = struct(); end
            P = obj.plan;
            n = numel(P.ids);
            vals = cell(1, n);
            oe = false;
            for j = P.order
                switch P.kind(j)
                    case 1
                        id = P.ids{j};
                        if isfield(in, id)
                            x = in.(id);
                        elseif ~isnan(P.value(j))
                            x = P.value(j);
                        else
                            error('vital:daveml:missingInput', 'required input "%s" (%s) not supplied', id, P.names{j});
                        end
                    case 2
                        x = P.value(j);
                    case 3
                        x = P.fh{j}(vals{P.args{j}});
                    case 4
                        t = P.tbl{j};
                        [x, c] = vital.daveml.lookup(t.bpValues, t.data, [vals{P.args{j}}], t.extrapolate, t.lo, t.hi);
                        oe = oe || c;
                end
                if isfinite(P.minValue(j)), x = max(x, P.minValue(j)); end
                if isfinite(P.maxValue(j)), x = min(x, P.maxValue(j)); end
                vals{j} = x;
            end
            out = cell2struct(vals, P.ids, 2);
            out.outOfEnvelope = oe;
        end

        function rep = runChecks(obj)
            rep = vital.daveml.runCheckData(struct('checks', obj.checkCases), @(in) obj.evaluate(in));
        end

        function validate(obj, where)
            if nargin < 2, where = obj.where(); end
            if isempty(obj.source) || ~obj.source.isValid()
                error('vital:data:noProvenance', '%sthe file source is missing or invalid.', where);
            end
            obj.variables.validate(where);
            obj.breakpoints.validate(where);
            obj.tables.validate(where);
            for t = obj.tables
                v = obj.variable(t.varID);
                if ~strcmp(v.kind, 'table') || ~strcmp(v.units, t.units)
                    error('vital:data:badFormat', '%stable %s: its variable is not a table output with the same units.', where, t.varID);
                end
            end
        end

        function s = toStruct(obj)
            s.class = erase(class(obj), 'vital.data.');
            s.name = obj.name;
            s.role = obj.role;
            s.source = obj.source.toStruct();
            s = obj.extraStruct(s);
            s.variables = arrayfun(@(v) v.toStruct(), obj.variables, 'UniformOutput', false);
            s.breakpoints = arrayfun(@(b) b.toStruct(), obj.breakpoints, 'UniformOutput', false);
            s.tables = arrayfun(@(t) t.toStruct(), obj.tables, 'UniformOutput', false);
            s.checkCases = obj.checkCases;
        end

        function disp(obj)
            for k = 1:numel(obj)
                m = obj(k);
                fprintf('  %s ''%s'' (%s): %d variables, %d tables, %d breakpoint sets, %d check cases\n', class(m), ...
                    m.name, m.role, numel(m.variables), numel(m.tables), numel(m.breakpoints), numel(m.checkCases));
                if ~isempty(m.source), fprintf('    %s\n', char(m.source)); end
            end
        end
    end

    methods (Access = protected)
        function s = extraStruct(~, s)
        end

        function w = where(obj)
            w = sprintf('%s ''%s'': ', erase(class(obj), 'vital.data.'), obj.name);
        end
    end

    methods (Static)
        function m = fromStruct(s)
            %FROMSTRUCT  Dispatch on s.class (AeroDatabase, PropulsionData, MassData, ControlData).
            cls = char(vital.data.internal.field(s, 'class', ''));
            switch cls
                case 'AeroDatabase', m = vital.data.AeroDatabase.fromStruct(s);
                case 'PropulsionData', m = vital.data.PropulsionData.fromStruct(s);
                case 'MassData', m = vital.data.MassData.fromStruct(s);
                case 'ControlData', m = vital.data.ControlData.fromStruct(s);
                otherwise
                    error('vital:data:badFormat', 'unknown data model class "%s".', cls);
            end
        end

        function parts = partsFromStruct(s)
            g = @(f, d) vital.data.internal.field(s, f, d);
            parts.name = char(g('name', ''));
            parts.role = char(g('role', ''));
            parts.source = g('source', []);
            bps = vital.data.Breakpoint.empty;
            for c = vital.data.internal.asList(g('breakpoints', []))
                bps(end+1) = vital.data.Breakpoint.fromStruct(c{1}); %#ok<AGROW>
            end
            vars = vital.data.Variable.empty;
            for c = vital.data.internal.asList(g('variables', []))
                vars(end+1) = vital.data.Variable.fromStruct(c{1}); %#ok<AGROW>
            end
            tabs = vital.data.Table.empty;
            for c = vital.data.internal.asList(g('tables', []))
                tabs(end+1) = vital.data.Table.fromStruct(c{1}, bps); %#ok<AGROW>
            end
            parts.variables = vars;
            parts.breakpoints = bps;
            parts.tables = tabs;
            parts.checkCases = g('checkCases', []);
        end

        function parts = partsFromDaveML(relPath, role, opts)
            %PARTSFROMDAVEML  Read one DAVE-ML file of data/MANIFEST.json into parts.
            arguments
                relPath (1,:) char
                role (1,:) char
                opts.DataRoot (1,:) char = ''
            end
            [path, sha] = vital.data.sourceFile(relPath, 'DataRoot', opts.DataRoot);
            [m, L] = vital.data.internal.readCached(path, sha);
            relPath = strrep(relPath, '\', '/');
            src = @(line, id, el) vital.data.Source(relPath, line, sha, id, el, '');
            parts.name = m.name;
            parts.role = role;
            parts.source = vital.data.Source(relPath, L.header, sha, '', 'DAVEfunc', '');
            vars = vital.data.Variable.empty;
            for k = 1:numel(m.vars)
                v = m.vars(k);
                kind = v.kind;
                if strcmp(kind, 'function'), kind = 'table'; end
                vars(k) = vital.data.Variable(v.varID, v.name, v.units, src(L.variableDef(v.varID), v.varID, 'variableDef'), ...
                    'Kind', kind, 'Value', v.initialValue, 'MinValue', v.minValue, 'MaxValue', v.maxValue, ...
                    'IsInput', v.isInput, 'IsOutput', v.isOutput, 'Expression', v.expr, 'Deps', v.deps);
            end
            bps = vital.data.Breakpoint.empty;
            for k = 1:numel(m.breakpoints)
                b = m.breakpoints(k);
                nm = '';
                if isKey(L.bpName, b.bpID), nm = L.bpName(b.bpID); end
                bps(k) = vital.data.Breakpoint(nm, b.bpID, b.units, b.vals, src(L.breakpointDef(b.bpID), b.bpID, 'breakpointDef'));
            end
            tabs = vital.data.Table.empty;
            for k = 1:numel(m.functions)
                f = m.functions(k);
                gt = L.functionTable(f.name);
                ids = L.gridBpIDs(gt);
                tb = vital.data.Breakpoint.empty;
                for j = 1:numel(f.inputs)
                    def = bps(strcmp({bps.bpID}, ids{j}));
                    if ~isequal(def.values, f.bps{j})
                        error('vital:data:badFormat', '%s function "%s": breakpoints %s do not match.', relPath, f.name, ids{j});
                    end
                    tb(j) = def.withName(f.inputs{j});
                end
                data = f.data;
                vo = vars(strcmp({vars.varID}, f.output));
                tableName = gt;
                if isKey(L.gridName, gt), tableName = L.gridName(gt); end
                tabs(k) = vital.data.Table(f.output, tb, data, vo.units, src(L.function(f.name), f.output, 'function'), ...
                    'Name', vo.name, 'Extrapolate', f.extrapolate, 'Lo', f.lo, 'Hi', f.hi, 'FunctionName', f.name, 'TableName', tableName);
            end
            checks = m.checks;
            for k = 1:numel(checks)
                checks(k).line = L.staticShot(k);
            end
            parts.variables = vars;
            parts.breakpoints = bps;
            parts.tables = tabs;
            parts.checkCases = checks;
        end
    end
end

% ============================================================================
function c = emptyChecks()
c = struct('name', {}, 'line', {}, 'inputs', {}, 'outputs', {}, 'internal', {});
end

function c = normalizeChecks(raw)
% one layout for checks from vital.daveml.read and from JSON: 1xN struct arrays
c = reshape(emptyChecks(), 1, 0);
num = @vital.data.internal.num;
for r = vital.data.internal.asList(raw)
    x = r{1};
    g = @(f, d) vital.data.internal.field(x, f, d);
    c(end+1) = struct('name', char(g('name', '')), 'line', num(g('line', NaN)), 'inputs', sig(g('inputs', [])), ...
        'outputs', sig(g('outputs', [])), 'internal', sig(g('internal', []))); %#ok<AGROW>
end
    function s = sig(list)
        s = reshape(struct('varID', {}, 'value', {}, 'tol', {}), 1, 0);
        for e = vital.data.internal.asList(list)
            s(end+1) = struct('varID', char(e{1}.varID), 'value', num(e{1}.value), 'tol', num(e{1}.tol)); %#ok<AGROW>
        end
    end
end

function k = resolve(obj, ids, names, q, what)
q = char(q);
k = find(strcmp(ids, q), 1);
if isempty(k), k = mod(find(strcmp(names, q), 1) - 1, numel(ids)) + 1; end
if isempty(k)
    hit = unique([find(strcmpi(ids, q)), mod(find(strcmpi(names, q)) - 1, max(numel(ids), 1)) + 1]);
    if numel(hit) == 1
        k = hit;
    elseif numel(hit) > 1
        error('vital:data:ambiguousName', '%s''%s'' matches several %ss ignoring case: %s.', obj.where(), q, what, ...
            strjoin(ids(hit), ', '));
    end
end
if isempty(k)
    error('vital:data:unknownName', '%sno %s ''%s''.', obj.where(), what, q);
end
end

function P = compilePlan(vars, tables, where)
% evaluation order and per-variable kind, value, saturations, function handles
n = numel(vars);
P.ids = {vars.varID};
P.names = {vars.name};
kinds = {vars.kind};
P.kind = zeros(1, n);
P.value = NaN(1, n);
P.minValue = [vars.minValue];
P.maxValue = [vars.maxValue];
P.fh = cell(1, n);
P.args = cell(1, n);
P.tbl = cell(1, n);
deps = cell(1, n);
tids = {tables.varID};
vnames = cellfun(@(s) ['v_' matlab.lang.makeValidName(s)], P.ids, 'UniformOutput', false);
for j = 1:n
    v = vars(j);
    switch kinds{j}
        case 'input'
            P.kind(j) = 1;
            if isscalar(v.value), P.value(j) = v.value; end
            deps{j} = cell(1, 0);
        case 'constant'
            P.kind(j) = 2;
            if ~(isscalar(v.value) && ~isnan(v.value))
                error('vital:data:badFormat', '%sconstant "%s" has no value.', where, v.varID);
            end
            P.value(j) = v.value;
            deps{j} = cell(1, 0);
        case 'calc'
            P.kind(j) = 3;
            used = vital.data.internal.checkExpression(v.expression, P.ids, sprintf('%svariable "%s"', where, v.varID), vnames);
            d = v.deps;
            if isempty(d) && ~isempty(used), d = used; end
            if ~isempty(setdiff(used, d))
                error('vital:data:badExpression', '%svariable "%s": the expression uses %s, not in its deps.', where, ...
                    v.varID, strjoin(setdiff(used, d), ', '));
            end
            deps{j} = d;
            argn = cellfun(@(s) ['v_' matlab.lang.makeValidName(s)], d, 'UniformOutput', false);
            P.fh{j} = str2func(['@(' strjoin(argn, ',') ') ' v.expression]);
        case 'table'
            P.kind(j) = 4;
            k = find(strcmp(tids, v.varID), 1);
            if isempty(k)
                error('vital:data:badFormat', '%stable output "%s" has no table.', where, v.varID);
            end
            P.tbl{j} = tables(k);
            deps{j} = {tables(k).breakpoints.name};
    end
end
P.order = vital.data.internal.topoOrder(P.ids, deps);
for j = 1:n
    P.args{j} = cellfun(@(d) find(strcmp(P.ids, d), 1), deps{j});
end
end
