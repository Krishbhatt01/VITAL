function runTargetsToFile(root, targets, statusFile)
%RUNTARGETSTOFILE  Child-process side of the sabotage harness.
%   Runs the named tests ("TestClass/method") found under ROOT\tests and
%   writes {ran, results:[{name,passed}], error} to STATUSFILE. Always
%   writes the file, so the parent can tell "tests failed" (a detection)
%   from "the harness broke" (an error).
st = struct('ran', false, 'results', struct('name', {}, 'passed', {}), 'error', '');
try
    results = struct('name', {}, 'passed', {});
    for k = 1:numel(targets)
        parts = split(string(targets{k}), '/');
        hit = dir(fullfile(root, 'tests', '**', parts(1) + ".m"));
        suite = matlab.unittest.TestSuite.fromFile(fullfile(hit(1).folder, hit(1).name));
        suite = suite(endsWith(string({suite.Name}), "/" + parts(2)));
        if isempty(suite)
            error('sabotage:targetNotFound', 'target %s not found', targets{k});
        end
        res = matlab.unittest.TestRunner.withNoPlugins.run(suite);
        results(end+1) = struct('name', targets{k}, 'passed', all([res.Passed])); %#ok<AGROW>
    end
    st.results = results;
    st.ran = true;
catch err
    st.error = sprintf('%s: %s', err.identifier, err.message);
end
fid = fopen(statusFile, 'w');
fprintf(fid, '%s', jsonencode(st));
fclose(fid);
end
