classdef (TestTags = {'FIXTURE','M5'}) fxIncDone < matlab.unittest.TestCase
%FXINCDONE  Current-milestone fixture already completed (a Baseline increment): passes.
    methods (Test)
        function passes(tc), tc.verifyTrue(true); end
    end
end
