classdef (TestTags = {'M1'}) tRunnerIntegrity < matlab.unittest.TestCase
%TRUNNERINTEGRITY  Defects found when the gate was run from a fresh MATLAB
%   session (2026-09-29): the runner depended on startup_vital, and test
%   files that failed to load were silently EXCLUDED, so a gate could run
%   44 of 123 tests and look complete.

    methods (Test)
        function excludedTestFileFailsGate(tc)
            % FC-111: a test file matlab.unittest cannot load must fail the gate.
            f = fullfile(vital.paths('tests'), 'fixtures', 'broken_suite');
            out = tempname; mkdir(out); c = onCleanup(@() rmdir(out, 's'));
            ws = warning('off', 'all'); cw = onCleanup(@() warning(ws));
            s = run_vital_tests('M0', 'Folder', f, 'IncludeFixtures', true, 'ReportDir', out, 'Quiet', true);
            tc.verifyFalse(s.gateOK, 'a gate with an excluded test file must not be OK');
            tc.verifyEqual(s.counts.EXCLUDED, 1);
            tc.verifyTrue(any(contains(string(s.excluded), 'tBrokenFixture.m')));
            j = jsondecode(fileread(fullfile(out, 'M0_green.json')));
            tc.verifyTrue(any(strcmp({j.tests.class}, 'EXCLUDED')), 'the report must list the excluded file');
        end

        function excludedFileFailsRedGateToo(tc)
            f = fullfile(vital.paths('tests'), 'fixtures', 'broken_suite');
            out = tempname; mkdir(out); c = onCleanup(@() rmdir(out, 's'));
            ws = warning('off', 'all'); cw = onCleanup(@() warning(ws));
            s = run_vital_tests('M0', 'Phase', 'red', 'Folder', f, 'IncludeFixtures', true, 'ReportDir', out, 'Quiet', true);
            tc.verifyFalse(s.gateOK);
        end

        function cleanSuiteHasNoExclusions(tc)
            f = fullfile(vital.paths('tests'), 'fixtures', 'path_suite');
            out = tempname; mkdir(out); c = onCleanup(@() rmdir(out, 's'));
            s = run_vital_tests('M0', 'Folder', f, 'IncludeFixtures', true, 'ReportDir', out, 'Quiet', true);
            tc.verifyEqual(s.counts.EXCLUDED, 0);
            tc.verifyTrue(s.gateOK);
        end

        function runnerWorksWithoutStartup(tc)
            % FC-110: a fresh MATLAB with the default path, cd'd to the VITAL root and
            % WITHOUT startup_vital, must still load and run VitalTestCase-based tests.
            root = vital.paths('root');
            out = tempname; mkdir(out); c = onCleanup(@() rmdir(out, 's'));
            status = fullfile(out, 'status.txt');
            cmd = sprintf(['restoredefaultpath; cd(''%s''); ' ...
                's = run_vital_tests(''M0'', ''Folder'', fullfile(''%s'',''tests'',''fixtures'',''path_suite''), ' ...
                '''IncludeFixtures'', true, ''ReportDir'', ''%s'', ''Quiet'', true); ' ...
                'fid = fopen(''%s'',''w''); fprintf(fid, ''%%d %%d %%d'', s.total, s.counts.PASS, s.counts.EXCLUDED); fclose(fid);'], ...
                root, root, out, status);
            [~, log] = system(sprintf('"%s" -batch "%s"', fullfile(matlabroot, 'bin', 'matlab'), cmd));
            tc.assertTrue(isfile(status), ['child MATLAB wrote no status: ' log]);
            v = sscanf(fileread(status), '%d');
            tc.verifyEqual(v(:).', [1 1 0], 'total / passed / excluded in a session without startup_vital');
        end
    end
end
