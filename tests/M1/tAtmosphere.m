classdef (TestTags = {'M1'}) tAtmosphere < vital.test.VitalTestCase
%TATMOSPHERE  M1: US Standard Atmosphere 1976 (CONVENTIONS.md section 4).
%   Evidence: the NESC consensus simulations (PUB), the Aerospace Toolbox
%   atmoscoesa (INDEP, geopotential input), and the US 1976 defining
%   equations evaluated in the test (ANALYTIC).

    methods (Test)
        function matchesNescConsensus(tc)
            % Case 1 (30000 -> 15600 ft). Sims 3-6 solved the US 1976 equations (TM Vol II p.97);
            % they differ among themselves by up to 2e-5 in p and rho, and sim 3 has a last-frame
            % recording artifact (TM E.2.4). VITAL is evaluated at each sim's own altitude and
            % judged by the PRE-REGISTERED envelope criterion (ADR-009, NESC_CASE_MATRIX.json),
            % never by a tolerance chosen here.
            M = jsondecode(fileread(fullfile(vital.paths('docs'), 'NESC_CASE_MATRIX.json')));
            band = M.cases(strcmp({M.cases.id}, '1')).band;
            ft = 0.3048;
            sigs = {'ambientTemperature_dgR', 'ambientPressure_lbf_ft2', 'airDensity_slug_ft3', 'speedOfSound_ft_s'};
            sims = [3 4 5 6];
            T = cell(size(sims)); R = repmat({cell(size(sims))}, size(sigs)); scale = zeros(size(sigs));
            for j = 1:numel(sims)
                t = vital.io.readNescCsv('Atmos_01_DroppedSphere', sims(j));
                atm = vital.env.atmosphereUS76(t.altitudeMsl_ft * ft);
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
                    'NESC Atmos_01 sims 3-6 (TM Vol II p.97); envelope criterion ADR-009 with NESC_CASE_MATRIX.json band', ...
                    'Quantity', ['envelope excess ' sigs{i}], 'Unit', b.unit);
            end
        end

        function matchesAtmoscoesa(tc)
            H = (0:500:84500).';
            h = 6356766 * H ./ (6356766 - H);                       % geometric height for these geopotential heights
            atm = vital.env.atmosphereUS76(h);
            [T, a, p, rho] = atmoscoesa(H, 'None');
            c = 'Aerospace Toolbox atmoscoesa (geopotential input)';
            tc.verifyTol(atm.T, T, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'T 0-84.5 km', 'Unit', 'K');
            tc.verifyTol(atm.p, p, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'p 0-84.5 km', 'Unit', 'Pa');
            tc.verifyTol(atm.rho, rho, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'rho 0-84.5 km', 'Unit', 'kg/m3');
            tc.verifyTol(atm.a, a, 1e-6, 'rel', 'INDEP', c, 'Quantity', 'a 0-84.5 km', 'Unit', 'm/s');
        end

        function tropopauseAnalytic(tc)
            % US 1976: T = 216.65 K at H = 11 km; p = p0 (T/T0)^(g0 M0 / (R* L)).
            g0 = 9.80665; Rs = 8.31432; M0 = 28.9644; L = 0.0065;
            pExp = 101325 * (216.65/288.15)^(g0*M0/(Rs*L)*1e-3);
            H = 11000; h = 6356766*H/(6356766 - H);
            atm = vital.env.atmosphereUS76(h);
            c = 'US Standard Atmosphere 1976 defining equations (NASA-TM-X-74335)';
            tc.verifyTol(atm.T, 216.65, 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'T(11 km)', 'Unit', 'K');
            tc.verifyTol(atm.p, pExp, 1e-9, 'rel', 'ANALYTIC', c, 'Quantity', 'p(11 km)', 'Unit', 'Pa');
            tc.verifyTol(atm.H, 11000, 1e-6, 'abs', 'ANALYTIC', 'geopotential of the geometric height', 'Quantity', 'H', 'Unit', 'm');
        end

        function seaLevel(tc)
            atm = vital.env.atmosphereUS76(0);
            c = 'US 1976 sea-level values';
            tc.verifyTol(atm.T, 288.15, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'T0', 'Unit', 'K');
            tc.verifyTol(atm.p, 101325, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'p0', 'Unit', 'Pa');
            tc.verifyTol(atm.rho, 101325/(8314.32/28.9644*288.15), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'rho0', 'Unit', 'kg/m3');
        end

        function geopotentialConversion(tc)
            h = [0, 1000, 10000, 50000];
            H = vital.env.geometricToGeopotential(h);
            tc.verifyTol(H, 6356766*h./(6356766 + h), 1e-9, 'abs', 'ANALYTIC', 'US 1976: H = r0 h / (r0 + h), r0 = 6356766 m', ...
                'Quantity', 'H(h)', 'Unit', 'm');
            tc.verifyLessThan(H(3), h(3));
        end

        function deltaIsaShiftsTemperatureOnly(tc)
            std = vital.env.atmosphereUS76(3000);
            hot = vital.env.atmosphereUS76(3000, 'DeltaT', 15);
            R = 8314.32/28.9644;
            tc.verifyTol(hot.T, std.T + 15, 1e-12, 'abs', 'ANALYTIC', 'ISA+dT: T = T_std + dT', 'Quantity', 'T', 'Unit', 'K');
            tc.verifyTol(hot.p, std.p, 0, 'abs', 'ANALYTIC', 'ISA+dT: pressure at a given pressure altitude unchanged', 'Quantity', 'p', 'Unit', 'Pa');
            tc.verifyTol(hot.rho, hot.p/(R*hot.T), 1e-12, 'rel', 'ANALYTIC', 'ISA+dT: rho = p/(R T), consistent with T', 'Quantity', 'rho');
            tc.verifyTol(hot.a, sqrt(1.4*R*hot.T), 1e-12, 'rel', 'ANALYTIC', 'a = sqrt(gamma R T)', 'Quantity', 'a');
        end

        function vectorInputKeepsShape(tc)
            atm = vital.env.atmosphereUS76([0 1000; 2000 3000]);
            tc.verifyEqual(size(atm.rho), [2 2]);
        end
    end
end
