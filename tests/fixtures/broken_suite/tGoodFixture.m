classdef (TestTags = {'FIXTURE','M0'}) tGoodFixture < matlab.unittest.TestCase
%TGOODFIXTURE  A valid fixture test that sits next to a broken one.
    methods (Test)
        function passes(tc), tc.verifyTrue(true); end
    end
end
