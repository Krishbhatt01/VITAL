function report = run_sabotage(milestone, opts)
%RUN_SABOTAGE  Prove a milestone's tests can fail: apply each registered
%   sabotage (tests\M<k>\sabotages.json) to a temporary copy of VITAL, run
%   its target tests in a separate MATLAB process, and require them to go
%   RED. Also verifies that the real tree was not modified.
%
%   report = run_sabotage('M1')
%   report = run_sabotage('M5', 'Parts', {'A'})   only tests\M5\sabotages_A.json
%   Definitions: sabotages.json (part 'main') plus sabotages_<part>.json
%   (vital.test.loadSabotageSet). With Parts given, reports are named
%   M<k>_sabotage_<parts>.*. The tree-hash check assumes nobody else edits the
%   tree during the run; the final gate is always run with the tree quiet.
%   report.allDetected is true only if every sabotage was detected and the
%   tree hash is unchanged. Results go to reports\M<k>_sabotage.txt/.json.
arguments
    milestone (1,:) char
    opts.ReportDir (1,:) char = ''
    opts.Parts cell = {}
end
addpath(fileparts(mfilename('fullpath')));      % FC-110: no dependence on startup_vital
mk = vital.test.milestoneNumber(milestone);
root = vital.paths('root');
if isempty(opts.ReportDir), opts.ReportDir = vital.paths('reports'); end
sabs = vital.test.loadSabotageSet(fullfile(root, 'tests', sprintf('M%d', mk)), 'Parts', opts.Parts);
excl = {'data', 'reports'};
before = vital.test.treeHash(root, 'Exclude', excl);
rows = struct('id', {}, 'file', {}, 'targets', {}, 'detected', {}, 'results', {}, 'rationale', {});
for k = 1:numel(sabs)
    fprintf('sabotage %s (%s) ... ', sabs(k).id, sabs(k).file);
    r = vital.test.runSabotageCase(root, sabs(k));
    if r.detected, fprintf('DETECTED\n'); else, fprintf('NOT DETECTED\n'); end
    rows(end+1) = struct('id', sabs(k).id, 'file', sabs(k).file, 'targets', {sabs(k).targets}, ...
        'detected', r.detected, 'results', r.results, 'rationale', sabs(k).rationale); %#ok<AGROW>
end
after = vital.test.treeHash(root, 'Exclude', excl);
report.milestone = milestone;
report.treeUnchanged = strcmp(before, after);
report.treeHash = after;
report.sabotages = rows;
report.allDetected = all([rows.detected]) && report.treeUnchanged;
report.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
base = fullfile(opts.ReportDir, sprintf('M%d_sabotage', mk));
if ~isempty(opts.Parts), base = [base '_' strjoin(opts.Parts, '_')]; end
fid = fopen([base '.json'], 'w'); fprintf(fid, '%s', jsonencode(report, 'PrettyPrint', true)); fclose(fid);
fid = fopen([base '.txt'], 'w');
fprintf(fid, 'VITAL sabotage check %s  %s\n', milestone, report.timestamp);
for r = rows
    if r.detected, s = 'DETECTED'; else, s = 'NOT DETECTED'; end
    fprintf(fid, '%-8s %-12s %-40s %s\n', r.id, s, r.file, strjoin(r.targets, ', '));
end
fprintf(fid, 'tree unchanged: %d   all detected: %d\n', report.treeUnchanged, report.allDetected);
fclose(fid);
end
