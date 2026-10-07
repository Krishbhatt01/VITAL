function summary = run_vital_tests(milestone, opts)
%RUN_VITAL_TESTS  Run a milestone gate: every test tagged M0..Mk.
%
%   s = run_vital_tests('M3')                 green gate (default)
%   s = run_vital_tests('M3', 'Phase', 'red') red gate: new tests must fail
%                                             for the right reason
%   Options
%     'Phase'           'green' | 'red'
%     'Folder'          test root (default: <root>\tests, scanning only the
%                       M<k> subfolders, so fixtures are never discovered)
%     'IncludeFixtures' keep FIXTURE-tagged tests (runner self-tests only)
%     'ReportDir'       where M<k>_<phase>.txt/.json/.xml and
%                       M<k>_<phase>_provenance.json are written
%     'Quiet'           suppress console output
%     'Increment'       current-milestone test classes being built now (new:
%                       RED rules apply). With Increment or Baseline given,
%                       unlisted current-milestone classes are skipped, so a
%                       parallel increment's work in progress cannot break this
%                       gate. A full gate (neither given) runs every test.
%     'Baseline'        current-milestone classes already finished; treated
%                       like earlier milestones (PASS or REGRESSION)
%     'Tag'             appended to the report names: M<k>_<phase>_<Tag>.*
%
%   The returned summary has .gateOK. See vital.test.classifyResults for
%   the meaning of each class.
arguments
    milestone (1,:) char
    opts.Phase (1,:) char {mustBeMember(opts.Phase, {'red','green'})} = 'green'
    opts.Folder (1,:) char = ''
    opts.IncludeFixtures (1,1) logical = false
    opts.ReportDir (1,:) char = ''
    opts.Quiet (1,1) logical = false
    opts.Increment cell = {}
    opts.Baseline cell = {}
    opts.Tag (1,:) char = ''
end
% FC-110: never depend on startup_vital. matlab.unittest changes into the test
% folders while it builds the suite, so the +vital package must be on the PATH,
% not merely in the current folder.
addpath(fileparts(mfilename('fullpath')));
import matlab.unittest.TestSuite
mk = vital.test.milestoneNumber(milestone);
if isempty(opts.ReportDir), opts.ReportDir = vital.paths('reports'); end
if ~isfolder(opts.ReportDir), mkdir(opts.ReportDir); end

% ---- discover ---------------------------------------------------------------
if isempty(opts.Folder)
    testsRoot = vital.paths('tests');
    d = dir(testsRoot);
    d = d([d.isdir] & matches(string({d.name}), regexpPattern('^M\d+$')));
    folders = {};
    for k = 1:numel(d)
        if vital.test.milestoneNumber(d(k).name) <= mk
            folders{end+1} = fullfile(testsRoot, d(k).name); %#ok<AGROW>
        end
    end
else
    folders = {opts.Folder};
end
suite = matlab.unittest.Test.empty;
for k = 1:numel(folders)
    suite = [suite, TestSuite.fromFolder(folders{k}, 'IncludingSubfolders', true)]; %#ok<AGROW>
end
% FC-111: matlab.unittest EXCLUDES a test file it cannot load (e.g. a missing
% superclass) with only a warning. Every test file in the scanned folders must
% contribute to the suite; any file that does not is reported as EXCLUDED and
% fails the gate, so a gate can never pass with tests silently missing.
excluded = vital.test.findExcludedTestFiles(folders, suite);
suite = vital.test.selectMilestone(suite, milestone, 'IncludeFixtures', opts.IncludeFixtures);
[suite, notNew] = applyIncrement(suite, mk, opts.Increment, opts.Baseline);

% ---- run --------------------------------------------------------------------
base = fullfile(opts.ReportDir, sprintf('M%d_%s', mk, opts.Phase));
if ~isempty(opts.Tag), base = [base '_' opts.Tag]; end
runner = matlab.unittest.TestRunner.withNoPlugins;
runner.addPlugin(matlab.unittest.plugins.DiagnosticsRecordingPlugin);
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat([base '.xml']));
outer = vital.test.provenance('get');           % support nested use (runner self-tests)
vital.test.provenance('clear');
t0 = tic;
results = runner.run(suite);
elapsed = toc(t0);
vital.test.provenance('write', [base '_provenance.json']);
recs = vital.test.provenance('get');
vital.test.provenance('set', outer);

