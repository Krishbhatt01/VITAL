function m = read(file)
%READ  Parse a DAVE-ML (ANSI/AIAA S-119) file into a VITAL model struct.
%   m = vital.daveml.read(file)
%
%   m.file, m.sha256, m.name
%   m.vars(k)        varID, name, units, initialValue (NaN if none),
%                    minValue/maxValue (-Inf/Inf if none; applied as
%                    SATURATIONS, ADR-014), isInput, isOutput,
%                    expr (compiled MATLAB expression of a <calculation>,
%                    '' if none), deps (varIDs used), kind
%                    ('input'|'constant'|'calc'|'function')
%   m.breakpoints(k) bpID, units, vals (strictly increasing)
%   m.functions(k)   name, output (varID), inputs (varIDs, table order),
%                    bps (cell of breakpoint vectors), data (N-D array,
%                    dims in breakpointRef order), extrapolate (cellstr),
%                    lo, hi (independentVarRef min/max, else table range)
%   m.checks(k)      name, inputs(varID,value), outputs(varID,value,tol),
%                    internal(varID,value)
%   m.order          evaluation order (indices into m.vars)
%
%   Table data: DAVE-ML lists gridded data with the LAST breakpoint varying
%   fastest; it is reshaped so data(i,j,...) belongs to bps{1}(i), bps{2}(j) ...
%   MathML in <calculation> is compiled to a MATLAB expression here; any
%   element VITAL does not implement raises vital:daveml:unsupportedElement
%   with its location. Nothing is ignored silently.
%
%   Errors: vital:daveml:fileNotFound, parseError, missingUnits,
%   nonMonotonicBreakpoints, tableSize, undefinedVariable, unsupportedElement,
%   cycle.
if ~isfile(file)
    error('vital:daveml:fileNotFound', 'DAVE-ML file not found: %s', file);
end
try
    p = matlab.io.xml.dom.Parser;
    p.Configuration.LoadExternalDTD = false;
    p.Configuration.Validate = false;
    p.Configuration.AllowDoctype = true;
    p.Configuration.Namespaces = true;
    doc = parseFile(p, file);
catch err
    error('vital:daveml:parseError', 'cannot parse %s: %s', file, err.message);
end
root = doc.getDocumentElement();
if ~strcmp(localName(root), 'DAVEfunc')
    error('vital:daveml:parseError', '%s: root element is <%s>, not <DAVEfunc>.', file, localName(root));
end
m.file = file;
m.sha256 = vital.io.sha256File(file);
hdr = firstChild(root, 'fileHeader');
if isempty(hdr), m.name = ''; else, m.name = char(hdr.getAttribute('name')); end

m.vars = struct('varID', {}, 'name', {}, 'units', {}, 'initialValue', {}, 'minValue', {}, ...
    'maxValue', {}, 'isInput', {}, 'isOutput', {}, 'expr', {}, 'deps', {}, 'kind', {});
m.breakpoints = struct('bpID', {}, 'units', {}, 'vals', {});
tables = struct('gtID', {}, 'bpIDs', {}, 'data', {});
fnNodes = {};
checkNode = [];
ALLOWED = {'fileHeader', 'variableDef', 'breakpointDef', 'griddedTableDef', 'function', 'checkData'};
for node = elementChildren(root)
    n = node{1};
    tag = localName(n);
    switch tag
        case 'variableDef'
            m.vars(end+1) = parseVariable(n);
        case 'breakpointDef'
            id = char(n.getAttribute('bpID'));
            vals = numbers(firstChild(n, 'bpVals'));
            if numel(vals) > 1 && any(diff(vals) <= 0)
                error('vital:daveml:nonMonotonicBreakpoints', 'breakpointDef[@bpID="%s"]: values must be strictly increasing.', id);
            end
            m.breakpoints(end+1) = struct('bpID', id, 'units', char(n.getAttribute('units')), 'vals', vals);
        case 'griddedTableDef'
            tables(end+1) = parseTable(n); %#ok<AGROW>
        case 'function'
            fnNodes{end+1} = n; %#ok<AGROW>
        case 'checkData'
            checkNode = n;
        otherwise
            if ~any(strcmp(tag, ALLOWED))
                error('vital:daveml:unsupportedElement', 'unsupported top-level element <%s> in %s.', tag, file);
            end
    end
