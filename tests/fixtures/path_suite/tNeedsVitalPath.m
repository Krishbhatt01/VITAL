classdef (TestTags = {'FIXTURE','M0'}) tNeedsVitalPath < vital.test.VitalTestCase
%TNEEDSVITALPATH  Resolves only if the +vital package is on the MATLAB path
%   (not merely in the current folder). Used to prove run_vital_tests sets
%   up its own path (FC-110).
    methods (Test)
        function vitalResolves(tc)
            tc.verifyExact(isfolder(vital.paths('root')), true, 'ANALYTIC', 'package resolves', 'Quantity', 'root');
        end
    end
end
