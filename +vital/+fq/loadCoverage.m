function cov = loadCoverage(file)
%LOADCOVERAGE  Coverage table of MIL-F-8785C criteria VITAL does not assess.
%   cov = vital.fq.loadCoverage()   rules/mil_f_8785c/coverage.json
%   cov (struct array) fields: paragraph, metric, class, reason, candidate_ids
%   (1 x n cellstr; empty for paragraph-level entries without a candidate).
%   class: OUT-OF-SIM       the model cannot represent it (forces, feel system,
%                           landing configuration)
%          PILOT            qualitative or pilot-opinion requirement
%          NOT-IMPLEMENTED  computable in principle (e.g. from time histories)
%                           but not implemented in M6
%          NO-REQUIREMENT   the candidate has no numeric bound (a "-" cell or a
%                           figure without that boundary)
%   Errors: vital:fq:badCoverage (missing field, unknown class, empty reason).
arguments
    file (1,:) char = fullfile(vital.paths('rules'), 'mil_f_8785c', 'coverage.json')
end
raw = jsondecode(fileread(file));
if iscell(raw), raw = [raw{:}]; end
CLASSES = {'OUT-OF-SIM', 'PILOT', 'NOT-IMPLEMENTED', 'NO-REQUIREMENT'};
cov = struct('paragraph', {}, 'metric', {}, 'class', {}, 'reason', {}, 'candidate_ids', {});
for k = 1:numel(raw)
    e = raw(k);
    if ~all(isfield(e, {'paragraph', 'metric', 'class', 'reason', 'candidate_ids'}))
        error('vital:fq:badCoverage', 'coverage entry %d lacks a field.', k);
    end
    if ~any(strcmp(e.class, CLASSES)) || strlength(string(e.reason)) == 0
        error('vital:fq:badCoverage', 'coverage entry %d (%s): bad class or empty reason.', k, e.paragraph);
    end
    ids = e.candidate_ids;
    if isempty(ids), ids = {}; else, ids = reshape(cellstr(ids), 1, []); end
    cov(end+1) = struct('paragraph', e.paragraph, 'metric', e.metric, 'class', e.class, ...
        'reason', e.reason, 'candidate_ids', {ids}); %#ok<AGROW>
end
end
