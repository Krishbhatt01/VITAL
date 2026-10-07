classdef (TestTags = {'M6'}) tFqRules < vital.test.VitalTestCase
%TFQRULES  M6: curated MIL-F-8785C Class IV rule records, their traceability
%   to the candidate file and to the extract, the coverage table and the
%   registered condition space.
%
%   Deliverables (rules/mil_f_8785c/):
%     records/*.json          one record per (sub-paragraph, metric, Level,
%                             Category), vital.io.validateRule-valid
%     coverage.json           every criterion VITAL does NOT assess, with class
%                             and reason (never silently omitted)
%     conditions_f16.json     condition space and category policy
%
%   PRE-REGISTERED expectations (written before any record existed):
%   1. The curated set is exactly the in-scope candidates with a numeric bound
%      (docs/MIL8785C_EXTRACT.md section 5), with "All", "A&C" and "B&C"
%      expanded to one record per Category, and Category A of 3.3.1.1 split
%      into the CO/GA row and the other-phase row (extract 6.2 item 8):
%        3.2.1.1    T2_speed_divergence_s L3 x {A,B,C}                        3
%        3.2.1.2    zeta_p L1, L2; T2_phugoid_s L3 x {A,B,C}                  9
%        3.2.2.1.1  A: CAP L1-3, omega_nsp L1-2; B: CAP L1-3;
%                   C: CAP L1-3, omega_nsp L1-3, n_alpha L1-2                16
%        3.2.2.1.2  zeta_sp L1-3 x {A,B,C}                                    9
%        3.3.1.1    groups A-COGA, A-other, B, C: zeta_d 12, zeta_d_omega_nd 7,
%                   omega_nd 12                                              31
%        3.3.1.2    tau_R_s L1-3 x {A,B,C}                                    9
%        3.3.1.3    spiral_T2_s L1-3 x {A,B,C}                                9
%        3.3.1.4    coupled_roll_spiral_present L1-3 (A-COGA);
%                   zeta_RS_omega_nRS L1-3 x {B,C}                            9
%                                                                     total  95
%      Candidates in these paragraphs with no bound (min and max null: the
%      Figure 1 Level 3 omega floor, the Figure 3 Level 3 n/alpha floor and the
%      two "-" cells of the Table VI zeta_d*omega_nd column) are NOT curated and
%      appear in the coverage table as NO-REQUIREMENT.
%   2. Every bound equals, exactly, the bound of the candidate record the
%      record names (source.candidate_id), for the same metric, Level, page and
%      paragraph, and the candidate's category covers the record's category.
%   3. Every finite bound appears as a number in source.extract_quote, and the
%      quote is a verbatim substring of the extract section of its paragraph.
%      The Table VI increment (0.014 / 0.009 per (rad/s)^2 above 20 (rad/s)^2)
%      is traced the same way. The one exception is the boolean prohibition of
%      3.3.1.4 (class Q-PROXY), encoded as present <= 0 with no number to quote.
%   4. Strict inequalities follow the spec wording: 3.3.1.1 ("shall exceed the
%      minimum values", all rows), 3.3.1.3 ("shall be greater than"), 3.3.1.4
%      zeta_RS*omega_nRS ("exceeds") and the Figure 3 Level 3 note ("SHALL
%      ALWAYS BE GREATER THAN 0.6"). Every other bound is inclusive.
%   5. Every one of the 235 candidates is either curated (named by exactly the
%      records of pre-registration 1) or listed in coverage.json, never both;
%      every coverage entry has a class in {OUT-OF-SIM, PILOT, NOT-IMPLEMENTED,
%      NO-REQUIREMENT} and a reason. The qualitative paragraphs of extract 6.3 H
%      that have no candidate record (3.2.1.1.2, 3.2.2.2, 3.2.2.3, 3.3.2.1,
%      3.3.3, 3.3.4.4) are listed as PILOT.
%   6. The condition space is registered: Categories A and B are assessed and
%      Category C is NOT assessed (the NESC F-16 has no gear or flap
%      configuration, so no terminal-phase configuration exists), with a
%      stated reason.
%   REVISION 2026-10-05 (review R2, coordinator decisions B1, M1, M2, M4).
%   Items 1, 2, 3 and 5 above are kept as first registered. They are
%   SUPERSEDED, not failed physics: the curated set grows by 23 interpreted
%   records (registered in tests/M6/tFqRulesR2.m, verified against the PDF
%   page images there): 3.2.1.1 L1-L2 speed_divergence_rate_1_s (6), 3.2.2.2
%   lon_divergence_rate_1_s (9), 3.3.1.4 Category A other phases (3), and the
%   Table VI zeta_d_omega_nd Level 3 (4) and Level 1 CO/GA (1) minima with
%   their increments. New counts: total 118; 3.3.1.1 zeta_d_omega_nd 12;
%   3.3.1.4 coupled_roll_spiral_present 6. Interpreted records (non-empty
%   source.interpretation) are exempt from items 2-3 only (their bound is an
%   interpretation, not a transcription); the two Table VI "-" candidates
%   are now curated, so they leave the NO-REQUIREMENT list of item 5; 3.2.2.2
%   is no longer PILOT (controls fixed: curated; controls free and the
%   force/deflection sense: OUT-OF-SIM).
%   7. Failure modes: a record without a citation is rejected
%      (vital:rule:missingField), a record whose metric has no extractor is
%      rejected (vital:fq:unknownMetric), an empty folder is vital:fq:noRules and
%      duplicate ids are vital:fq:badRule.

    properties
        Root
        RecDir
    end

    methods (TestMethodSetup)
        function locate(tc)
            tc.Root = vital.paths('root');
            tc.RecDir = fullfile(vital.paths('rules'), 'mil_f_8785c', 'records');
        end
    end

    methods (Access = private)
        function R = records(tc)
            vital.io.requireDeliverable(fullfile(tc.RecDir, 'MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA.json'));
            R = vital.fq.loadRules(tc.RecDir);
        end

        function C = candidates(~)
            f = fullfile(vital.paths('rules'), 'mil_f_8785c', 'candidates_from_extract.json');
            C = jsondecode(fileread(f));
            if ~iscell(C), C = num2cell(C); end
        end
    end

    methods (Static, Access = private)
        function s = section(txt, paragraph)
            % extract text from the heading that names the paragraph to the next heading
            lines = splitlines(string(txt));
            isHead = startsWith(lines, "#");
            k0 = find(isHead & startsWith(lines, "### " + paragraph + " "), 1);
            if isempty(k0)
                k0 = find(isHead & contains(lines, " and " + paragraph + " "), 1);
            end
            if isempty(k0), s = ""; return; end
            k1 = find(isHead((k0+1):end) & ~startsWith(lines((k0+1):end), "#### "), 1) + k0;
            if isempty(k1), k1 = numel(lines) + 1; end
            s = strjoin(lines(k0:k1-1), newline);
        end

        function v = numbers(s)
            tok = regexp(char(s), '(?<![\d.])(\d+\.\d*|\.\d+|\d+)', 'match');
            v = str2double(tok);
        end

        function tf = interpreted(r)
            tf = isfield(r.record.source, 'interpretation') && ~isempty(r.record.source.interpretation);
        end

        function cats = expand(cat)
            switch cat
                case 'All', cats = {'A', 'B', 'C'};
                case 'A&C', cats = {'A', 'C'};
                case 'B&C', cats = {'B', 'C'};
                case 'A-CO/GA', cats = {'A'};
                otherwise, cats = {cat};
            end
        end
    end

    methods (Test)
        function recordsExistAndValidate(tc)
            R = tc.records();
            files = dir(fullfile(tc.RecDir, '*.json'));
            for k = 1:numel(files)
                raw = jsondecode(fileread(fullfile(files(k).folder, files(k).name)));
                vital.io.validateRule(raw);              % errors on any schema violation
                tc.verifyEqual([raw.id '.json'], files(k).name, 'file name = id');
                tc.verifyNumElements(raw.criterion.levels, 1, [raw.id ': one Level per record']);
            end
            tc.verifyExact(numel(R), 118, 'REG', 'pre-registration 1 as revised 2026-10-05 (class header)', 'Quantity', 'number of curated records');
            tc.verifyExact(numel(unique({R.id})), numel(R), 'ANALYTIC', 'ids are unique', 'Quantity', 'unique ids');
            [names, ~] = vital.fq.metricNames();
            tc.verifyTrue(all(ismember({R.metric}, names)), 'every record metric has an extractor');
        end

        function curatedSetMatchesRegistration(tc)
            R = tc.records();
            reg = {'3.2.1.1', 'T2_speed_divergence_s', 3; '3.2.1.2', 'zeta_p', 6; '3.2.1.2', 'T2_phugoid_s', 3; ...
                '3.2.2.1.1', 'CAP', 9; '3.2.2.1.1', 'omega_nsp_rad_s', 5; '3.2.2.1.1', 'n_alpha_g_per_rad', 2; ...
                '3.2.2.1.2', 'zeta_sp', 9; '3.3.1.1', 'zeta_d', 12; '3.3.1.1', 'zeta_d_omega_nd_rad_s', 12; ...
                '3.3.1.1', 'omega_nd_rad_s', 12; '3.3.1.2', 'tau_R_s', 9; '3.3.1.3', 'spiral_T2_s', 9; ...
                '3.3.1.4', 'coupled_roll_spiral_present', 6; '3.3.1.4', 'zeta_RS_omega_nRS_rad_s', 6; ...
                '3.2.1.1', 'speed_divergence_rate_1_s', 6; '3.2.2.2', 'lon_divergence_rate_1_s', 9};
            for k = 1:size(reg, 1)
                n = sum(strcmp({R.paragraph}, reg{k, 1}) & strcmp({R.metric}, reg{k, 2}));
                tc.verifyExact(n, reg{k, 3}, 'REG', 'pre-registration 1', 'Quantity', sprintf('%s %s records', reg{k, 1}, reg{k, 2}));
            end
            groups = {'3.3.1.1-CatA-COGA', '3.3.1.1-CatA-other', '3.3.1.1-CatB', '3.3.1.1-CatC', ...
                '3.3.1.4-CatA-COGA', '3.3.1.4-CatB', '3.3.1.4-CatC', '3.2.2.1.1-CatA', '3.2.2.1.1-CatB', '3.2.2.1.1-CatC', ...
                '3.3.1.4-CatA-other', '3.2.2.2-CatA', '3.2.2.2-CatB', '3.2.2.2-CatC'};
            tc.verifyTrue(all(ismember(groups, {R.group})), 'registered groups present');
        end

        function recordBoundsTraceToCandidates(tc)
            R = tc.records();
            C = tc.candidates();
            cid = cellfun(@(c) c.id, C, 'UniformOutput', false);
            for k = 1:numel(R)
                r = R(k);
                if tFqRules.interpreted(r)
                    continue    % revision 2026-10-05: verified in tFqRulesR2/interpretedRecordsRegistered
                end
                j = find(strcmp(cid, r.candidate_id));
                tc.assertNumElements(j, 1, [r.id ': candidate ' r.candidate_id ' must exist once']);
                c = C{j};
                L = c.criterion.levels(1);
                tc.verifyEqual(c.metric, r.metric, [r.id ': metric']);
                tc.verifyEqual(c.source.paragraph, r.paragraph, [r.id ': paragraph']);
                tc.verifyEqual(c.source.page, r.page, [r.id ': page']);
                tc.verifyEqual(L.level, r.level, [r.id ': level']);
                tc.verifyTrue(ismember(r.category, tFqRules.expand(L.category)), [r.id ': category covered by ' L.category]);
                lo = -Inf; hi = Inf;
                if ~isempty(L.min), lo = L.min; end
                if ~isempty(L.max), hi = L.max; end
                if strcmp(r.class, 'Q-PROXY')
                    tc.verifyExact([r.lo r.hi], [-Inf 0], 'ANALYTIC', 'boolean prohibition encoded as present <= 0', ...
                        'Quantity', [r.id ' bounds']);
                else
                    tc.verifyExact([r.lo r.hi], [lo hi], 'PUB', sprintf('%s (MIL-F-8785C %s p.%s), candidate %s', ...
                        'candidates_from_extract.json', r.paragraph, r.page, r.candidate_id), 'Quantity', [r.id ' bounds']);
                end
                apx = isfield(L, 'approximate') && isequal(L.approximate, true);
                tc.verifyEqual(r.approximate, apx, [r.id ': approximate flag follows the candidate']);
                if r.incr.has
                    tc.verifySubstring(c.notes, sprintf('%g', r.incr.slope), [r.id ': increment slope in candidate notes']);
                    tc.verifySubstring(c.notes, sprintf('- %g', r.incr.threshold), [r.id ': increment threshold in notes']);
                end
            end
        end

        function recordBoundsTraceToExtractText(tc)
            R = tc.records();
            txt = fileread(fullfile(tc.Root, 'docs', 'MIL8785C_EXTRACT.md'), 'Encoding', 'UTF-8');
            for k = 1:numel(R)
                r = R(k);
                sec = tFqRules.section(txt, r.paragraph);
                tc.assertNotEqual(sec, "", [r.id ': extract section for ' r.paragraph]);
                q = r.quote;
                tc.verifyTrue(contains(sec, q), sprintf('%s: quote not found verbatim in extract section %s: "%s"', r.id, r.paragraph, q));
                nums = tFqRules.numbers(q);
                for b = [r.lo r.hi]
                    if isfinite(b) && ~strcmp(r.class, 'Q-PROXY') && ~tFqRules.interpreted(r)
                        tc.verifyTrue(any(abs(nums - b) <= 1e-12 * max(1, abs(b))), ...
                            sprintf('%s: bound %g not in quote "%s"', r.id, b, q));
                    end
                end
                if r.incr.has
                    tc.verifyTrue(contains(sec, r.incr.quote), [r.id ': increment quote in extract']);
                    n2 = tFqRules.numbers(r.incr.quote);
                    tc.verifyTrue(any(abs(n2 - r.incr.slope) < 1e-12) && any(abs(n2 - r.incr.threshold) < 1e-12), ...
                        [r.id ': increment numbers in quote']);
                end
            end
        end

        function strictnessFollowsSpecWording(tc)
            R = tc.records();
            for k = 1:numel(R)
                r = R(k);
                expStrict = any(strcmp(r.paragraph, {'3.3.1.1', '3.3.1.3'})) || ...
                    strcmp(r.metric, 'zeta_RS_omega_nRS_rad_s') || ...
                    (strcmp(r.paragraph, '3.2.2.1.1') && strcmp(r.metric, 'omega_nsp_rad_s') && strcmp(r.category, 'C') && r.level == 3);
                tc.verifyExact(r.strict, expStrict, 'PUB', sprintf('MIL-F-8785C %s wording (pre-registration 4)', r.paragraph), ...
                    'Quantity', [r.id ' strict']);
            end
        end

        function everyCandidateCuratedOrCovered(tc)
            R = tc.records();
            C = tc.candidates();
            vital.io.requireDeliverable(fullfile(vital.paths('rules'), 'mil_f_8785c', 'coverage.json'));
            cov = vital.fq.loadCoverage();
            cid = cellfun(@(c) c.id, C, 'UniformOutput', false);
            tc.verifyExact(numel(cid), 235, 'PUB', 'docs/MIL8785C_EXTRACT.md section 5: 235 records', 'Quantity', 'candidates');
            curated = unique({R.candidate_id});
            curated = curated(~cellfun(@isempty, curated));   % revision 2026-10-05: records without a candidate
            covered = [cov.candidate_ids];
            tc.verifyEmpty(intersect(curated, covered), 'a candidate is curated or covered, never both');
            tc.verifyEmpty(setdiff(cid, [curated covered]), 'every candidate is curated or covered (none silently omitted)');
            tc.verifyEmpty(setdiff([curated covered], cid), 'no unknown candidate ids');
            tc.verifyTrue(all(ismember({cov.class}, {'OUT-OF-SIM', 'PILOT', 'NOT-IMPLEMENTED', 'NO-REQUIREMENT'})), 'coverage classes');
            tc.verifyTrue(all(cellfun(@(s) strlength(string(s)) > 20, {cov.reason})), 'every coverage entry has a reason');
            pil = {cov(strcmp({cov.class}, 'PILOT')).paragraph};
            for p = {'3.2.1.1.2', '3.2.2.3', '3.3.2.1', '3.3.3', '3.3.4.4'}   % 3.2.2.2 removed (revision 2026-10-05)
                tc.verifyTrue(ismember(p{1}, pil), ['qualitative paragraph ' p{1} ' listed as PILOT']);
            end
            % in-scope candidates without a bound are NO-REQUIREMENT (pre-registration 1)
            nr = [cov(strcmp({cov.class}, 'NO-REQUIREMENT')).candidate_ids];
            for id = {'MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L3-CatA', 'MIL-F-8785C-3.2.2.1.1-n_alpha_g_per_rad-L3-CatC'}
                % the two Table VI "-" candidates left this list (revision 2026-10-05, M4)
                tc.verifyTrue(ismember(id{1}, nr), [id{1} ' is NO-REQUIREMENT']);
            end
        end

        function conditionSpaceRegistered(tc)
            f = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
            vital.io.requireDeliverable(f);
            C = vital.fq.loadConditions(f, 'Grid', 'default');
            tc.verifyEqual({C.axes.name}, {'h_ft', 'mach', 'cg_pct_mac'});
            tc.verifyTrue(C.categoryPolicy.A.assess && C.categoryPolicy.B.assess, 'Categories A and B assessed');
            tc.verifyFalse(C.categoryPolicy.C.assess, 'Category C not assessed (no landing configuration)');
            tc.verifySubstring(lower(C.categoryPolicy.C.reason), 'landing');
            tc.verifyGreaterThan(numel(C.points), 20, 'default grid larger than the test grids');
            T = vital.fq.loadConditions(f, 'Grid', 'test');
            tc.verifyLessThanOrEqual(numel(T.points), 6, 'test grid is small (runtime budget)');
        end

        function badRecordsRejected(tc)
            R = tc.records(); %#ok<NASGU>   % RED until loadRules exists
            src = fullfile(tc.RecDir, 'MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA.json');
            good = jsondecode(fileread(src));
            d = tempname; mkdir(d); cleanup = onCleanup(@() vital.test.removeTree(d));
            tc.verifyError(@() vital.fq.loadRules(d), 'vital:fq:noRules');
            bad = good; bad.source.page = '';
            tFqRules.writeJson(fullfile(d, [good.id '.json']), bad);
            tc.verifyError(@() vital.fq.loadRules(d), 'vital:rule:missingField');
            bad = good; bad.metric = 'no_such_metric';
            tFqRules.writeJson(fullfile(d, [good.id '.json']), bad);
            tc.verifyError(@() vital.fq.loadRules(d), 'vital:fq:unknownMetric');
            tFqRules.writeJson(fullfile(d, [good.id '.json']), good);
            tFqRules.writeJson(fullfile(d, 'copy.json'), good);
            tc.verifyError(@() vital.fq.loadRules(d), 'vital:fq:badRule');
        end
    end

    methods (Static)
        function writeJson(file, s)
            fid = fopen(file, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
            fclose(fid);
        end
    end
end
