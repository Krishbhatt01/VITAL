classdef (TestTags = {'FIXTURE','M0'}) fxClassifyOld < matlab.unittest.TestCase
%FXCLASSIFYOLD  Synthetic tests from an EARLIER milestone (M0) than the one
%   under test (M1). A pass is a normal regression pass; a failure is a
%   regression and must invalidate the gate.

    methods (Test)
        function passesOld(tc)
            tc.verifyTrue(true);
        end

        function failsOld(tc)
            tc.verifyEqual(1, 2);
        end
    end
end
