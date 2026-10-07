function [rows, summary] = classifyResults(suite, results, milestone, phase, opts)
%CLASSIFYRESULTS  Turn matlab.unittest results into RED/GREEN gate classes.
%
%   phase 'green'  every test must pass            -> PASS | FAIL
%   phase 'red'    tests of the CURRENT milestone:
%                    fails citing vital:notImplemented -> RED_EXPECTED
%                    fails with any other exception    -> RED_UNEXPECTED
%                    fails a check, no exception       -> RED_SUSPICIOUS
%                    already passes                    -> VACUOUS
%                  tests of EARLIER milestones:
%                    passes -> PASS,  fails -> REGRESSION
%
%   A red gate is valid (gateOK) when there is no RED_UNEXPECTED and no
%   REGRESSION; RED_SUSPICIOUS and VACUOUS tests are listed in
%   summary.needsReview and must be justified in the gate report.
%   A green gate is valid only if every test passes.
%   The run must have used DiagnosticsRecordingPlugin.
%   'NotNew', {classes}: current-milestone classes treated as earlier ones
%   (finished increments; see run_vital_tests 'Baseline').
arguments
    suite matlab.unittest.Test
    results matlab.unittest.TestResult
    milestone (1,:) char
    phase (1,:) char {mustBeMember(phase, {'red','green'})}
    opts.NotNew cell = {}
end
mk = vital.test.milestoneNumber(milestone);
CLASSES = {'PASS','FAIL','RED_EXPECTED','RED_UNEXPECTED','RED_SUSPICIOUS','VACUOUS','REGRESSION'};
rows = struct('name', {}, 'milestone', {}, 'isNew', {}, 'class', {}, 'detail', {});
names = string({suite.Name});
for i = 1:numel(results)
    r = results(i);
    j = find(names == string(r.Name), 1);
    tags = string(suite(j).Tags);
    mt = tags(matches(tags, regexpPattern('^M\d+$')));
    if isempty(mt), tnum = mk; else, tnum = max(vital.test.milestoneNumber(mt)); end
    isNew = (tnum == mk) && ~ismember(char(extractBefore(string(r.Name) + "/", "/")), opts.NotNew);
    [hasNotImpl, hasException, detail] = inspect(r);
    if strcmp(phase, 'green')
        if r.Passed, cls = 'PASS'; else, cls = 'FAIL'; end
    elseif r.Passed
        if isNew, cls = 'VACUOUS'; else, cls = 'PASS'; end
    elseif ~isNew
        cls = 'REGRESSION';
    elseif hasNotImpl
        cls = 'RED_EXPECTED';
    elseif hasException
        cls = 'RED_UNEXPECTED';
    else
        cls = 'RED_SUSPICIOUS';
    end
    rows(end+1) = struct('name', char(r.Name), 'milestone', sprintf('M%d', tnum), ...
        'isNew', isNew, 'class', cls, 'detail', detail); %#ok<AGROW>
end
counts = struct();
for c = CLASSES
    counts.(c{1}) = sum(strcmp({rows.class}, c{1}));
end
summary.milestone = milestone;
summary.phase = phase;
summary.total = numel(rows);
summary.counts = counts;
if strcmp(phase, 'green')
    summary.gateOK = summary.total > 0 && counts.PASS == summary.total;
else
    summary.gateOK = summary.total > 0 && counts.RED_UNEXPECTED == 0 && counts.REGRESSION == 0;
end
review = {rows(ismember({rows.class}, {'RED_SUSPICIOUS','VACUOUS'})).name};
summary.needsReview = review;
end

function [hasNotImpl, hasException, detail] = inspect(r)
hasNotImpl = false; hasException = false; detail = '';
if r.Passed || ~isfield(r.Details, 'DiagnosticRecord'), return; end
recs = r.Details.DiagnosticRecord;
parts = strings(0);
for k = 1:numel(recs)
    rep = string(recs(k).Report);
    parts(end+1) = rep; %#ok<AGROW>
    % Match the error IDENTIFIER, never free message text: an error whose
    % message merely mentions "vital:notImplemented" is not a stub.
    if isa(recs(k), 'matlab.unittest.plugins.diagnosticrecord.ExceptionDiagnosticRecord')
        hasException = true;
        if strcmp(recs(k).Exception.identifier, 'vital:notImplemented')
            hasNotImpl = true;
        end
    elseif ~isempty(regexp(rep, 'Actual Exception:\s*''vital:notImplemented''', 'once'))
        % verifyError/assertError saw the stub's identifier as the actual exception
        hasNotImpl = true;
    end
end
txt = regexprep(strjoin(parts, ' '), '\s+', ' ');
detail = char(extractBefore(txt + " ", min(strlength(txt) + 1, 600)));
end
