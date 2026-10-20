classdef (TestTags = {'M8', 'OOP'}) tOopAtmosphere < vital.test.VitalTestCase
%TOOPATMOSPHERE  0.8.1-OOP: the core atmosphere is the Aerospace Toolbox atmosisa
%   (ISA), wrapped by vital.env.atmosphere (ADR-037, user decision 3).
%   PRE-REGISTERED (written before the wrapper existed):
%   1. Agreement with US 1976 (INDEP: VITAL's former implementation, frozen
%      test-side as tests/reference/us76Reference.m): T, p, rho, a within 1e-6
%      relative for geopotential heights 0..32 km. [REVISED after the first
%      GREEN run for p and rho: 1e-6 below 10 km, 5e-6 over 0-32 km; measured
%      3.3e-6 at 32 km; see agreesWithUs76Below32km and ADR-037.]
%   2. Geometric input: vital.env.atmosphere(h) equals atmosisa evaluated at the
%      GEOPOTENTIAL height H = r0 h/(r0 + h) exactly (0 abs); atmosisa fed the
%      geometric height directly differs by > 1e-4 relative in p at 30,000 ft.
%   3. Out of range is an ERROR vital:env:altitudeOutOfRange (never atmosisa's
%      held value or warning), at H < -5000 m and H > 84852 m; no warning in range.
%   4. ISA + dT: T = T_std + dT, p unchanged, rho = p/(R T), a = sqrt(1.4 R T)
%      with atmosisa's own gas constant R = 101325/(1.225 * 288.15).
%   5. NESC Atmos_01 (PUB): the pre-registered NESC_CASE_MATRIX.json band holds
%      with the atmosisa wrapper (same criterion as tests/M1/tAtmosphere).
%   6. Everywhere: no +vital file except the compatibility alias calls
%      vital.env.atmosphereUS76; the alias returns the wrapper's result exactly.

    methods (TestClassSetup)
        function addReference(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
        end
    end

    methods (Test)
        function agreesWithUs76Below32km(tc)
            H = (0:250:32000).';
            h = 6356766 * H ./ (6356766 - H);
            atm = vital.env.atmosphere(h);
            ref = us76Reference(h);
            c = 'VITAL US 1976 (NASA-TM-X-74335), frozen test-side reference tests/reference/us76Reference.m';
            tc.verifyTol(atm.T, ref.T, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'T 0-32 km', 'Unit', 'K');
            % FAILED HYPOTHESIS (first GREEN run, 2026-10-19): the pre-registered 1e-6
            % for p and rho holds only below H = 10.75 km (p) and 17.25 km (rho); the
            % measured maximum over 0-32 km is 3.3e-6 (p) and 2.6e-6 (rho) at 32 km.
            % Cause: atmosisa's gas constant R = p0/(rho0 T0) = 287.0529 differs from
            % US 1976's R*/M0 = 287.0531 by 7e-7 relative, and that enters the
            % barometric exponent g0/(R L), so the p difference grows like
            % 7e-7 |ln(p/p0)|. Revised (documented, not hidden; ADR-037): 1e-6 below
            % 10 km for p and rho, and 5e-6 over 0-32 km. Flagged to the user.
            lo = H <= 10000;
            tc.verifyTol(atm.p(lo), ref.p(lo), 1e-6, 'rel', 'INDEP', c, 'Quantity', 'p 0-10 km', 'Unit', 'Pa');
            tc.verifyTol(atm.rho(lo), ref.rho(lo), 1e-6, 'rel', 'INDEP', c, 'Quantity', 'rho 0-10 km', 'Unit', 'kg/m3');
            tc.verifyTol(atm.p, ref.p, 5e-6, 'rel', 'INDEP', c, 'Quantity', 'p 0-32 km (revised)', 'Unit', 'Pa');
            tc.verifyTol(atm.rho, ref.rho, 5e-6, 'rel', 'INDEP', c, 'Quantity', 'rho 0-32 km (revised)', 'Unit', 'kg/m3');
            tc.verifyTol(atm.a, ref.a, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'a 0-32 km', 'Unit', 'm/s');
            tc.verifyTol(atm.H, ref.H, 1e-9, 'abs', 'INDEP', c, 'Quantity', 'H', 'Unit', 'm');
        end

        function geometricConvertedToGeopotential(tc)
            h = [0; 1000; 9144; 20000; 45000];
            H = 6356766 * h ./ (6356766 + h);
            atm = vital.env.atmosphere(h);
            [T, a, p, rho] = atmosisa(H);
            c = 'Aerospace Toolbox atmosisa at the geopotential height H = r0 h/(r0 + h)';
            tc.verifyTol(atm.T, T, 0, 'abs', 'INDEP', c, 'Quantity', 'T', 'Unit', 'K');
            tc.verifyTol(atm.p, p, 0, 'abs', 'INDEP', c, 'Quantity', 'p', 'Unit', 'Pa');
            tc.verifyTol(atm.rho, rho, 0, 'abs', 'INDEP', c, 'Quantity', 'rho', 'Unit', 'kg/m3');
            tc.verifyTol(atm.a, a, 0, 'abs', 'INDEP', c, 'Quantity', 'a', 'Unit', 'm/s');
            tc.verifyTol(atm.H, H, 1e-9, 'abs', 'ANALYTIC', 'H = r0 h/(r0 + h), r0 = 6356766 m', 'Quantity', 'H', 'Unit', 'm');
            tc.verifyEqual(atm.h, h);
            [~, ~, pGeom] = atmosisa(9144);
            tc.verifyGreaterThan(abs(pGeom - atm.p(3)) / atm.p(3), 1e-4, ...
                'geometric fed as geopotential must be visibly different at 30,000 ft');
        end

        function outOfRangeIsError(tc)
            r0 = 6356766;
            above = r0 * 84900 / (r0 - 84900);      % H = 84900 m > 84852 m
            below = r0 * -5100 / (r0 + 5100);       % H = -5100 m < -5000 m
            tc.verifyError(@() vital.env.atmosphere(above), 'vital:env:altitudeOutOfRange');
            tc.verifyError(@() vital.env.atmosphere(below), 'vital:env:altitudeOutOfRange');
            tc.verifyError(@() vital.env.atmosphere([1000 above]), 'vital:env:altitudeOutOfRange');
            tc.verifyError(@() vital.env.atmosphere(NaN), 'vital:badInput');
            edge = r0 * 84852 / (r0 - 84852) - 1;
            tc.verifyWarningFree(@() vital.env.atmosphere([edge, -4000]));
        end

        function deltaIsaUsesAtmosisaGasConstant(tc)
            std = vital.env.atmosphere(3000);
            hot = vital.env.atmosphere(3000, 'DeltaT', 15);
            R = 101325 / (1.225 * 288.15);
            c = 'ISA + dT with atmosisa''s gas constant R = p0/(rho0 T0)';
            tc.verifyTol(hot.T, std.T + 15, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'T', 'Unit', 'K');
            tc.verifyTol(hot.p, std.p, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'p', 'Unit', 'Pa');
            tc.verifyTol(hot.rho, hot.p / (R * hot.T), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'rho', 'Unit', 'kg/m3');
            tc.verifyTol(hot.a, sqrt(1.4 * R * hot.T), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'a', 'Unit', 'm/s');
            tc.verifyTol(std.rho, std.p / (R * std.T), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'rho (std)', 'Unit', 'kg/m3');
        end

        function nescAtmosBandHolds(tc)
            M = jsondecode(fileread(fullfile(vital.paths('docs'), 'NESC_CASE_MATRIX.json')));
            band = M.cases(strcmp({M.cases.id}, '1')).band;
            ft = 0.3048;
            sigs = {'ambientTemperature_dgR', 'ambientPressure_lbf_ft2', 'airDensity_slug_ft3', 'speedOfSound_ft_s'};
            sims = [3 4 5 6];
            T = cell(size(sims)); R = repmat({cell(size(sims))}, size(sigs)); scale = zeros(size(sigs));
            for j = 1:numel(sims)
                t = vital.io.readNescCsv('Atmos_01_DroppedSphere', sims(j));
                atm = vital.env.atmosphere(t.altitudeMsl_ft * ft);
                mine = {atm.T * 9/5, atm.p / 47.880258980335840, atm.rho / 515.37881839319607, atm.a / ft};
                T{j} = t.time;
                for i = 1:numel(sigs)
                    R{i}{j} = t.(sigs{i}) - mine{i};
                    scale(i) = max(scale(i), max(abs(t.(sigs{i}))));
                end
            end
            for i = 1:numel(sigs)
                b = band(strcmp({band.signal}, sigs{i}));
                r = vital.verify.envelopeCheck(T{2}, T, R{i}, b, scale(i));
                tc.verifyWithin(r.worst, -Inf, 0, 'PUB', ...
                    'NESC Atmos_01 sims 3-6 (TM Vol II p.97) vs atmosisa wrapper; envelope criterion ADR-009, NESC_CASE_MATRIX.json band', ...
                    'Quantity', ['envelope excess ' sigs{i}], 'Unit', b.unit);
            end
        end

        function scalarCacheNeverStale(tc)
            % Added 2026-10-19 (user decision 4): the one-entry speed cache must
            % never return the atmosphere of another altitude. A scalar sequence with
            % repeats and changes equals a fresh vector evaluation exactly.
            hs = [0 3000 3000 11000 0 0 9144.5 3000];
            ref = vital.env.atmosphere(hs);             % vector call: never cached
            f = {'T', 'p', 'rho', 'a'};
            for k = 1:numel(hs)
                s = vital.env.atmosphere(hs(k));
                for i = 1:numel(f)
                    tc.verifyTol(s.(f{i}), ref.(f{i})(k), 0, 'abs', 'ANALYTIC', ...
                        'cache returns exactly atmosisa(H) for the same H', 'Quantity', sprintf('%s at h = %g', f{i}, hs(k)));
                end
            end
        end

        function aliasAndNoCoreCaller(tc)
            h = [0 3000 9144 20000];
            tc.verifyEqual(vital.env.atmosphereUS76(h), vital.env.atmosphere(h));
            tc.verifyEqual(vital.env.atmosphereUS76(h, 'DeltaT', 7), vital.env.atmosphere(h, 'DeltaT', 7));
            f = dir(fullfile(vital.paths('root'), '+vital', '**', '*.m'));
            bad = {};
            for k = 1:numel(f)
                if strcmp(f(k).name, 'atmosphereUS76.m'), continue; end
                txt = fileread(fullfile(f(k).folder, f(k).name));
                code = regexprep(txt, '%[^\n]*', '');          % comments may still name it
                if contains(code, 'atmosphereUS76'), bad{end+1} = f(k).name; end %#ok<AGROW>
            end
            tc.verifyEmpty(bad, 'core files still calling vital.env.atmosphereUS76 instead of vital.env.atmosphere');
        end
    end
end
