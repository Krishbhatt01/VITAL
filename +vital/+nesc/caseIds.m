function ids = caseIds()
%CASEIDS  The NESC atmospheric check-cases VITAL reproduces (NESC_CASE_MATRIX.json).
%   ids = vital.nesc.caseIds()  ->  {'1', ..., '10', '11', '12', '13.1', ..., '13.4', '15', '16'}
%   Case 14 does not exist in the atmospheric set and case 17 (two-stage rocket)
%   is out of scope (docs/NESC_CASE_MATRIX.md).
M = vital.nesc.caseDef('matrix');
ids = {M.cases.id};
end
