classdef (TestTags = {'FIXTURE','M0'}) tAddOne < matlab.unittest.TestCase
%TADDONE  Fixture test targeted by the sabotage harness test.
    methods (Test)
        function addsOne(tc)
            tc.verifyEqual(fxs.addOne(1), 2);
        end
    end
end
