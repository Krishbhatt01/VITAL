classdef (TestTags = {'M8'}) tUqSpec < vital.test.VitalTestCase
%TUQSPEC  M8: the uncertainty specification (uq/f16_uncertainty.json, labelled
%   JUDGMENT) and the joint-coverage box (vital.uq.loadSpec, vital.uq.box).
%
%   PRE-REGISTERED (with the stubs, before any implementation):
%   1. SPEC = THE PLAN (REG: docs/PLAN_M5_M8.md, M8 table; the sigmas are
%      JUDGMENTS fixed by the coordinator, not published values). label
%      'JUDGMENT'; coverage 0.99; groups in this order with (parameter,
%      AeroScale field, NASA term, sigma):
%        pitchDamping  Cm_q (Cm_q, cmq, 0.10)                                 d = 1
%        pitchStatic   Cm_table (Cm_table, cmt, 0.05)                         d = 1
%        latDamping    Cl_p (Cl_p, clp, 0.10), Cn_r (Cnr_table, cnr, 0.10)    d = 2
%        latStatic     Cl_table (Cl_table, clt, 0.05), Cnt_table (Cnt_table, cnt, 0.05)  d = 2
%      DEVIATION recorded before any run: the plan names the AeroScale field of
%      Cn_r "Cn_r"; tests/M6/tAeroScale.m#badAeroScaleRejected (an earlier
%      milestone's test, not editable here) uses 'Cn_r' as its example of an
%      UNKNOWN name, so the field is 'Cnr_table' (reports/fragments/uq/NOTES.md).
%   2. k_g = sqrt(chi2inv(0.99, d)) (ANALYTIC closed forms, 1e-12 rel):
%      d = 1: sqrt(2) erfinv(0.99) = 2.5758293035489;  d = 2 (chi-square with
%      2 dof is exponential): sqrt(-2 ln 0.01) = 3.0348542587702. The plan's
%      4-digit values 2.5758 and 3.0349 agree within 5e-5 abs (REG).
%   3. BOX (ANALYTIC, 1e-15 abs): half-width = w k_g sigma for w = 0.5, 1, 1.5;
%      lo = 1 - h, hi = 1 + h, nominal = 1; e.g. x1: Cm_q 0.25758, Cm_table
%      0.12879, Cl_p and Cn_r 0.30349, Cl_table and Cnt_table 0.15174. The
%      group's 99 % ellipsoid touches its box: the ellipsoid's extent along axis
%      i, k_g w sigma_i, equals the half-width (ANALYTIC); a Monte Carlo check
%      (10^5 seeded normal samples per group, w = 1): the fraction of samples
%      inside the group box is >= 0.99 (box contains the ellipsoid; REG, the
%      standard error is 3e-4).
%   FAILED HYPOTHESES (first GREEN-phase run, 2026-10-07; recorded, originals kept
%   above, tolerances unchanged):
%   3a. boxHalfWidths compared against k_g LITERALS typed with 13 significant
%       digits (2.5758293035489, 3.0348542587702) at 1e-15 abs. Those literals
%       are themselves truncated by up to 5e-14, so the check failed by 1.4e-14
%       on x1.5 (a test-design error, not a box error; coverageFactors shows the
%       box's k_g agree with the closed forms to 1e-12 rel). CORRECTED: the
%       expected k_g are now the closed forms sqrt(2) erfinv(0.99) and
%       sqrt(-2 ln 0.01) evaluated in the test at full precision, same 1e-15 abs.
%   3b. "fraction inside the group box >= 0.99" is wrong for d = 1: the 99 %
%       interval IS the box (equality), so the sample fraction scatters around
%       0.99 (observed 0.98991 for pitchDamping). CORRECTED (ANALYTIC): the box
%       probability is exactly erf(k_g / sqrt 2)^d (0.99 for d = 1, 0.99519 for
%       d = 2, so >= 0.99 = the ellipsoid content in both cases); the sample
%       fraction must lie within 4 binomial standard errors of it.
%   4. FAILURE MODES: a spec file with a missing sigma, sigma <= 0, an unknown
%      AeroScale field, a repeated AeroScale field, a label other than
%      JUDGMENT, or no file -> vital:uq:badSpec. box WidthScale 0 or NaN ->
%      vital:badInput; WidthScale 4 (pitchDamping lower bound 1 - 4*0.2576 < 0)
%      -> vital:uq:negativeMultiplier.

    properties
        spec
        dir
    end

    methods (TestClassSetup)
        function load(tc)
            tc.spec = vital.uq.loadSpec();
        end
    end

    methods (TestMethodSetup)
        function tmp(tc)
            tc.dir = tempname;
            mkdir(tc.dir);
            tc.addTeardown(@() rmdir(tc.dir, 's'));
        end
    end

    methods (Access = private)
        function f = writeVariant(tc, raw, name)
            f = fullfile(tc.dir, [name '.json']);
            fid = fopen(f, 'w');
            fprintf(fid, '%s', jsonencode(raw));
            fclose(fid);
        end
    end

    methods (Test)
        function specIsThePlan(tc)
            s = tc.spec;
            tc.verifyEqual(s.label, 'JUDGMENT');
            tc.verifyTol(s.coverage, 0.99, 0, 'abs', 'REG', 'PLAN M8: 99 % joint coverage', 'Quantity', 'coverage');
            tc.verifyEqual({s.groups.name}, {'pitchDamping', 'pitchStatic', 'latDamping', 'latStatic'});
            tc.verifyEqual([s.groups.d], [1 1 2 2]);
            P = s.parameters;
            tc.verifyEqual({P.name}, {'Cm_q', 'Cm_table', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'});
            tc.verifyEqual({P.aeroScale}, {'Cm_q', 'Cm_table', 'Cl_p', 'Cnr_table', 'Cl_table', 'Cnt_table'});
            tc.verifyEqual({P.term}, {'cmq', 'cmt', 'clp', 'cnr', 'clt', 'cnt'});
            tc.verifyEqual({P.group}, {'pitchDamping', 'pitchStatic', 'latDamping', 'latDamping', 'latStatic', 'latStatic'});
            tc.verifyExact([P.sigma], [0.10 0.05 0.10 0.10 0.05 0.05], 'REG', 'PLAN M8 table (JUDGMENT sigmas)', ...
                'Quantity', 'sigma');
            tc.verifySubstring(s.source, 'JUDGMENT');
        end

        function coverageFactors(tc)
            kg = [tc.spec.groups.kg];
            k1 = sqrt(2) * erfinv(0.99); k2 = sqrt(-2 * log(0.01));
            tc.verifyTol(kg, [k1 k1 k2 k2], 1e-12, 'rel', 'ANALYTIC', ...
                'sqrt(chi2inv(.99,1)) = sqrt(2) erfinv(.99); sqrt(chi2inv(.99,2)) = sqrt(-2 ln .01)', 'Quantity', 'k_g');
            tc.verifyTol(kg, [2.5758 2.5758 3.0349 3.0349], 5e-5, 'abs', 'REG', 'PLAN M8 table, 4 digits', 'Quantity', 'k_g (plan)');
        end

        function boxHalfWidths(tc)
            k1 = sqrt(2) * erfinv(0.99); k2 = sqrt(-2 * log(0.01));   % failed hypothesis 3a: full-precision closed forms
            kg = [k1 k1 k2 k2 k2 k2];
            sg = [0.10 0.05 0.10 0.10 0.05 0.05];
            for w = [0.5 1 1.5]
                B = vital.uq.box(tc.spec, 'WidthScale', w);
                h = w * kg .* sg;
                q = sprintf('x%g', w);
                tc.verifyEqual(B.names, {'Cm_q', 'Cm_table', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'});
                tc.verifyEqual(B.aeroScale, {'Cm_q', 'Cm_table', 'Cl_p', 'Cnr_table', 'Cl_table', 'Cnt_table'});
                tc.verifyTol(B.halfWidth, h, 1e-15, 'abs', 'ANALYTIC', 'header 3: h = w k_g sigma', 'Quantity', ['half-width ' q]);
                tc.verifyTol(B.lo, 1 - h, 1e-15, 'abs', 'ANALYTIC', 'header 3', 'Quantity', ['lo ' q]);
                tc.verifyTol(B.hi, 1 + h, 1e-15, 'abs', 'ANALYTIC', 'header 3', 'Quantity', ['hi ' q]);
                tc.verifyExact(B.nominal, ones(1, 6), 'ANALYTIC', 'nominal multipliers', 'Quantity', ['nominal ' q]);
                tc.verifyTol(B.sigmaEff, w * sg, 1e-15, 'abs', 'ANALYTIC', 'w sigma', 'Quantity', ['sigmaEff ' q]);
                tc.verifyEqual(B.label, 'JUDGMENT');
                tc.verifyEqual(B.widthScale, w);
            end
            B = vital.uq.box(tc.spec);
            tc.verifyTol(B.halfWidth, [0.25758 0.12879 0.30349 0.30349 0.15174 0.15174], 1e-5, 'abs', 'ANALYTIC', ...
                'header 3 x1 values', 'Quantity', 'half-width x1 (5 digits)');
        end

        function boxContainsGroupEllipsoid(tc)
            B = vital.uq.box(tc.spec);
            s = RandStream('mt19937ar', 'Seed', 7);
            for g = tc.spec.groups(:).'
                i = find(strcmp(B.group, g.name));
                % the ellipsoid's extent along each axis equals the half-width
                tc.verifyTol(g.kg * B.sigmaEff(i), B.halfWidth(i), 1e-15, 'abs', 'ANALYTIC', ...
                    'axis extent of the 99 % ellipsoid = k_g sigma', 'Quantity', ['extent ' g.name]);
                Z = randn(s, 1e5, numel(i)) .* B.sigmaEff(i);
                inside = all(abs(Z) <= B.halfWidth(i), 2);
                % failed hypothesis 3b: compare with the exact box probability, not with >= 0.99
                pBox = erf(g.kg / sqrt(2))^numel(i);
                tc.verifyGreaterThanOrEqual(pBox, 0.99 - 1e-12, 'the box holds the 99 % ellipsoid');
                se = sqrt(pBox * (1 - pBox) / 1e5);
                tc.verifyTol(mean(inside), pBox, 4 * se, 'abs', 'ANALYTIC', ...
                    'header 3b: exact box probability erf(k/sqrt2)^d, 4 standard errors', ...
                    'Quantity', ['fraction inside ' g.name]);
            end
        end

        function badSpecs(tc)
            raw = jsondecode(fileread(fullfile(vital.paths('root'), 'uq', 'f16_uncertainty.json')));
            r = raw; r.groups(1).parameters = rmfield(r.groups(1).parameters, 'sigma');
            tc.verifyError(@() vital.uq.loadSpec(tc.writeVariant(r, 'noSigma')), 'vital:uq:badSpec');
            r = raw; r.groups(2).parameters.sigma = 0;
            tc.verifyError(@() vital.uq.loadSpec(tc.writeVariant(r, 'zeroSigma')), 'vital:uq:badSpec');
            r = raw; r.groups(2).parameters.aeroScale = 'Cx_table';
            tc.verifyError(@() vital.uq.loadSpec(tc.writeVariant(r, 'unknownField')), 'vital:uq:badSpec');
            r = raw; r.groups(2).parameters.aeroScale = 'Cm_q';
            tc.verifyError(@() vital.uq.loadSpec(tc.writeVariant(r, 'repeatedField')), 'vital:uq:badSpec');
            r = raw; r.label = 'PUB';
            tc.verifyError(@() vital.uq.loadSpec(tc.writeVariant(r, 'notJudgment')), 'vital:uq:badSpec');
            tc.verifyError(@() vital.uq.loadSpec(fullfile(tc.dir, 'missing.json')), 'vital:uq:badSpec');
        end

        function badBoxes(tc)
            tc.verifyError(@() vital.uq.box(tc.spec, 'WidthScale', 0), 'vital:badInput');
            tc.verifyError(@() vital.uq.box(tc.spec, 'WidthScale', NaN), 'vital:badInput');
            tc.verifyError(@() vital.uq.box(tc.spec, 'WidthScale', 4), 'vital:uq:negativeMultiplier');
        end
    end
end
