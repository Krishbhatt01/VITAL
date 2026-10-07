function validateRule(rec)
%VALIDATERULE  Check a requirement record against the VITAL rule schema.
%   See rules\schema\RULE_SCHEMA.md. Errors:
%     vital:rule:missingField  a required field (incl. any citation field) is absent or empty
%     vital:rule:badValue      a field has a value outside its allowed set or range
%
%   A record without a full citation (document, paragraph, page) is
%   rejected: no requirement may enter VITAL from memory.
REQUIRED = {'id','title','ruleset','class','source','applicability','metric', ...
            'criterion','scale','conditions','status_policy'};
CLASSES  = {'Q-SPEC','Q-CFR','Q-STD','Q-PROXY','PILOT','ANALYSIS-SUPPORT','OUT-OF-SIM','DEFINITION'};
need(rec, REQUIRED, 'record');
need(rec.source, {'document','paragraph','page'}, 'source');
if ~any(strcmp(rec.class, CLASSES))
    error('vital:rule:badValue', 'class "%s" is not one of %s', char(rec.class), strjoin(CLASSES, ', '));
end
if ~(isnumeric(rec.scale) && isscalar(rec.scale) && isfinite(rec.scale) && rec.scale > 0)
    error('vital:rule:badValue', 'scale must be a positive finite number');
end
need(rec.criterion, {'type'}, 'criterion');
switch rec.criterion.type
    case 'levels'
        need(rec.criterion, {'levels'}, 'criterion');
        L = rec.criterion.levels;
        for k = 1:numel(L)
            need(L(k), {'level','category'}, sprintf('levels(%d)', k));
            if ~ismember(L(k).level, [1 2 3])
                error('vital:rule:badValue', 'levels(%d).level must be 1, 2 or 3', k);
            end
            lo = bound(L(k), 'min', -Inf); hi = bound(L(k), 'max', Inf);
            if isinf(lo) && isinf(hi)
                error('vital:rule:badValue', 'levels(%d) needs at least one of min/max', k);
            end
            if ~(lo < hi)
                error('vital:rule:badValue', 'levels(%d): min %.6g must be below max %.6g', k, lo, hi);
            end
        end
    case 'threshold'
        need(rec.criterion, {'op','limit'}, 'criterion');
        if ~any(strcmp(rec.criterion.op, {'>=','<=','>','<'}))
            error('vital:rule:badValue', 'criterion.op must be >=, <=, > or <');
        end
        if ~(isnumeric(rec.criterion.limit) && isscalar(rec.criterion.limit) && isfinite(rec.criterion.limit))
            error('vital:rule:badValue', 'criterion.limit must be a finite number');
        end
    otherwise
        error('vital:rule:badValue', 'criterion.type must be "levels" or "threshold"');
end
end

function need(s, fields, where)
for f = fields
    if ~isfield(s, f{1}) || isempty(s.(f{1}))
        error('vital:rule:missingField', '%s is missing required field "%s"', where, f{1});
    end
end
end

function v = bound(s, f, default)
if isfield(s, f) && ~isempty(s.(f)), v = double(s.(f)); else, v = default; end
end
