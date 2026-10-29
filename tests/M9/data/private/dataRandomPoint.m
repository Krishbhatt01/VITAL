function [x, u, env] = dataRandomPoint()
%DATARANDOMPOINT  One seeded state of the 0.9.1-CORE equivalence set
%   (tests/M9/core/tCoreModel.m randomPoint, copied): V 60..350 m/s, alpha -20..60
%   deg, beta -35..35 deg, random attitude and rates, h 0..15 km, controls past
%   their limits, wind and DeltaT.
V = 60 + 290 * rand;
a = deg2rad(-20 + 80 * rand); b = deg2rad(-35 + 70 * rand);
v = V * [cos(a) * cos(b); sin(b); sin(a) * cos(b)];
q = randn(4, 1); q = q / norm(q);
w = (rand(3, 1) - 0.5) * 3;
h = 15000 * rand;
x = [v; w; q; (rand(2, 1) - 0.5) * 2e4; -h];
u = [deg2rad(-30 + 60 * rand); deg2rad(-25 + 50 * rand); deg2rad(-35 + 70 * rand); -0.05 + 1.1 * rand];
env = struct('g', 9.80665, 'wind_n', (rand(3, 1) - 0.5) * 20, 'deltaT', (rand - 0.5) * 30);
end
