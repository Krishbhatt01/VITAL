classdef (TestTags = {'FIXTURE','M4'}) fxIncOld < matlab.unittest.TestCase
%FXINCOLD  Earlier-milestone fixture (M4) for tRunnerIncrements: always passes.
    methods (Test)
        function passes(tc), tc.verifyTrue(true); end
    end
end