end

ids = {m.vars.varID};
m.functions = struct('name', {}, 'output', {}, 'inputs', {}, 'bps', {}, 'data', {}, ...
    'extrapolate', {}, 'lo', {}, 'hi', {});
for k = 1:numel(fnNodes)
    f = parseFunction(fnNodes{k}, m.breakpoints, tables);
    m.functions(end+1) = f;
    j = find(strcmp(ids, f.output));
    if isempty(j)
        error('vital:daveml:undefinedVariable', 'function "%s" writes undefined variable "%s".', f.name, f.output);
    end
    m.vars(j).kind = 'function';
    m.vars(j).deps = reshape(f.inputs, 1, []);
end
for j = 1:numel(m.vars)
    for d = m.vars(j).deps
        if ~any(strcmp(ids, d{1}))
            error('vital:daveml:undefinedVariable', 'variableDef[@varID="%s"] uses undefined variable "%s".', ...
                m.vars(j).varID, d{1});
        end
    end
end
m.order = topoOrder(m.vars);
if isempty(checkNode)
    m.checks = struct('name', {}, 'inputs', {}, 'outputs', {}, 'internal', {});
else
    m.checks = parseChecks(checkNode, m.vars);
end
end

% ============================================================================
function v = parseVariable(n)
id = char(n.getAttribute('varID'));
where = sprintf('variableDef[@varID="%s"]', id);
units = char(n.getAttribute('units'));
if isempty(units)
    error('vital:daveml:missingUnits', '%s has no units attribute (every DAVE-ML variable must declare its units).', where);
end
v.varID = id;
v.name = char(n.getAttribute('name'));
v.units = units;
v.initialValue = attrNum(n, 'initialValue', NaN);
v.minValue = attrNum(n, 'minValue', -Inf);
v.maxValue = attrNum(n, 'maxValue', Inf);
v.isInput = ~isempty(firstChild(n, 'isInput'));
v.isOutput = ~isempty(firstChild(n, 'isOutput'));
calc = firstChild(n, 'calculation');
v.expr = ''; v.deps = {};
if ~isempty(calc)
    math = firstChild(calc, 'math');
    kids = elementChildren(math);
    if numel(kids) ~= 1
        error('vital:daveml:unsupportedElement', '%s: <math> must contain exactly one expression.', where);
    end
    deps = {};
    [v.expr, deps] = compileMath(kids{1}, where, deps);
    v.deps = reshape(unique(deps, 'stable'), 1, []);   % row: a 0x1 cell would iterate once in a for loop
    v.kind = 'calc';
elseif v.isInput
    v.kind = 'input';
else
    v.kind = 'constant';
end
end

function t = parseTable(n)
t.gtID = char(n.getAttribute('gtID'));
refs = firstChild(n, 'breakpointRefs');
t.bpIDs = {};
for r = elementChildren(refs)
    t.bpIDs{end+1} = char(r{1}.getAttribute('bpID'));
end
t.data = numbers(firstChild(n, 'dataTable'));
end

