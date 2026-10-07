classdef (TestTags = {'FIXTURE','M1'}) fxClassifyNew < matlab.unittest.TestCase
%FXCLASSIFYNEW  Synthetic tests belonging to the milestone under test (M1).
%   Used only by tRunnerClassification. Each method produces one known
%   outcome so the RED/GREEN classifier can be checked against it.

    methods (Test)
        function passes(tc)
            tc.verifyTrue(true);
        end

        function failsVerify(tc)
            tc.verifyEqual(1, 2);
        end

        function errorsNotImplemented(~)
            vital.notImplemented('fxClassifyNew.errorsNotImplemented');
        end

        function errorsOther(~)
            error('fixture:boom', 'An error that is not vital:notImplemented.');
        end

        function verifyErrorSeesNotImplemented(tc)
            % The function under test is still a stub, so verifyError sees
            % vital:notImplemented instead of the identifier it expects.
            tc.verifyError(@() vital.notImplemented('stub'), 'vital:badInput');
        end
    end
end
