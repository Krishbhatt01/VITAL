classdef (TestTags = {'M0'}) tCatalogueRules < vital.test.VitalTestCase
%TCATALOGUERULES  When must a failure-catalogue row name a real test?
%   (Changed 2026-09-29, before M5, so parallel increments of one milestone
%   do not block each other.)
%     closed milestone (docs/MILESTONES.json)  -> must name an existing test method
%     open milestone, tests/M<k> exists       -> PLANNED, or an existing test method
%     milestone not started                   -> PLANNED
%   vital.io.checkCatalogue(rows, root, closed) returns one message per violation.

    properties
        Root
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Root = vital.paths('root');
        end
    end

    methods (Access = private)
        function r = row(~, ms, test)
            r = struct('id', "FC-X", 'milestone', string(ms), 'mode', "m", 'detection', "d", ...
                'errorId', "e", 'test', string(test));
        end
    end

    methods (Test)
        function closedMilestonePlannedRowIsAProblem(tc)
            p = vital.io.checkCatalogue(tc.row('M0', 'PLANNED (M0)'), tc.Root, {'M0'});
            tc.verifyNumElements(p, 1);
        end

        function closedMilestoneRealTestIsFine(tc)
            p = vital.io.checkCatalogue(tc.row('M0', 'tests/M0/tRunnerClassification.m#notImplementedIsRedExpected'), tc.Root, {'M0'});
            tc.verifyEmpty(p);
        end

        function openMilestoneMayBePlanned(tc)
            p = vital.io.checkCatalogue(tc.row('M1', 'PLANNED (M1)'), tc.Root, {'M0'});
            tc.verifyEmpty(p, 'tests/M1 exists but M1 is not closed: PLANNED is allowed');
        end

        function openMilestoneNamedTestMustExist(tc)
            p = vital.io.checkCatalogue(tc.row('M1', 'tests/M1/tFrames.m#noSuchMethod'), tc.Root, {'M0'});
            tc.verifyNumElements(p, 1);
            p = vital.io.checkCatalogue(tc.row('M1', 'tests/M1/tNoSuchFile.m#x'), tc.Root, {'M0'});
            tc.verifyNumElements(p, 1);
        end

        function notStartedMilestoneMustBePlanned(tc)
            p = vital.io.checkCatalogue(tc.row('M99', 'tests/M99/tX.m#y'), tc.Root, {'M0'});
            tc.verifyNumElements(p, 1);
            p = vital.io.checkCatalogue(tc.row('M99', 'PLANNED (M99)'), tc.Root, {'M0'});
            tc.verifyEmpty(p);
        end

        function milestonesFileRecordsClosedGates(tc)
            f = fullfile(tc.Root, 'docs', 'MILESTONES.json');
            vital.io.requireDeliverable(f);
            m = jsondecode(fileread(f));
            closed = cellstr(m.closed);
            tc.verifyTrue(all(ismember({'M0','M1','M2','M3','M4'}, closed)), 'M0-M4 gates were closed');
            for k = 1:numel(closed)
                tc.verifyTrue(isfolder(fullfile(tc.Root, 'tests', closed{k})), [closed{k} ' closed without a tests folder']);
            end
        end
    end
end