function f = parseFunction(n, bps, tables)
f.name = char(n.getAttribute('name'));
f.inputs = {}; f.extrapolate = {}; lo = []; hi = [];
for r = elementChildren(n)
    e = r{1};
    switch localName(e)
        case 'independentVarRef'
            f.inputs{end+1} = char(e.getAttribute('varID'));
            ex = char(e.getAttribute('extrapolate'));
            if isempty(ex), ex = 'neither'; end
            if ~any(strcmp(ex, {'neither', 'min', 'max', 'both'}))
                error('vital:daveml:unsupportedElement', 'function "%s": extrapolate="%s" is not a DAVE-ML value.', f.name, ex);
            end
            f.extrapolate{end+1} = ex;
            lo(end+1) = attrNum(e, 'min', NaN); %#ok<AGROW>
            hi(end+1) = attrNum(e, 'max', NaN); %#ok<AGROW>
        case 'dependentVarRef'
            f.output = char(e.getAttribute('varID'));
        case 'functionDefn'
            gd = firstChild(e, 'griddedTableDef');
            gr = firstChild(e, 'griddedTableRef');
            if ~isempty(gd)
                tbl = parseTable(gd);
            elseif ~isempty(gr)
                id = char(gr.getAttribute('gtID'));
                k = find(strcmp({tables.gtID}, id), 1);
                if isempty(k)
                    error('vital:daveml:undefinedVariable', 'function "%s" references undefined table "%s".', f.name, id);
                end
                tbl = tables(k);
            else
                other = elementChildren(e);
                nm = 'nothing'; if ~isempty(other), nm = localName(other{1}); end
                error('vital:daveml:unsupportedElement', 'function "%s": functionDefn with <%s> is not supported (only gridded tables).', f.name, nm);
            end
        case {'description', 'provenance', 'provenanceRef'}
        otherwise
            error('vital:daveml:unsupportedElement', 'function "%s": unsupported element <%s>.', f.name, localName(e));
    end
end
if numel(tbl.bpIDs) ~= numel(f.inputs)
    error('vital:daveml:tableSize', 'function "%s": %d inputs but %d breakpoint sets.', f.name, numel(f.inputs), numel(tbl.bpIDs));
end
f.bps = cell(1, numel(tbl.bpIDs));
sz = zeros(1, numel(tbl.bpIDs));
for k = 1:numel(tbl.bpIDs)
    j = find(strcmp({bps.bpID}, tbl.bpIDs{k}), 1);
    if isempty(j)
        error('vital:daveml:undefinedVariable', 'function "%s" references undefined breakpoint set "%s".', f.name, tbl.bpIDs{k});
    end
    f.bps{k} = bps(j).vals;
    sz(k) = numel(bps(j).vals);
end
if numel(tbl.data) ~= prod(sz)
    error('vital:daveml:tableSize', 'function "%s": %d table values for a %s grid.', f.name, numel(tbl.data), mat2str(sz));
end
% Last breakpoint varies fastest: reshape with reversed dimensions, then reverse them back.
if numel(sz) == 1
    f.data = tbl.data(:).';
else
    f.data = permute(reshape(tbl.data, fliplr(sz)), numel(sz):-1:1);
end
for k = 1:numel(sz)
    if isnan(lo(k)), lo(k) = f.bps{k}(1); end
    if isnan(hi(k)), hi(k) = f.bps{k}(end); end
end
f.lo = lo; f.hi = hi;
f = orderfields(f, {'name', 'output', 'inputs', 'bps', 'data', 'extrapolate', 'lo', 'hi'});
end

function checks = parseChecks(n, vars)
checks = struct('name', {}, 'inputs', {}, 'outputs', {}, 'internal', {});
for s = elementChildren(n)
    shot = s{1};
    if ~strcmp(localName(shot), 'staticShot')
        error('vital:daveml:unsupportedElement', 'checkData: unsupported element <%s>.', localName(shot));
    end
    c.name = char(shot.getAttribute('name'));
    c.inputs = signals(firstChild(shot, 'checkInputs'), vars, false);
    c.outputs = signals(firstChild(shot, 'checkOutputs'), vars, true);
    iv = firstChild(shot, 'internalValues');
    if isempty(iv)
        c.internal = struct('varID', {}, 'value', {}, 'tol', {});
    else
        c.internal = signals(iv, vars, false);
    end
    checks(end+1) = c; %#ok<AGROW>
end
end