% ---- classify and report ------------------------------------------------------
[rows, summary] = vital.test.classifyResults(suite, results, milestone, opts.Phase, 'NotNew', notNew);
summary.increment = opts.Increment;
summary.baseline = opts.Baseline;
for k = 1:numel(excluded)
    rows(end+1) = struct('name', excluded{k}, 'milestone', '', 'isNew', false, ...
        'class', 'EXCLUDED', 'detail', 'test file failed to load; matlab.unittest excluded it'); %#ok<AGROW>
end
summary.counts.EXCLUDED = numel(excluded);
summary.excluded = excluded;
summary.total = numel(rows);
summary.gateOK = summary.gateOK && isempty(excluded);
summary.elapsed_s = elapsed;
summary.checksLogged = numel(recs);
summary.checksBySource = countSources(recs);
summary.files = struct('txt', [base '.txt'], 'json', [base '.json'], 'xml', [base '.xml'], ...
    'provenance', [base '_provenance.json']);
summary.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
summary.vitalVersion = vital.version();

j.summary = summary;
j.tests = rows(:);
fid = fopen([base '.json'], 'w');
fprintf(fid, '%s', jsonencode(j, 'PrettyPrint', true));
fclose(fid);

lines = strings(0);
lines(end+1) = sprintf('VITAL %s  gate %s (%s)  %s', summary.vitalVersion, milestone, upper(opts.Phase), summary.timestamp);
lines(end+1) = sprintf('%-80s %s', 'test', 'class');
for r = rows(:)'
    lines(end+1) = sprintf('%-80s %s', r.name, r.class); %#ok<AGROW>
end
c = summary.counts;
lines(end+1) = "";
lines(end+1) = sprintf(['TOTAL %d | PASS %d FAIL %d | RED_EXPECTED %d RED_UNEXPECTED %d ' ...
    'RED_SUSPICIOUS %d VACUOUS %d REGRESSION %d | EXCLUDED %d | checks logged %d | %.1f s'], ...
    summary.total, c.PASS, c.FAIL, c.RED_EXPECTED, c.RED_UNEXPECTED, c.RED_SUSPICIOUS, ...
    c.VACUOUS, c.REGRESSION, c.EXCLUDED, summary.checksLogged, elapsed);
src = summary.checksBySource;
lines(end+1) = sprintf('checks by source: PUB %d  INDEP %d  ANALYTIC %d  REG %d', ...
    src.PUB, src.INDEP, src.ANALYTIC, src.REG);
if ~isempty(summary.needsReview)
    lines(end+1) = "needs review (justify in gate report): " + strjoin(string(summary.needsReview), ', ');
end
failing = rows(~ismember({rows.class}, {'PASS','RED_EXPECTED'}));
for r = failing(:)'
    lines(end+1) = sprintf('  [%s] %s: %s', r.class, r.name, r.detail); %#ok<AGROW>
end
if summary.gateOK, lines(end+1) = "GATE OK"; else, lines(end+1) = "GATE NOT OK"; end
fid = fopen([base '.txt'], 'w');
fprintf(fid, '%s\n', lines);
fclose(fid);
if ~opts.Quiet, fprintf('%s\n', lines); end
end

function [suite, notNew] = applyIncrement(suite, mk, inc, base)
% Restrict the current milestone's tests to Increment + Baseline classes.
notNew = {};
if isempty(inc) && isempty(base), return; end
cls = extractBefore(string({suite.Name}) + "/", "/");
cur = false(size(suite));
for i = 1:numel(suite)
    tags = string(suite(i).Tags);
    nums = vital.test.milestoneNumber(tags(matches(tags, regexpPattern('^M\d+$'))), 'Quiet', true);
    cur(i) = ~isempty(nums) && max(nums) == mk;
end
listed = string([inc(:); base(:)]);
bad = setdiff(listed, unique(cls(cur)));
if ~isempty(bad)
    error('vital:test:unknownIncrement', ['not a test class of milestone M%d: %s ' ...
        '(Increment/Baseline name current-milestone test classes only)'], mk, strjoin(bad, ', '));
end
suite = suite(~cur | ismember(cls, listed));
notNew = cellstr(string(base));
end

function s = countSources(recs)
s = struct('PUB', 0, 'INDEP', 0, 'ANALYTIC', 0, 'REG', 0);
for k = 1:numel(recs)
    f = char(recs(k).source);
    if isfield(s, f), s.(f) = s.(f) + 1; end
end
end
