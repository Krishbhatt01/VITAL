function S = dmlScan(file)
%DMLSCAN  INDEPENDENT scan of a DAVE-ML file with regular expressions on its text
%   (no vital.daveml.read, no XML parser): what the file declares and on which line.
%   S.vars(k)        varID, name, units, initialValue (NaN if absent), line
%   S.bps(k)         bpID, units, vals (row), line
%   S.gts(k)         gtID, bpIDs (cell, breakpointRefs order), vals (row, file order), line
%   S.fns(k)         name, output (dependentVarRef), inputs (cell), gtID, line
%   S.shots(k)       name, line
%   Lines are 1-based and give the line on which the element's start tag BEGINS.
%   XML comments are blanked first (keeping every character offset), so a
%   commented-out element is never counted.
txt = fileread(file);
[cs, ce] = regexp(txt, '<!--.*?-->', 'start', 'end');
for k = 1:numel(cs)
    seg = txt(cs(k):ce(k));
    seg(seg ~= newline) = ' ';
    txt(cs(k):ce(k)) = seg;
end
nl = find(txt == newline);
lineAt = @(pos) sum(nl < pos) + 1;
attr = @(a, name) firstTok(regexp(a, ['\<' name '="([^"]*)"'], 'tokens', 'once'));

S.vars = struct('varID', {}, 'name', {}, 'units', {}, 'initialValue', {}, 'line', {});
[st, tk] = regexp(txt, '<variableDef\>([^>]*)>', 'start', 'tokens');
for k = 1:numel(st)
    a = tk{k}{1};
    iv = attr(a, 'initialValue');
    if isempty(iv), ivn = NaN; else, ivn = str2double(iv); end
    S.vars(end+1) = struct('varID', attr(a, 'varID'), 'name', attr(a, 'name'), 'units', attr(a, 'units'), ...
        'initialValue', ivn, 'line', lineAt(st(k)));
end
S.bps = struct('bpID', {}, 'units', {}, 'vals', {}, 'line', {});
[st, tk] = regexp(txt, '<breakpointDef\>([^>]*)>(.*?)</breakpointDef>', 'start', 'tokens');
for k = 1:numel(st)
    v = regexp(tk{k}{2}, '<bpVals>(.*?)</bpVals>', 'tokens', 'once');
    S.bps(end+1) = struct('bpID', attr(tk{k}{1}, 'bpID'), 'units', attr(tk{k}{1}, 'units'), ...
        'vals', nums(v{1}), 'line', lineAt(st(k)));
end
S.gts = struct('gtID', {}, 'bpIDs', {}, 'vals', {}, 'line', {});
[st, tk] = regexp(txt, '<griddedTableDef\>([^>]*)>(.*?)</griddedTableDef>', 'start', 'tokens');
for k = 1:numel(st)
    body = tk{k}{2};
    refs = regexp(regexp(body, '<breakpointRefs>(.*?)</breakpointRefs>', 'tokens', 'once'), 'bpID="([^"]*)"', 'tokens');
    refs = cellfun(@(c) c{1}, refs{1}, 'UniformOutput', false);
    dt = regexp(body, '<dataTable>(.*?)</dataTable>', 'tokens', 'once');
    S.gts(end+1) = struct('gtID', attr(tk{k}{1}, 'gtID'), 'bpIDs', {refs}, 'vals', nums(dt{1}), 'line', lineAt(st(k)));
end
S.fns = struct('name', {}, 'output', {}, 'inputs', {}, 'gtID', {}, 'line', {});
[st, tk] = regexp(txt, '<function\>([^>]*)>(.*?)</function>', 'start', 'tokens');
for k = 1:numel(st)
    body = tk{k}{2};
    ins = regexp(body, '<independentVarRef\>[^>]*\<varID="([^"]*)"', 'tokens');
    out = regexp(body, '<dependentVarRef\>[^>]*\<varID="([^"]*)"', 'tokens', 'once');
    g = regexp(body, '<griddedTable(?:Def|Ref)\>[^>]*\<gtID="([^"]*)"', 'tokens', 'once');
    S.fns(end+1) = struct('name', attr(tk{k}{1}, 'name'), 'output', out{1}, ...
        'inputs', {cellfun(@(c) c{1}, ins, 'UniformOutput', false)}, 'gtID', g{1}, 'line', lineAt(st(k)));
end
S.shots = struct('name', {}, 'line', {});
[st, tk] = regexp(txt, '<staticShot\>([^>]*)>', 'start', 'tokens');
for k = 1:numel(st)
    S.shots(end+1) = struct('name', attr(tk{k}{1}, 'name'), 'line', lineAt(st(k)));
end
end

function s = firstTok(c)
if isempty(c), s = ''; else, s = c{1}; end
end

function v = nums(s)
p = regexp(s, '[,\s]+', 'split');
p = p(~cellfun(@isempty, p));
v = str2double(p);
end
