classdef (TestTags = {'FIXTURE'}) fxTagSelection < matlab.unittest.TestCase
%FXTAGSELECTION  One trivially passing test per milestone tag, used to check
%   that milestone selection is cumulative and that 'M1' does not match 'M10'.

    methods (Test, TestTags = {'M0'})
        function inM0(tc), tc.verifyTrue(true); end
    end
    methods (Test, TestTags = {'M1'})
        function inM1(tc), tc.verifyTrue(true); end
    end
    methods (Test, TestTags = {'M2'})
        function inM2(tc), tc.verifyTrue(true); end
    end
    methods (Test, TestTags = {'M3'})
        function inM3(tc), tc.verifyTrue(true); end
    end
    methods (Test, TestTags = {'M10'})
        function inM10(tc), tc.verifyTrue(true); end
    end
end
