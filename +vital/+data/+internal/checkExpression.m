function deps = checkExpression(expr, ids, where, vnames)
%CHECKEXPRESSION  Refuse anything in a build-up expression that is not the MathML
%   subset vital.daveml.read compiles (D1: a .vital.json file is DATA, never code).
%   deps = vital.data.internal.checkExpression(expr, varIDs, where, vnames)
%   (vnames: the v_ names of varIDs, optional, precomputed for speed)
%   Allowed: numbers, v_<name> variables (v_ + matlab.lang.makeValidName(varID) of
%   one of ids), + - * / ^ ( ) [ ] , < > <= >= == ~= & | ~, and the functions abs cos
%   sin tan exp floor ceil log min max atan2 vital.daveml.piecewise.
%   deps: the varIDs the expression uses, in order of first appearance.
%   Anything else: vital:data:badExpression.
ALLOWED = {'abs', 'cos', 'sin', 'tan', 'exp', 'floor', 'ceil', 'log', 'min', 'max', 'atan2', 'vital.daveml.piecewise'};
if nargin < 4, vnames = cellfun(@(s) ['v_' matlab.lang.makeValidName(s)], ids, 'UniformOutput', false); end
rest = regexprep(expr, '(?<![\w.])(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?', ' ');   % numbers (not digits inside names)
words = regexp(rest, '[A-Za-z_][\w]*(\.[A-Za-z_]\w*)*', 'match');
deps = {};
for w = words
    if any(strcmp(w{1}, ALLOWED)), continue; end
    k = find(strcmp(w{1}, vnames), 1);
    if isempty(k)
        error('vital:data:badExpression', '%s: "%s" is not an allowed name in a build-up expression.', where, w{1});
    end
    if ~any(strcmp(deps, ids{k})), deps{end+1} = ids{k}; end %#ok<AGROW>
end
ops = regexprep(rest, '[A-Za-z_][\w]*(\.[A-Za-z_]\w*)*', ' ');
if ~isempty(regexp(ops, '[^\s+\-*/^()\[\],<>=~&|]', 'once')) || contains(ops, '''') || contains(ops, '"')
    error('vital:data:badExpression', '%s: the expression "%s" contains a character outside the allowed subset.', where, expr);
end
deps = reshape(deps, 1, []);
end