function sig = signals(n, vars, needTol)
sig = struct('varID', {}, 'value', {}, 'tol', {});
if isempty(n), return; end
for s = elementChildren(n)
    e = s{1};
    idNode = firstChild(e, 'varID');
    if ~isempty(idNode)
        id = strtrim(char(idNode.getTextContent()));
    else
        nm = strtrim(char(firstChild(e, 'signalName').getTextContent()));
        k = find(strcmp({vars.name}, nm), 1);
        if isempty(k)
            error('vital:daveml:undefinedVariable', 'checkData signal "%s" matches no variableDef name.', nm);
        end
        id = vars(k).varID;
    end
    val = str2double(strtrim(char(firstChild(e, 'signalValue').getTextContent())));
    tolNode = firstChild(e, 'tol');
    if isempty(tolNode)
        if needTol
            error('vital:daveml:unsupportedElement', 'checkOutputs signal "%s" has no <tol>.', id);
        end
        tol = NaN;
    else
        tol = str2double(strtrim(char(tolNode.getTextContent())));
    end
    sig(end+1) = struct('varID', id, 'value', val, 'tol', tol); %#ok<AGROW>
end
end

% ---- MathML -------------------------------------------------------------------
function [s, deps] = compileMath(n, where, deps)
tag = localName(n);
switch tag
    case 'ci'
        id = strtrim(char(n.getTextContent()));
        deps{end+1} = id;
        s = ['v_' matlab.lang.makeValidName(id)];
    case 'cn'
        val = str2double(strtrim(char(n.getTextContent())));
        if ~isfinite(val) || ~isempty(elementChildren(n))
            error('vital:daveml:unsupportedElement', '%s: <cn> "%s" is not a plain decimal number.', where, strtrim(char(n.getTextContent())));
        end
        s = sprintf('%.17g', val);
    case 'apply'
        kids = elementChildren(n);
        if numel(kids) == 1 && strcmp(localName(kids{1}), 'piecewise')
            % NASA F16_aero.dml:611-628 wraps a <piecewise> in an operator-less
            % <apply>; the apply is then just grouping.
            [s, deps] = compileMath(kids{1}, where, deps);
            return
        end
        op = kids{1};
        args = cell(1, numel(kids) - 1);
        for k = 2:numel(kids)
            [args{k-1}, deps] = compileMath(kids{k}, where, deps);
        end
        s = applyOp(op, args, where);
    case 'piecewise'
        conds = {}; vals = {}; other = '';
        for pc = elementChildren(n)
            e = pc{1};
            switch localName(e)
                case 'piece'
                    pk = elementChildren(e);
                    if numel(pk) ~= 2
                        error('vital:daveml:unsupportedElement', '%s: <piece> needs a value and a condition.', where);
                    end
                    [vals{end+1}, deps] = compileMath(pk{1}, where, deps); %#ok<AGROW>
                    [conds{end+1}, deps] = compileMath(pk{2}, where, deps); %#ok<AGROW>
                case 'otherwise'
                    ok = elementChildren(e);
                    [other, deps] = compileMath(ok{1}, where, deps);
                otherwise
                    error('vital:daveml:unsupportedElement', '%s: <%s> inside <piecewise>.', where, localName(e));
            end
        end
        c = ['[' strjoin(conds, ', ') ']']; v = ['[' strjoin(vals, ', ') ']'];
        if isempty(other)
            s = sprintf('vital.daveml.piecewise(%s, %s)', c, v);
        else
            s = sprintf('vital.daveml.piecewise(%s, %s, %s)', c, v, other);
        end
    otherwise
        error('vital:daveml:unsupportedElement', '%s: MathML element <%s> is not supported.', where, tag);
end
end

