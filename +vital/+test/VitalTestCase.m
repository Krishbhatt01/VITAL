classdef VitalTestCase < matlab.unittest.TestCase
%VITALTESTCASE  matlab.unittest base class whose checks record provenance.
%
%   Every numeric claim VITAL makes is checked by one of these methods, and
%   each check records WHERE the expected value comes from:
%
%     source   PUB       a published value (NESC TM, MIL-F-8785C, US76 ...)
%              INDEP     an independent implementation (e.g. Aerospace Toolbox)
%              ANALYTIC  a closed-form result derived in the test
%              REG       a pre-registered expectation (mutation tests)
%     citation free text: document + page/paragraph, or the derivation
%
%   Methods (all record to vital.test.provenance):
%     verifyTol(act, exp, tol, mode, source, citation, 'Quantity',q,'Unit',u)
%         mode 'abs': |act-exp| <= tol   (elementwise)
%         mode 'rel': |act-exp| <= tol*|exp|; exp must be non-zero
%         The modes are exclusive: MATLAB's verifyEqual passes when EITHER
%         AbsTol or RelTol is met, which would hide a wrong tolerance.
%         Any non-finite actual value FAILS (verifyEqual(NaN,NaN) passes).
%     verifyWithin(act, lo, hi, source, citation, ...)   lo <= act <= hi
%     verifyExact(act, exp, source, citation, ...)       isequal(act, exp)
%
%   Slack is the margin to failure in the check's own units: tol - error for
%   verifyTol, distance to the nearer bound for verifyWithin (negative when
%   the check fails). This follows the X57TestCase idiom from AAMF.

    properties (Constant, Hidden)
        SOURCES = ["PUB","INDEP","ANALYTIC","REG"]
    end

    methods
        function verifyTol(tc, actual, expected, tol, mode, source, citation, opts)
            arguments
                tc
                actual {mustBeNumeric}
                expected {mustBeNumeric}
                tol (1,1) {mustBeNumeric, mustBeNonnegative}
                mode (1,:) char
                source (1,:) char
                citation (1,:) char
                opts.Quantity (1,:) char = ''
                opts.Unit (1,:) char = ''
            end
            tc.checkSource(source);
            if ~any(strcmp(mode, {'abs','rel'}))
                error('vital:test:badMode', 'verifyTol mode must be ''abs'' or ''rel'', not ''%s''', mode);
            end
            actual = double(actual); expected = double(expected);
            if ~isequal(size(actual), size(expected)) && ~isscalar(expected)
                error('vital:test:sizeMismatch', 'actual is %s but expected is %s', ...
                    mat2str(size(actual)), mat2str(size(expected)));
            end
            err = abs(actual - expected);
            switch mode
                case 'abs'
                    allowed = tol * ones(size(err));
                case 'rel'
                    if any(expected(:) == 0)
                        error('vital:test:relZeroExpected', ...
                            'relative tolerance is undefined for a zero expected value; use ''abs''');
                    end
                    allowed = tol .* abs(expected) .* ones(size(err));
            end
            finiteOK = all(isfinite(actual(:)));
            slackVec = allowed - err;
            slack = min(slackVec(:));
            if ~finiteOK, slack = -Inf; end
            pass = finiteOK && all(err(:) <= allowed(:));
            tc.record(opts.Quantity, actual, expected, tol, mode, opts.Unit, source, citation, pass, slack);
            if ~finiteOK
                msg = sprintf('%s: actual value is not finite (%s)', opts.Quantity, mat2str(actual, 6));
            else
                [~, iw] = min(slackVec(:));
                msg = sprintf('%s: |%.12g - %.12g| = %.3g vs %s tolerance %.3g [%s: %s]', ...
                    opts.Quantity, actual(iw), expected(min(iw, numel(expected))), err(iw), ...
                    mode, allowed(iw), source, citation);
            end
            tc.verifyTrue(pass, msg);
        end

        function verifyWithin(tc, actual, lo, hi, source, citation, opts)
            arguments
                tc
                actual {mustBeNumeric}
                lo (1,1) {mustBeNumeric}
                hi (1,1) {mustBeNumeric}
                source (1,:) char
                citation (1,:) char
                opts.Quantity (1,:) char = ''
                opts.Unit (1,:) char = ''
            end
            tc.checkSource(source);
            if ~(lo <= hi)
                error('vital:test:badBounds', 'verifyWithin needs lo <= hi');
            end
            actual = double(actual);
            finiteOK = all(isfinite(actual(:)));
            slack = min(min(actual(:) - lo, hi - actual(:)));
            if ~finiteOK, slack = -Inf; end
            pass = finiteOK && slack >= 0;
            tc.record(opts.Quantity, actual, [lo hi], NaN, 'within', opts.Unit, source, citation, pass, slack);
            tc.verifyTrue(pass, sprintf('%s = %s not within [%.12g, %.12g] [%s: %s]', ...
                opts.Quantity, mat2str(actual, 8), lo, hi, source, citation));
        end

        function verifyExact(tc, actual, expected, source, citation, opts)
            arguments
                tc
                actual
                expected
                source (1,:) char
                citation (1,:) char
                opts.Quantity (1,:) char = ''
                opts.Unit (1,:) char = ''
            end
            tc.checkSource(source);
            pass = isequal(actual, expected);
            tc.record(opts.Quantity, actual, expected, 0, 'exact', opts.Unit, source, citation, pass, double(pass) - 1);
            tc.verifyTrue(pass, sprintf('%s: expected exactly %s [%s: %s]', ...
                opts.Quantity, vital.test.VitalTestCase.show(expected), source, citation));
        end
    end

    methods (Access = private)
        function checkSource(tc, source)
            if ~any(source == tc.SOURCES)
                error('vital:test:badSource', 'source tag must be one of %s, not "%s"', ...
                    strjoin(tc.SOURCES, '/'), source);
            end
        end

        function record(~, quantity, actual, expected, tol, mode, unit, source, citation, pass, slack)
            st = dbstack(2);                     % 1 = record, 2 = verifyX, 3 = the test method
            if isempty(st), where = ''; else, where = st(1).name; end
            vital.test.provenance('add', struct('test', where, 'quantity', quantity, ...
                'actual', vital.test.VitalTestCase.storable(actual), ...
                'expected', vital.test.VitalTestCase.storable(expected), ...
                'tol', tol, 'mode', mode, 'unit', unit, 'source', source, ...
                'citation', citation, 'pass', logical(pass), 'slack', slack));
        end
    end

    methods (Static, Access = private)
        function v = storable(v)
            if ~(isnumeric(v) || islogical(v) || ischar(v) || isstring(v))
                v = vital.test.VitalTestCase.show(v);
            end
        end

        function s = show(v)
            if ischar(v) || isstring(v), s = char(v);
            elseif isnumeric(v) || islogical(v), s = mat2str(v, 8);
            else, s = class(v);
            end
        end
    end
end
