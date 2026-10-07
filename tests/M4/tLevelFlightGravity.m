classdef (TestTags = {'M4'}) tLevelFlightGravity < vital.test.VitalTestCase
%TLEVELFLIGHTGRAVITY  M4: the specific-force deficit of steady level flight
%   over a rotating ellipsoidal Earth, used to trim flat-earth to the NESC
%   rotating-Earth condition (found in M4: gravity alone explains only half
%   of the README-vs-NESC pitch difference).
%     g_eff,down = gravitation_down + centrifugal_down + Coriolis_down + curvature_down
%     centrifugal = -w_E x (w_E x r);  Coriolis = -2 w_E x v;
%     curvature   = -(v_N^2/(R_M + h) + v_E^2/(R_N + h))   (down component)

    properties
        K
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.K = vital.geo.constants('wgs84');
        end
    end

    methods (Test)
        function atRestIsGravitationPlusCentrifugal(tc)
            lat = deg2rad(36); lon = deg2rad(-75); h = 3000;
            r = vital.geo.lla2ecef(lat, lon, h, tc.K);
            wE = [0; 0; tc.K.omega];
            gn = vital.geo.dcmEcefToNed(lat, lon) * (vital.geo.gravitation(r, tc.K) - cross(wE, cross(wE, r)));
            tc.verifyTol(vital.geo.levelFlightGravity(lat, lon, h, [0;0;0], tc.K), gn(3), 1e-12, 'abs', 'ANALYTIC', ...
                'v = 0: gravitation + centrifugal', 'Quantity', 'g_eff at rest', 'Unit', 'm/s2');
        end

        function eastwardAtEquatorShowsEotvosEffect(tc)
            % At the equator, flying east at v adds an upward Coriolis 2 w v and a curvature v^2/(R_N + h).
            v = 100; h = 0;
            g0 = vital.geo.levelFlightGravity(0, 0, h, [0;0;0], tc.K);
            g1 = vital.geo.levelFlightGravity(0, 0, h, [0; v; 0], tc.K);
            tc.verifyTol(g1 - g0, -2*tc.K.omega*v - v^2/(tc.K.a + h), 1e-12, 'abs', 'ANALYTIC', ...
                'Eotvos: -2 w_E v (east, equator) - v^2/(R_N + h)', 'Quantity', 'delta g_eff', 'Unit', 'm/s2');
        end

        function westwardIsHeavierThanEastward(tc)
            gE = vital.geo.levelFlightGravity(deg2rad(36), 0, 3000, [0; 150; 0], tc.K);
            gW = vital.geo.levelFlightGravity(deg2rad(36), 0, 3000, [0; -150; 0], tc.K);
            tc.verifyGreaterThan(gW, gE);
        end

        function nonFiniteInputRejected(tc)
            tc.verifyError(@() vital.geo.levelFlightGravity(NaN, 0, 0, [0;0;0], tc.K), 'vital:badInput');
        end
    end
end
