classdef (TestTags = {'FIXTURE','M0'}) tReadsReport < matlab.unittest.TestCase
%TREADSREPORT  Fixture test that reads a file under reports/ (as tCtrlSuggest
%   and tF16Uq do). Its tree is the copy the sabotage harness makes, so the
%   report must exist in that copy for the test to pass.
    methods (Test)
        function scaledReportValue(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            v = jsondecode(fileread(fullfile(root, 'reports', 'fq', 'value.json')));
            tc.verifyEqual(fxr.scaleValue(v.value), 6);
        end
    end
end
