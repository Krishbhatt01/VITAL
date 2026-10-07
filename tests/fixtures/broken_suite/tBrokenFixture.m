classdef (TestTags = {'FIXTURE','M0'}) tBrokenFixture < some.missing.SuperClass
%TBROKENFIXTURE  Deliberately broken: its superclass does not exist, so
%   matlab.unittest EXCLUDES the file with only a warning. The VITAL runner
%   must turn that into a gate failure (FC-111).
    methods (Test)
        function neverRuns(tc), tc.verifyTrue(false); end
    end
end
