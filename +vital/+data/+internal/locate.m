function L = locate(file)
%LOCATE  Line numbers of the elements of a DAVE-ML file (D1 provenance).
%   L = vital.data.internal.locate(file)
%   L.variableDef, L.breakpointDef, L.function, L.griddedTableDef: containers.Map
%     from varID / bpID / function name / gtID to the 1-based line on which the
%     element's start tag BEGINS (an attribute may sit on a later line).
%   L.functionTable: function name -> gtID of its table (inline def or ref);
%   L.gridBpIDs: gtID -> its breakpointRefs bpIDs (cellstr, table order);
%   L.gridName: gtID -> the griddedTableDef name attribute; L.bpName: bpID -> name.
%   L.staticShot: 1xN lines of the <staticShot> elements in file order.
%   L.header: line of <fileHeader>.
%   XML comments are blanked first (offsets kept), as the XML parser ignores them.
txt = fileread(file);
[cs, ce] = regexp(txt, '<!--.*?-->', 'start', 'end');
for k = 1:numel(cs)
    seg = txt(cs(k):ce(k));
    seg(seg ~= newline) = ' ';
    txt(cs(k):ce(k)) = seg;
end
nl = find(txt == newline);
lineAt = @(pos) sum(nl < pos) + 1;
L.variableDef = mapOf(txt, '<variableDef\>[^>]*?\<varID="([^"]*)"', lineAt);
L.breakpointDef = mapOf(txt, '<breakpointDef\>[^>]*?\<bpID="([^"]*)"', lineAt);
L.griddedTableDef = mapOf(txt, '<griddedTableDef\>[^>]*?\<gtID="([^"]*)"', lineAt);
L.function = containers.Map('KeyType', 'char', 'ValueType', 'double');
L.functionTable = containers.Map('KeyType', 'char', 'ValueType', 'char');
[st, tk] = regexp(txt, '<function\>[^>]*?\<name="([^"]*)"[^>]*>(.*?)</function>', 'start', 'tokens');
for k = 1:numel(st)
    if ~isKey(L.function, tk{k}{1}), L.function(tk{k}{1}) = lineAt(st(k)); end
    g = regexp(tk{k}{2}, '<griddedTable(?:Def|Ref)\>[^>]*?\<gtID="([^"]*)"', 'tokens', 'once');
    if ~isempty(g), L.functionTable(tk{k}{1}) = g{1}; end
end
L.gridName = containers.Map('KeyType', 'char', 'ValueType', 'char');
tk = regexp(txt, '<griddedTableDef\>([^>]*)>', 'tokens');
for k = 1:numel(tk)
    id = regexp(tk{k}{1}, '\<gtID="([^"]*)"', 'tokens', 'once');
    nm = regexp(tk{k}{1}, '\<name="([^"]*)"', 'tokens', 'once');
    if ~isempty(id) && ~isempty(nm), L.gridName(id{1}) = nm{1}; end
end
L.gridBpIDs = containers.Map('KeyType', 'char', 'ValueType', 'any');
tk = regexp(txt, '<griddedTableDef\>([^>]*)>(.*?)</griddedTableDef>', 'tokens');
for k = 1:numel(tk)
    id = regexp(tk{k}{1}, '\<gtID="([^"]*)"', 'tokens', 'once');
    refs = regexp(regexp(tk{k}{2}, '<breakpointRefs>(.*?)</breakpointRefs>', 'tokens', 'once'), '\<bpID="([^"]*)"', 'tokens');
    if ~isempty(id) && ~isempty(refs)
        L.gridBpIDs(id{1}) = cellfun(@(c) c{1}, refs{1}, 'UniformOutput', false);
    end
end
L.bpName = containers.Map('KeyType', 'char', 'ValueType', 'char');
tk = regexp(txt, '<breakpointDef\>([^>]*)>', 'tokens');
for k = 1:numel(tk)
    id = regexp(tk{k}{1}, '\<bpID="([^"]*)"', 'tokens', 'once');
    nm = regexp(tk{k}{1}, '\<name="([^"]*)"', 'tokens', 'once');
    if ~isempty(id) && ~isempty(nm), L.bpName(id{1}) = nm{1}; end
end
st = regexp(txt, '<staticShot\>', 'start');
L.staticShot = arrayfun(lineAt, st);
st = regexp(txt, '<fileHeader\>', 'start', 'once');
if isempty(st), L.header = 1; else, L.header = lineAt(st); end
end

function m = mapOf(txt, pattern, lineAt)
m = containers.Map('KeyType', 'char', 'ValueType', 'double');
[st, tk] = regexp(txt, pattern, 'start', 'tokens');
for k = 1:numel(st)
    if ~isKey(m, tk{k}{1}), m(tk{k}{1}) = lineAt(st(k)); end
end
end
