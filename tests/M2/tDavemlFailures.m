classdef (TestTags = {'M2'}) tDavemlFailures < vital.test.DavemlCase
%TDAVEMLFAILURES  M2: malformed or unsupported DAVE-ML is rejected with an
%   exact identifier, never read silently (FC-201 ... FC-208).

    methods (Test)
        function unsupportedElementIsReportedWithLocation(tc)
            f = tc.fixture('unsupported.dml');
            tc.verifyError(@() vital.daveml.read(f), 'vital:daveml:unsupportedElement');
            msg = '';
            try, vital.daveml.read(f); catch err, msg = err.message; end
            tc.verifySubstring(msg, 'factorial', 'the message names the unsupported element');
            tc.verifySubstring(msg, 'varID="f"', 'the message locates it (variableDef)');
        end

        function truncatedFileIsParseError(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('truncated.dml')), 'vital:daveml:parseError');
        end

        function nonMonotonicBreakpointsRejected(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('nonmono.dml')), 'vital:daveml:nonMonotonicBreakpoints');
        end

        function tableSizeMismatchRejected(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('badsize.dml')), 'vital:daveml:tableSize');
        end

        function missingUnitsRejected(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('nounits.dml')), 'vital:daveml:missingUnits');
        end

        function undefinedVariableRejected(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('undefined.dml')), 'vital:daveml:undefinedVariable');
        end

        function missingFileRejected(tc)
            tc.verifyError(@() vital.daveml.read(tc.fixture('no_such_file.dml')), 'vital:daveml:fileNotFound');
        end
    end
end
