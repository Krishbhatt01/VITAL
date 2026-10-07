classdef (TestTags = {'M6'}) tFqRulesR2 < vital.test.VitalTestCase
%TFQRULESR2  M6, review R2 fixes to the rule records: a second-reader bound
%   table typed from the MIL-F-8785C PAGE IMAGES (not from the extract or the
%   candidate file), the records that encode interpretations, and the
%   group/category consistency (escaped mutation R2-1).
%
%   PDF bound table (pre-registration 1). Read by agent fq from page renders of
%   data/mil/original/MIL-F-8785C.pdf (PDF index = printed page - 1) on
%   2026-10-05: p.11 (3.2.1.1), p.12 (3.2.1.2), p.13 (3.2.2.2, Table IV),
%   p.14 (Figure 1), p.15 (Figure 2), p.22 (Table VI and its increments), p.23
%   (Tables VII, VIII, 3.3.1.4). Figure 3 (p.16) was not re-read by fq: its row
%   uses review R2's pixel calibration (REVIEW.md section 1: n/alpha edges 2.71
%   and 1.70, Level 1 omega floor 0.853 +/- 0.01); its graphical records are
%   checked within +/- 0.01.
%     Table IV (p.13), inclusive: A & C  L1 0.35-1.30, L2 0.25-2.00, L3 >= 0.15
%                                  B      L1 0.30-2.00, L2 0.20-2.00, L3 >= 0.15
%     Figure 1 (p.14), Cat A, inclusive: CAP L1 0.28-3.6, L2 0.16-10.0, L3 >= 0.16;
%                                  omega_nsp L1 >= 1.0, L2 >= 0.6
%     Figure 2 (p.15), Cat B, inclusive: CAP L1 0.085-3.6, L2 0.038-10.0, L3 >= 0.038
%     Figure 3 (p.16, R2), Cat C: CAP L1 0.16-3.6, L2 0.096-10.0, L3 >= 0.096;
%                                  omega L1 >= ~0.853, L2 >= 0.6, L3 > 0.6 (strict);
%                                  n/alpha L1 >= ~2.71, L2 >= ~1.70
%     Table VI (p.22), all strict ("shall exceed"):
%       L1 A (CO and GA), IV: zeta_d 0.4, zeta_d omega_nd "-", omega_nd 1.0
%       L1 A, I and IV:       0.19, 0.35, 1.0
%       L1 B, All:            0.08, 0.15, 0.4
%       L1 C, I, II-C, IV:    0.08, 0.15, 1.0
%       L2 All:               0.02, 0.05, 0.4
%       L3 All:               0,    "-",  0.4
%       increment of the minimum zeta_d omega_nd when omega_nd^2|phi/beta|_d > 20:
%       L1 .014, L2 .009, L3 .005 times (omega_nd^2|phi/beta|_d - 20)
%     Table VII (p.23), tau_R max, inclusive: A 1.0/1.4/10, B 1.4/3.0/10, C 1.0/1.4/10
%     Table VIII (p.23), spiral T2 min, strict: A & C 12/8/4 s, B 20/8/4 s
%     3.2.1.2 (p.12), inclusive: zeta_p L1 >= 0.04, L2 >= 0; T2 L3 >= 55 s
%     3.2.1.1 (p.11): Level 3 T2 >= 6 s (inclusive, "in no event ... less than")
%     3.3.1.4 (p.23), strict: zeta_RS omega_nRS L1 0.5, L2 0.3, L3 0.15 (B and C)
%
%   Interpreted records (pre-registration 2; source.interpretation non-empty;
%   REVIEW.md M1, M2, M4, B1 and the coordinator's decisions):
%     3.2.1.1 L1, L2 x A, B, C   speed_divergence_rate_1_s <= 0   Q-PROXY
%          (p.11 "no tendency for airspeed to diverge aperiodically", controls fixed)
%     3.2.2.2 L1-L3 x A, B, C    lon_divergence_rate_1_s <= 0     Q-PROXY
%          (p.13 "no tendency for the airplane pitch attitude or angle of attack
%          to diverge aperiodically with controls fixed"; no Level is named, so it
%          applies at every Level, 3.1.10.3.2; the level 1-g point is the n = 1
%          member of the steady turns and pullups)
%     3.3.1.4 L1-L3 x A-other    coupled_roll_spiral_present <= 0 Q-PROXY
%          (conservative reading of "such as CO and GA": the permission is given
%          to Categories B and C only)
%     3.3.1.1 zeta_d_omega_nd L3 x 4 groups and L1 A-COGA: min 0 (strict) plus the
%          printed increment (.005 resp. .014): the only reading that gives the
%          printed increment line an effect ("-" base; zeta_d > 0 gives > 0)
%     23 interpreted records in total.
%   Pre-registration 3: 118 curated records = the 95 of tFqRules + 23 above.
%   Pre-registration 4 (R2-1): every record's group is
%     <paragraph>-Cat<category>[-<phase_subset>].

    properties
        R
    end

    methods (TestMethodSetup)
        function load(tc)
            tc.R = vital.fq.loadRules();
        end
    end

    methods (Static, Access = private)
        function T = pdfTable()
            % {paragraph, metric, level, group suffixes, lo, hi, strict, page, approxTol, slope}
            I = Inf;
            T = {
            '3.2.2.1.2', 'zeta_sp', 1, {'CatA', 'CatC'}, 0.35, 1.30, false, 13, 0, 0
            '3.2.2.1.2', 'zeta_sp', 2, {'CatA', 'CatC'}, 0.25, 2.00, false, 13, 0, 0
            '3.2.2.1.2', 'zeta_sp', 3, {'CatA', 'CatC'}, 0.15, I, false, 13, 0, 0
            '3.2.2.1.2', 'zeta_sp', 1, {'CatB'}, 0.30, 2.00, false, 13, 0, 0
            '3.2.2.1.2', 'zeta_sp', 2, {'CatB'}, 0.20, 2.00, false, 13, 0, 0
            '3.2.2.1.2', 'zeta_sp', 3, {'CatB'}, 0.15, I, false, 13, 0, 0
            '3.2.2.1.1', 'CAP', 1, {'CatA'}, 0.28, 3.6, false, 14, 0, 0
            '3.2.2.1.1', 'CAP', 2, {'CatA'}, 0.16, 10.0, false, 14, 0, 0
            '3.2.2.1.1', 'CAP', 3, {'CatA'}, 0.16, I, false, 14, 0, 0
            '3.2.2.1.1', 'omega_nsp_rad_s', 1, {'CatA'}, 1.0, I, false, 14, 0, 0
            '3.2.2.1.1', 'omega_nsp_rad_s', 2, {'CatA'}, 0.6, I, false, 14, 0, 0
            '3.2.2.1.1', 'CAP', 1, {'CatB'}, 0.085, 3.6, false, 15, 0, 0
            '3.2.2.1.1', 'CAP', 2, {'CatB'}, 0.038, 10.0, false, 15, 0, 0
            '3.2.2.1.1', 'CAP', 3, {'CatB'}, 0.038, I, false, 15, 0, 0
            '3.2.2.1.1', 'CAP', 1, {'CatC'}, 0.16, 3.6, false, 16, 0, 0
            '3.2.2.1.1', 'CAP', 2, {'CatC'}, 0.096, 10.0, false, 16, 0, 0
            '3.2.2.1.1', 'CAP', 3, {'CatC'}, 0.096, I, false, 16, 0, 0
            '3.2.2.1.1', 'omega_nsp_rad_s', 1, {'CatC'}, 0.853, I, false, 16, 0.01, 0
            '3.2.2.1.1', 'omega_nsp_rad_s', 2, {'CatC'}, 0.6, I, false, 16, 0, 0
            '3.2.2.1.1', 'omega_nsp_rad_s', 3, {'CatC'}, 0.6, I, true, 16, 0, 0
            '3.2.2.1.1', 'n_alpha_g_per_rad', 1, {'CatC'}, 2.71, I, false, 16, 0.01, 0
            '3.2.2.1.1', 'n_alpha_g_per_rad', 2, {'CatC'}, 1.70, I, false, 16, 0.01, 0
            '3.3.1.1', 'zeta_d', 1, {'CatA-COGA'}, 0.4, I, true, 22, 0, 0
            '3.3.1.1', 'omega_nd_rad_s', 1, {'CatA-COGA'}, 1.0, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d', 1, {'CatA-other'}, 0.19, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d_omega_nd_rad_s', 1, {'CatA-other'}, 0.35, I, true, 22, 0, 0.014
            '3.3.1.1', 'omega_nd_rad_s', 1, {'CatA-other'}, 1.0, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d', 1, {'CatB', 'CatC'}, 0.08, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d_omega_nd_rad_s', 1, {'CatB', 'CatC'}, 0.15, I, true, 22, 0, 0.014
            '3.3.1.1', 'omega_nd_rad_s', 1, {'CatB'}, 0.4, I, true, 22, 0, 0
            '3.3.1.1', 'omega_nd_rad_s', 1, {'CatC'}, 1.0, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d', 2, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0.02, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d_omega_nd_rad_s', 2, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0.05, I, true, 22, 0, 0.009
            '3.3.1.1', 'omega_nd_rad_s', 2, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0.4, I, true, 22, 0, 0
            '3.3.1.1', 'zeta_d', 3, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0, I, true, 22, 0, 0
            '3.3.1.1', 'omega_nd_rad_s', 3, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0.4, I, true, 22, 0, 0
            '3.3.1.2', 'tau_R_s', 1, {'CatA', 'CatC'}, -I, 1.0, false, 23, 0, 0
            '3.3.1.2', 'tau_R_s', 2, {'CatA', 'CatC'}, -I, 1.4, false, 23, 0, 0
            '3.3.1.2', 'tau_R_s', 1, {'CatB'}, -I, 1.4, false, 23, 0, 0
            '3.3.1.2', 'tau_R_s', 2, {'CatB'}, -I, 3.0, false, 23, 0, 0
            '3.3.1.2', 'tau_R_s', 3, {'CatA', 'CatB', 'CatC'}, -I, 10, false, 23, 0, 0
            '3.3.1.3', 'spiral_T2_s', 1, {'CatA', 'CatC'}, 12, I, true, 23, 0, 0
            '3.3.1.3', 'spiral_T2_s', 1, {'CatB'}, 20, I, true, 23, 0, 0
            '3.3.1.3', 'spiral_T2_s', 2, {'CatA', 'CatB', 'CatC'}, 8, I, true, 23, 0, 0
            '3.3.1.3', 'spiral_T2_s', 3, {'CatA', 'CatB', 'CatC'}, 4, I, true, 23, 0, 0
            '3.2.1.2', 'zeta_p', 1, {'CatA', 'CatB', 'CatC'}, 0.04, I, false, 12, 0, 0
            '3.2.1.2', 'zeta_p', 2, {'CatA', 'CatB', 'CatC'}, 0, I, false, 12, 0, 0
            '3.2.1.2', 'T2_phugoid_s', 3, {'CatA', 'CatB', 'CatC'}, 55, I, false, 12, 0, 0
            '3.2.1.1', 'T2_speed_divergence_s', 3, {'CatA', 'CatB', 'CatC'}, 6, I, false, 11, 0, 0
            '3.3.1.4', 'zeta_RS_omega_nRS_rad_s', 1, {'CatB', 'CatC'}, 0.5, I, true, 23, 0, 0
            '3.3.1.4', 'zeta_RS_omega_nRS_rad_s', 2, {'CatB', 'CatC'}, 0.3, I, true, 23, 0, 0
            '3.3.1.4', 'zeta_RS_omega_nRS_rad_s', 3, {'CatB', 'CatC'}, 0.15, I, true, 23, 0, 0
            };
        end

        function T = interpTable()
            % {paragraph, metric, level, group suffixes, lo, hi, strict, class, slope}
            I = Inf;
            T = {
            '3.2.1.1', 'speed_divergence_rate_1_s', 1, {'CatA', 'CatB', 'CatC'}, -I, 0, false, 'Q-PROXY', 0
            '3.2.1.1', 'speed_divergence_rate_1_s', 2, {'CatA', 'CatB', 'CatC'}, -I, 0, false, 'Q-PROXY', 0
            '3.2.2.2', 'lon_divergence_rate_1_s', 1, {'CatA', 'CatB', 'CatC'}, -I, 0, false, 'Q-PROXY', 0
            '3.2.2.2', 'lon_divergence_rate_1_s', 2, {'CatA', 'CatB', 'CatC'}, -I, 0, false, 'Q-PROXY', 0
            '3.2.2.2', 'lon_divergence_rate_1_s', 3, {'CatA', 'CatB', 'CatC'}, -I, 0, false, 'Q-PROXY', 0
            '3.3.1.4', 'coupled_roll_spiral_present', 1, {'CatA-other'}, -I, 0, false, 'Q-PROXY', 0
            '3.3.1.4', 'coupled_roll_spiral_present', 2, {'CatA-other'}, -I, 0, false, 'Q-PROXY', 0
            '3.3.1.4', 'coupled_roll_spiral_present', 3, {'CatA-other'}, -I, 0, false, 'Q-PROXY', 0
            '3.3.1.1', 'zeta_d_omega_nd_rad_s', 3, {'CatA-COGA', 'CatA-other', 'CatB', 'CatC'}, 0, I, true, 'Q-SPEC', 0.005
            '3.3.1.1', 'zeta_d_omega_nd_rad_s', 1, {'CatA-COGA'}, 0, I, true, 'Q-SPEC', 0.014
            };
        end

        function s = suffix(r)
            s = r.group(numel(r.paragraph) + 2:end);
        end
    end

    methods (Test)
        function groupMatchesCategory(tc)
            for r = tc.R(:).'
                exp = sprintf('%s-Cat%s', r.paragraph, r.category);
                if ~isempty(r.subset), exp = [exp '-' r.subset]; end %#ok<AGROW>
                tc.verifyEqual(r.group, exp, sprintf('%s: group must be paragraph-Cat<category>[-subset] (R2-1)', r.id));
            end
        end

        function boundsMatchPdfTable(tc)
            T = tFqRulesR2.pdfTable();
            used = false(size(T, 1), 1);
            for r = tc.R(:).'
                if isfield(r.record.source, 'interpretation') && ~isempty(r.record.source.interpretation), continue; end
                if strcmp(r.class, 'Q-PROXY'), continue; end
                if strcmp(r.paragraph, '3.3.1.1') && strcmp(r.metric, 'zeta_d_omega_nd_rad_s') && r.level == 3, continue; end
                k = find(strcmp(T(:, 1), r.paragraph) & strcmp(T(:, 2), r.metric) & [T{:, 3}].' == r.level & ...
                    cellfun(@(s) any(strcmp(s, tFqRulesR2.suffix(r))), T(:, 4)));
                tc.assertNumElements(k, 1, [r.id ': one PDF-table row']);
                used(k) = true;
                cit = sprintf('MIL-F-8785C p.%d (page image read by fq; Figure 3 by R2)', T{k, 8});
                if T{k, 9} > 0
                    tc.verifyWithin(r.lo, T{k, 5} - T{k, 9}, T{k, 5} + T{k, 9}, 'PUB', cit, 'Quantity', [r.id ' graphical lower bound']);
                else
                    tc.verifyExact([r.lo r.hi], [T{k, 5} T{k, 6}], 'PUB', cit, 'Quantity', [r.id ' bounds']);
                end
                tc.verifyExact(r.strict, T{k, 7}, 'PUB', cit, 'Quantity', [r.id ' strict']);
                if T{k, 10} > 0
                    tc.verifyTrue(r.incr.has, [r.id ': increment']);
                    tc.verifyExact([r.incr.slope r.incr.threshold], [T{k, 10} 20], 'PUB', cit, 'Quantity', [r.id ' increment']);
                end
            end
            tc.verifyTrue(all(used), sprintf('PDF-table rows without a record: %s', mat2str(find(~used).')));
        end

        function interpretedRecordsRegistered(tc)
            T = tFqRulesR2.interpTable();
            isI = arrayfun(@(r) isfield(r.record.source, 'interpretation') && ~isempty(r.record.source.interpretation), tc.R);
            tc.verifyExact(sum(isI), 23, 'REG', 'pre-registration 2', 'Quantity', 'interpreted records');
            n = 0;
            for r = tc.R(isI)
                k = find(strcmp(T(:, 1), r.paragraph) & strcmp(T(:, 2), r.metric) & [T{:, 3}].' == r.level & ...
                    cellfun(@(s) any(strcmp(s, tFqRulesR2.suffix(r))), T(:, 4)));
                tc.assertNumElements(k, 1, [r.id ': registered interpretation']);
                c = sprintf('REG: interpretation registered in tFqRulesR2 (%s)', r.paragraph);
                tc.verifyExact([r.lo r.hi], [T{k, 5} T{k, 6}], 'REG', c, 'Quantity', [r.id ' bounds']);
                tc.verifyExact(r.strict, T{k, 7}, 'REG', c, 'Quantity', [r.id ' strict']);
                tc.verifyEqual(r.class, T{k, 8}, r.id);
                if T{k, 9} > 0
                    tc.verifyExact([r.incr.slope r.incr.threshold], [T{k, 9} 20], 'REG', c, 'Quantity', [r.id ' increment']);
                end
                n = n + 1;
            end
            tc.verifyExact(n, 23, 'REG', 'pre-registration 2', 'Quantity', 'matched interpretations');
        end

        function curatedCount(tc)
            tc.verifyExact(numel(tc.R), 118, 'REG', 'pre-registration 3', 'Quantity', 'curated records');
        end
    end
end