function s = applyOp(op, a, where)
tag = localName(op);
n = numel(a);
need = @(k) assert(n == k, 'vital:daveml:unsupportedElement', '%s: <%s> expects %d argument(s), got %d.', where, tag, k, n);
switch tag
    case 'plus'
        if n == 1, s = ['(+' a{1} ')']; else, s = ['(' strjoin(a, ' + ') ')']; end
    case 'minus'
        if n == 1, s = ['(-' a{1} ')'];
        else, need(2); s = ['(' a{1} ' - ' a{2} ')']; end
    case 'times'
        s = ['(' strjoin(a, ' * ') ')'];
    case 'divide'
        need(2); s = ['(' a{1} ' / ' a{2} ')'];
    case 'power'
        need(2); s = ['(' a{1} ' ^ ' a{2} ')'];
    case {'abs', 'cos', 'sin', 'tan', 'exp', 'floor'}
        need(1); s = [tag '(' a{1} ')'];
    case 'ceiling'
        need(1); s = ['ceil(' a{1} ')'];
    case 'ln'
        need(1); s = ['log(' a{1} ')'];
    case {'min', 'max'}
        s = [tag '([' strjoin(a, ', ') '])'];
    case {'lt', 'gt', 'leq', 'geq', 'eq', 'neq'}
        need(2);
        sym = struct('lt', '<', 'gt', '>', 'leq', '<=', 'geq', '>=', 'eq', '==', 'neq', '~=');
        s = ['(' a{1} ' ' sym.(tag) ' ' a{2} ')'];
    case 'and'
        s = ['(' strjoin(a, ' & ') ')'];
    case 'or'
        s = ['(' strjoin(a, ' | ') ')'];
    case 'not'
        need(1); s = ['(~' a{1} ')'];
    case 'csymbol'
        url = char(op.getAttribute('definitionURL'));
        if endsWith(url, '#atan2')
            need(2); s = ['atan2(' a{1} ', ' a{2} ')'];
        else
            error('vital:daveml:unsupportedElement', '%s: csymbol "%s" is not supported.', where, url);
        end
    otherwise
        error('vital:daveml:unsupportedElement', '%s: MathML operator <%s> is not supported.', where, tag);
end
end

% ---- helpers ---------------------------------------------------------------------
function order = topoOrder(vars)
ids = {vars.varID};
n = numel(vars);
state = zeros(1, n);                    % 0 new, 1 visiting, 2 done
order = zeros(1, 0);
for k = 1:n
    [state, order] = visit(k, state, order);
end
    function [state, order] = visit(k, state, order)
        if state(k) == 2, return; end
        if state(k) == 1
            error('vital:daveml:cycle', 'circular dependency through variable "%s".', ids{k});
        end
        state(k) = 1;
        for d = vars(k).deps
            [state, order] = visit(find(strcmp(ids, d{1}), 1), state, order);
        end
        state(k) = 2;
        order(end+1) = k;
    end
end

function v = attrNum(n, name, default)
if n.hasAttribute(name)
    v = str2double(char(n.getAttribute(name)));
    if isnan(v)
        error('vital:daveml:unsupportedElement', 'attribute %s="%s" is not a number.', name, char(n.getAttribute(name)));
    end
else
    v = default;
end
end

function v = numbers(n)
txt = char(n.getTextContent());
txt = regexprep(txt, '<!--.*?-->', ' ');
parts = regexp(txt, '[,\s]+', 'split');
parts = parts(~cellfun(@isempty, parts));
v = str2double(parts);
if any(isnan(v))
    error('vital:daveml:parseError', 'non-numeric value in <%s>.', localName(n));
end
end

function c = firstChild(n, name)
c = [];
if isempty(n), return; end
for k = elementChildren(n)
    if strcmp(localName(k{1}), name)
        c = k{1}; return;
    end
end
end

function kids = elementChildren(n)
kids = {};
list = n.getChildNodes();
for i = 0:list.getLength() - 1
    node = list.item(i);
    if node.getNodeType() == 1
        kids{end+1} = node; %#ok<AGROW>
    end
end
end

function s = localName(n)
s = char(n.getLocalName());
if isempty(s)
    s = char(n.getNodeName());
    s = regexprep(s, '^.*:', '');
end
end
