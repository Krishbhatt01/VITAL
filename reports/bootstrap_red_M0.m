% BOOTSTRAP_RED_M0  RED run for M0 using plain matlab.unittest, because the
% VITAL runner (run_vital_tests) is itself under test in M0 and is a stub.
cd(fileparts(fileparts(mfilename('fullpath')))); startup_vital;
import matlab.unittest.*
suite = TestSuite.fromFolder(fullfile(pwd,'tests','M0'));
runner = TestRunner.withNoPlugins;
runner.addPlugin(plugins.DiagnosticsRecordingPlugin);
res = runner.run(suite);
fid = fopen(fullfile(pwd,'reports','M0_red_bootstrap.txt'),'w');
nExp = 0; nOther = 0; nPass = 0;
for k = 1:numel(res)
    r = res(k); why = '';
    recs = r.Details.DiagnosticRecord;
    txt = strjoin(arrayfun(@(d) string(d.Report), recs), newline);
    if r.Passed
        cls = 'VACUOUS(pass)'; nPass = nPass + 1;
    elseif contains(txt, 'vital:notImplemented')
        cls = 'RED_EXPECTED'; nExp = nExp + 1;
        m = regexp(txt, '[\w.]+ is not implemented yet', 'match', 'once'); why = m;
    else
        cls = 'RED_OTHER'; nOther = nOther + 1;
        why = regexprep(extractBefore(txt + " ", min(strlength(txt)+1, 400)), '\s+', ' ');
    end
    fprintf(fid, '%-70s %-14s %s\n', r.Name, cls, why);
    fprintf('%-70s %-14s %s\n', r.Name, cls, why);
end
fprintf(fid, '\nTOTAL %d   RED_EXPECTED %d   RED_OTHER %d   PASS(vacuous) %d\n', numel(res), nExp, nOther, nPass);
fprintf('\nTOTAL %d   RED_EXPECTED %d   RED_OTHER %d   PASS(vacuous) %d\n', numel(res), nExp, nOther, nPass);
fclose(fid);
