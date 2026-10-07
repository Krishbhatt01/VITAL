classdef (TestTags = {'M0'}) tSpecDocs < matlab.unittest.TestCase
%TSPECDOCS  M0: the specification documents exist, are complete, and agree
%   with the files they describe.

    properties
        Root
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Root = vital.paths('root');
        end
    end

    methods (Test)
        function requiredDocsExist(tc)
            req = struct( ...
                'CONVENTIONS',          {{'Frames','Units','Quaternion','Euler','Control sign','Corrections'}}, ...
                'DECISIONS',            {{'ADR-'}}, ...
                'FAILURE_CATALOGUE',    {{'| ID |'}}, ...
                'VERIFICATION_MATRIX',  {{'| Capability |'}}, ...
                'NESC_CASE_MATRIX',     {{'Band criterion'}});
            names = fieldnames(req);
            for k = 1:numel(names)
                f = fullfile(tc.Root, 'docs', [names{k} '.md']);
                vital.io.requireDeliverable(f);
                txt = fileread(f);
                tc.verifyGreaterThan(strlength(txt), 500, [names{k} ' is too short to be a specification']);
                for h = req.(names{k})
                    tc.verifyTrue(contains(txt, h{1}), sprintf('%s lacks "%s"', names{k}, h{1}));
                end
            end
        end

        function catalogueTestsExistOrPlanned(tc)
            % Rules in vital.io.checkCatalogue (tests/M0/tCatalogueRules.m): rows of a
            % CLOSED milestone (docs/MILESTONES.json) must name real tests; an open
            % milestone may keep PLANNED rows; a milestone not started must be PLANNED.
            f = fullfile(tc.Root, 'docs', 'FAILURE_CATALOGUE.md');
            vital.io.requireDeliverable(f);
            rows = vital.io.readFailureCatalogue(f);
            tc.assertNotEmpty(rows, 'failure catalogue has no rows');
            mf = fullfile(tc.Root, 'docs', 'MILESTONES.json');
            vital.io.requireDeliverable(mf);
            m = jsondecode(fileread(mf));
            problems = vital.io.checkCatalogue(rows, tc.Root, cellstr(m.closed));
            tc.verifyEmpty(problems, strjoin(string(problems), newline));
        end

        function catalogueCoversRequiredFailureModes(tc)
            f = fullfile(tc.Root, 'docs', 'FAILURE_CATALOGUE.md');
            vital.io.requireDeliverable(f);
            rows = vital.io.readFailureCatalogue(f);
            ids = string({rows.errorId});
            required = ["vital:notImplemented","vital:badInput","vital:env:altitudeOutOfRange", ...
                        "vital:airdata:zeroAirspeed","vital:sim:nanState","INFEASIBLE","NOT_CONVERGED", ...
                        "OUT_OF_DATA_ENVELOPE","vital:daveml:unsupportedElement", ...
                        "vital:rule:missingField","sabotage:patternNotFound"];
            for id = required
                tc.verifyTrue(any(ids == id), "failure catalogue lacks " + id);
            end
        end

        function ruleSchemaAcceptsValidRecord(tc)
            rec = vital.io.sampleRule();
            tc.verifyWarningFree(@() vital.io.validateRule(rec));
        end

        function ruleSchemaRejectsMissingCitation(tc)
            rec = vital.io.sampleRule();
            rec.source = rmfield(rec.source, 'paragraph');
            tc.verifyError(@() vital.io.validateRule(rec), 'vital:rule:missingField');
        end

        function ruleSchemaRejectsBadClass(tc)
            rec = vital.io.sampleRule();
            rec.class = 'MAYBE';
            tc.verifyError(@() vital.io.validateRule(rec), 'vital:rule:badValue');
        end

        function ruleSchemaRejectsNonMonotoneLevels(tc)
            rec = vital.io.sampleRule();
            rec.criterion.levels(1).min = 2;  rec.criterion.levels(1).max = 1;
            tc.verifyError(@() vital.io.validateRule(rec), 'vital:rule:badValue');
        end

        function manifestHashesMatch(tc)
            f = fullfile(vital.paths('data'), 'MANIFEST.json');
            vital.io.requireDeliverable(f);
            m = jsondecode(fileread(f));
            present = m.files(strcmp({m.files.status}, 'present'));
            tc.assertNotEmpty(present);
            for f = present(:)'
                p = fullfile(vital.paths('data'), f.path);
                tc.verifyTrue(isfile(p), ['manifest file missing: ' f.path]);
                if isfile(p)
                    tc.verifyEqual(vital.io.sha256File(p), f.sha256, ['hash mismatch: ' f.path]);
                end
            end
        end

        function nescCaseMatrixComplete(tc)
            f = fullfile(tc.Root, 'docs', 'NESC_CASE_MATRIX.json');
            vital.io.requireDeliverable(f);
            M = jsondecode(fileread(f));
            ids = string({M.cases.id});
            expected = ["1","2","3","4","5","6","7","8","9","10","11","12","13.1","13.2","13.3","13.4","15","16"];
            tc.verifyEqual(sort(ids), sort(expected), 'case list must match the NESC atmospheric cases 1-16');
            need = {'title','earth','gravity','atmosphere','ic','duration_s','csv_columns','sims','pages','band'};
            for c = M.cases(:)'
                for k = need
                    tc.verifyTrue(isfield(c, k{1}) && ~isempty(c.(k{1})), ...
                        sprintf('case %s lacks %s', c.id, k{1}));
                end
                if isfield(c, 'band') && ~isempty(c.band)
                    for b = c.band(:)'
                        tc.verifyTrue(isnumeric(b.floor) && isfinite(b.floor) && b.floor >= 0 && ...
                                      isnumeric(b.k) && isfinite(b.k) && b.k >= 0, ...
                            sprintf('case %s signal %s: band floor/k must be pre-registered numbers', c.id, b.signal));
                    end
                end
            end
        end
    end
end
