function bp = breakpoints(file)
%BREAKPOINTS  Breakpoints of the NESC aero tables in alpha and el, read from the
%   GENERATED model (M8 amendment R4b, R4-7; docs/PLAN_M5_M8.md "Amendment R4b":
%   "the breakpoint lists are read from the generated NESC models, never
%   retyped").
%   bp = vital.uq.breakpoints()        the generated vital.models.f16.aero
%   bp = vital.uq.breakpoints(file)    another generated DAVE-ML model file
%
%   The file is the output of vital.daveml.compile: every table lookup is a line
%     [v_out, c_] = vital.daveml.lookup({K.fN_bp1, ...}, K.fN_data, [v_in1, ...], ...)
%   and every breakpoint vector a line K.fN_bpM = [ ... ];. The M-th breakpoint
%   vector of a lookup belongs to its M-th input variable. bp.alpha_deg and
%   bp.el_deg are the sorted unions of the breakpoints of every lookup whose
%   input is v_alpha (angle of attack, deg) or v_el (elevator, deg).
%   bp fields: alpha_deg (1 x n), el_deg (1 x n), source (the file), tables
%   (struct array: table, output, variable, breakpoints), variables (every
%   lookup input seen).
%   Errors: vital:badInput (file not found, or no alpha / el breakpoints in it).
arguments
    file (1,:) char = ''
end
persistent cache
if isempty(file)
    file = which('vital.models.f16.aero');
end
if ~isfile(file)
    error('vital:badInput', 'generated model file "%s" not found.', file);
end
if isstruct(cache) && strcmp(cache.source, file)
    bp = cache;
    return
end
txt = fileread(file);
vec = containers.Map();
tok = regexp(txt, 'K\.(f\d+_bp\d+)\s*=\s*\[([^\]]*)\];', 'tokens');
for k = 1:numel(tok)
    vec(tok{k}{1}) = sscanf(strrep(tok{k}{2}, ',', ' '), '%f').';
end
tables = struct('table', {}, 'output', {}, 'variable', {}, 'breakpoints', {});
lk = regexp(txt, '\[(v_\w+),\s*c_\]\s*=\s*vital\.daveml\.lookup\(\{([^}]*)\},\s*K\.\w+,\s*\[([^\]]*)\]', 'tokens');
for k = 1:numel(lk)
    names = strtrim(strsplit(lk{k}{2}, ','));
    ins = strtrim(strsplit(lk{k}{3}, ','));
    for j = 1:min(numel(names), numel(ins))
        nm = regexprep(names{j}, '^K\.', '');
        if ~isKey(vec, nm), continue; end
        tables(end+1) = struct('table', nm, 'output', lk{k}{1}, 'variable', ins{j}, 'breakpoints', vec(nm)); %#ok<AGROW>
    end
end
pick = @(v) unique([tables(strcmp({tables.variable}, v)).breakpoints]);
bp.alpha_deg = pick('v_alpha');
bp.el_deg = pick('v_el');
if isempty(bp.alpha_deg) || isempty(bp.el_deg)
    error('vital:badInput', 'no alpha or el breakpoints found in "%s".', file);
end
bp.source = file;
bp.tables = tables;
bp.variables = unique({tables.variable});
cache = bp;
end
