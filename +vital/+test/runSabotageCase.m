function r = runSabotageCase(root, sab, opts)
%RUNSABOTAGECASE  Apply one sabotage to a copy of ROOT; run its targets in a
%   separate MATLAB process; report whether the targets turned RED.
%
%   r.ran       true if the child process ran the targets and reported back
%   r.detected  true if at least one target FAILED (the tests can see the defect)
%   r.results   per-target {name, passed}
%   r.log       child process console output
%
%   Harness problems are errors, never detections:
%     sabotage:targetNotFound  a target test does not exist in the tree
%     sabotage:harnessFailed   the child process did not report results for
%                              every target
%   A separate process is used because two +vital trees on one path merge
%   and MATLAB caches function definitions, which would make the outcome
%   depend on load order.
arguments
    root (1,:) char
    sab (1,1) struct
    opts.KeepCopy (1,1) logical = false
end
root = regexprep(root, '[\\/]+$', '');
targets = cellstr(sab.targets);
for k = 1:numel(targets)
    findTarget(root, targets{k});      % errors sabotage:targetNotFound
end

dst = tempname;
if ~opts.KeepCopy, cleanupCopy = onCleanup(@() vital.test.removeTree(dst)); end
vital.test.applySabotage(root, dst, sab);
statusFile = fullfile(dst, 'sabotage_status.json');

% The child sees the copy first. A fixture tree without its own +vital
% package gets the real framework appended at the END of the path, so the
% copy's code always wins.
vitalRoot = vital.paths('root');
tlist = strjoin(strcat('''', targets, ''''), ',');
cmd = sprintf(['addpath(''%s''); if ~isfolder(fullfile(''%s'',''+vital'')), addpath(''%s'',''-end''); end; ' ...
    'vital.test.runTargetsToFile(''%s'', {%s}, ''%s'');'], dst, dst, vitalRoot, dst, tlist, statusFile);
exe = fullfile(matlabroot, 'bin', 'matlab');
oldData = getenv('VITAL_DATA_ROOT');
setenv('VITAL_DATA_ROOT', vital.paths('data'));
restoreEnv = onCleanup(@() setenv('VITAL_DATA_ROOT', oldData));
[~, out] = system(sprintf('"%s" -batch "%s"', exe, cmd));

r = struct('id', sab.id, 'ran', false, 'detected', false, 'results', [], 'log', out);
if ~isfile(statusFile)
    error('sabotage:harnessFailed', 'sabotage %s: child process wrote no status. Output:\n%s', sab.id, out);
end
st = jsondecode(fileread(statusFile));
if ~st.ran
    error('sabotage:harnessFailed', 'sabotage %s: child process failed: %s', sab.id, st.error);
end
res = st.results;
if numel(res) ~= numel(targets)
    error('sabotage:harnessFailed', 'sabotage %s: %d targets requested, %d reported', ...
        sab.id, numel(targets), numel(res));
end
r.ran = true;
r.results = res;
r.detected = any(~[res.passed]);
end

function findTarget(root, target)
parts = split(string(target), '/');
if numel(parts) ~= 2
    error('sabotage:targetNotFound', 'target "%s" must be "TestClass/method"', target);
end
hits = dir(fullfile(root, 'tests', '**', parts(1) + ".m"));
found = false;
for k = 1:numel(hits)
    txt = fileread(fullfile(hits(k).folder, hits(k).name));
    if ~isempty(regexp(txt, "function\s+(\w+\s*=\s*)?" + parts(2) + "\s*\(", 'once'))
        found = true; break;
    end
end
if ~found
    error('sabotage:targetNotFound', 'target %s not found under %s', target, fullfile(root, 'tests'));
end
end
