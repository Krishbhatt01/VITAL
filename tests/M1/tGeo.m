classdef (TestTags = {'M1'}) tGeo < vital.test.VitalTestCase
%TGEO  M1: WGS-84 geodesy, NED axes and gravitation, checked against the
%   Aerospace Toolbox (INDEP), the gravitational potential (ANALYTIC) and
%   the NESC reference data (PUB, NASA/TM-2015-218675).

    properties
        K        % WGS-84 constants per TM Table 73
        KS       % sphere constants per TM Table 73
        LLA      % random geodetic points [lat lon h] (rad, rad, m)
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.K  = vital.geo.constants('wgs84');
            tc.KS = vital.geo.constants('sphere');
            s = RandStream('mt19937ar', 'Seed', 2);
            n = 50;
            lat = (2*rand(s,n,1)-1)*pi/2;  lat([1 2]) = [pi/2; -pi/2];
            tc.LLA = [lat, (2*rand(s,n,1)-1)*pi, rand(s,n,1)*20000 - 500];
        end
    end

    methods (Test)
        function constantsMatchTable73(tc)
            c = 'NASA/TM-2015-218675 Vol II Table 73 p.93';
            tc.verifyExact(tc.K.a, 6378137.0, 'PUB', c, 'Quantity', 'a');
            tc.verifyExact(tc.K.invf, 298.257223563, 'PUB', c, 'Quantity', '1/f');
            tc.verifyExact(tc.K.mu, 3.986004418e14, 'PUB', c, 'Quantity', 'mu');
            tc.verifyExact(tc.K.omega, 7.292115e-5, 'PUB', c, 'Quantity', 'omega_E');
            tc.verifyExact(tc.K.J2, 0.00108262982, 'PUB', c, 'Quantity', 'J2');
            tc.verifyExact(tc.KS.R, 6371007.1809, 'PUB', c, 'Quantity', 'sphere radius');
            tc.verifyExact(tc.KS.J2, 0, 'PUB', 'TM: spherical Earth uses inverse-square gravitation', 'Quantity', 'sphere J2');
        end

        function llaToEcefMatchesToolbox(tc)
            worst = 0;
            for k = 1:size(tc.LLA,1)
                r = vital.geo.lla2ecef(tc.LLA(k,1), tc.LLA(k,2), tc.LLA(k,3), tc.K);
                rt = lla2ecef([rad2deg(tc.LLA(k,1)), rad2deg(tc.LLA(k,2)), tc.LLA(k,3)], 'WGS84').';
                worst = max(worst, norm(r - rt));
            end
            tc.verifyTol(worst, 0, 1e-6, 'abs', 'INDEP', 'Aerospace Toolbox lla2ecef(...,''WGS84'')', 'Quantity', 'max |r - r_toolbox|', 'Unit', 'm');
        end

        function ecefToLlaRoundTrip(tc)
            wLat = 0; wLon = 0; wH = 0;
            for k = 1:size(tc.LLA,1)
                r = vital.geo.lla2ecef(tc.LLA(k,1), tc.LLA(k,2), tc.LLA(k,3), tc.K);
                [lat, lon, h] = vital.geo.ecef2lla(r, tc.K);
                wLat = max(wLat, abs(lat - tc.LLA(k,1)));
                if abs(tc.LLA(k,1)) < pi/2 - 1e-9
                    wLon = max(wLon, abs(atan2(sin(lon - tc.LLA(k,2)), cos(lon - tc.LLA(k,2)))));
                end
                wH = max(wH, abs(h - tc.LLA(k,3)));
            end
            tc.verifyTol(wLat, 0, 1e-12, 'abs', 'ANALYTIC', 'LLA -> ECEF -> LLA identity', 'Quantity', 'max latitude error', 'Unit', 'rad');
            tc.verifyTol(wLon, 0, 1e-12, 'abs', 'ANALYTIC', 'LLA -> ECEF -> LLA identity', 'Quantity', 'max longitude error', 'Unit', 'rad');
            tc.verifyTol(wH, 0, 1e-6, 'abs', 'ANALYTIC', 'LLA -> ECEF -> LLA identity', 'Quantity', 'max height error', 'Unit', 'm');
        end

        function ecefToLlaMatchesToolbox(tc)
            r = vital.geo.lla2ecef(deg2rad(36.01916667), deg2rad(-75.67444444), 10013*0.3048, tc.K);
            [lat, lon, h] = vital.geo.ecef2lla(r, tc.K);
            lt = ecef2lla(r.', 'WGS84');
            tc.verifyTol(rad2deg([lat lon]), lt(1:2), 1e-10, 'abs', 'INDEP', 'Aerospace Toolbox ecef2lla', 'Quantity', 'lat/lon', 'Unit', 'deg');
            tc.verifyTol(h, lt(3), 1e-6, 'abs', 'INDEP', 'Aerospace Toolbox ecef2lla', 'Quantity', 'h', 'Unit', 'm');
        end

        function sphereModelIsSpherical(tc)
            r = vital.geo.lla2ecef(0.3, -1.2, 1000, tc.KS);
            exp = (tc.KS.R + 1000) * [cos(0.3)*cos(-1.2); cos(0.3)*sin(-1.2); sin(0.3)];
            tc.verifyTol(r, exp, 1e-8, 'abs', 'ANALYTIC', 'TM Vol II eq. 10 (spherical Earth)', 'Quantity', 'r_sphere', 'Unit', 'm');
        end

        function nedDcmMatchesToolbox(tc)
            worst = 0;
            for k = 1:size(tc.LLA,1)
                C = vital.geo.dcmEcefToNed(tc.LLA(k,1), tc.LLA(k,2));
                Ct = dcmecef2ned(rad2deg(tc.LLA(k,1)), rad2deg(tc.LLA(k,2)));
                worst = max(worst, max(abs(C(:) - Ct(:))));
            end
            tc.verifyTol(worst, 0, 1e-14, 'abs', 'INDEP', 'Aerospace Toolbox dcmecef2ned', 'Quantity', 'max |C_ne - C_toolbox|');
        end

        function j2GravitationMatchesGravityzonal(tc)
            worst = 0;
            for k = 1:size(tc.LLA,1)
                r = vital.geo.lla2ecef(tc.LLA(k,1), tc.LLA(k,2), tc.LLA(k,3), tc.K);
                g = vital.geo.gravitation(r, tc.K);
                [gx, gy, gz] = gravityzonal(r.', 'Custom', tc.K.a, tc.K.mu, [tc.K.J2 0 0]);
                worst = max(worst, norm(g - [gx; gy; gz]) / norm(g));
            end
            tc.verifyTol(worst, 0, 1e-12, 'abs', 'INDEP', 'Aerospace Toolbox gravityzonal, custom model J2 only', ...
                'Quantity', 'max relative |g - g_toolbox|');
        end

        function j2GravitationIsPotentialGradient(tc)
            % U = mu/r [1 - (J2/2)(a/r)^2 (3 sin^2(phi_c) - 1)]; gravitation = grad U.
            K = tc.K;
            U = @(p) K.mu/norm(p) * (1 - K.J2/2*(K.a/norm(p))^2 * (3*(p(3)/norm(p))^2 - 1));
            r = vital.geo.lla2ecef(deg2rad(40), deg2rad(20), 5000, K);
            h = 1.0;  gnum = zeros(3,1);
            for i = 1:3
                e = zeros(3,1); e(i) = h;
                gnum(i) = (U(r + e) - U(r - e)) / (2*h);
            end
            g = vital.geo.gravitation(r, K);
            tc.verifyTol(norm(g - gnum)/norm(g), 0, 1e-7, 'abs', 'ANALYTIC', ...
                'central-difference gradient of the J2 potential (TM Vol II eq. 24)', 'Quantity', 'relative |g - grad U|');
        end

        function nescLocalGravitationCase1(tc)
            % Reference: Atmos_01 sim 5 at t = 0 (lat 0, lon 0, 30000 ft), TM Table 75: gravitation, local down.
            t = vital.io.readNescCsv('Atmos_01_DroppedSphere', 5);
            gd = vital.geo.localGravitation(deg2rad(t.latitude_deg(1)), deg2rad(t.longitude_deg(1)), ...
                t.altitudeMsl_ft(1)*0.3048, tc.K) / 0.3048;
            tc.verifyTol(gd, t.localGravity_ft_s2(1), 1e-9, 'rel', 'PUB', ...
                'NESC Atmos_01_sim_05.csv row 1; TM Vol II Table 75 p.96', 'Quantity', 'localGravity', 'Unit', 'ft/s2');
        end

        function nescLocalGravitationHighLatitude(tc)
            % Case 15 starts at 89.95 deg N: tests the geodetic-normal projection of J2 gravitation.
            t = vital.io.readNescCsv('Atmos_15_CircleNorthPole', 5);
            gd = vital.geo.localGravitation(deg2rad(t.latitude_deg(1)), deg2rad(t.longitude_deg(1)), ...
                t.altitudeMsl_ft(1)*0.3048, tc.K) / 0.3048;
            tc.verifyTol(gd, t.localGravity_ft_s2(1), 1e-9, 'rel', 'PUB', ...
                'NESC Atmos_15_sim_05.csv row 1', 'Quantity', 'localGravity at 89.95N', 'Unit', 'ft/s2');
        end

        function nescInverseSquareSphereCase4(tc)
            t = vital.io.readNescCsv('Atmos_04_DroppedSphereRoundNonRotation', 5);
            gd = vital.geo.localGravitation(0, 0, t.altitudeMsl_ft(1)*0.3048, tc.KS) / 0.3048;
            tc.verifyTol(gd, t.localGravity_ft_s2(1), 1e-9, 'rel', 'PUB', ...
                'NESC Atmos_04_sim_05.csv row 1 (sphere, inverse square)', 'Quantity', 'localGravity sphere', 'Unit', 'ft/s2');
        end

        function nescCsvReaderShape(tc)
            t = vital.io.readNescCsv('Atmos_01_DroppedSphere', 5);
            tc.verifyExact(height(t), 3001, 'PUB', 'Atmos_01_sim_05.csv has 3001 rows (TM data package)', 'Quantity', 'rows');
            tc.verifyTol(t.altitudeMsl_ft(1), 30000, 1e-6, 'abs', 'PUB', 'case 1 starts at 30000 ft (TM Table 25)', 'Quantity', 'h0', 'Unit', 'ft');
            tc.verifyTrue(any(strcmp(t.Properties.VariableNames, 'feVelocity_ft_s_Z')));
        end
    end
end
