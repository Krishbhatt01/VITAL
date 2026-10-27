function m = coreTwinFixture(d)
%CORETWINFIXTURE  A HYPOTHETICAL twin-engine F-16 (test fixture, NOT a real aircraft).
%   m = coreTwinFixture(d)     d = lateral engine offset (m), default 1.5
%   The NESC F-16 aero component and mass properties, with its single centreline
%   engine replaced by two vital.PropulsorComponents on axes at y = -d (left,
%   'engine_le', channel 'throttle_le') and y = +d (right, 'engine_re', channel
%   'throttle_re') from the MRC, each giving HALF the F-16 engine thrust at its
%   own throttle. Controls {'de','da','dr','throttle_le','throttle_re'}.
%   Used by tests/M9/core/tCoreModel.m (engine-out dN = +d T/2, the numbers of
%   run_force_moment_audit) and by run_core_example.m. Returned compiled.
arguments
    d (1,1) double = 1.5
end
f16 = vital.aircraft.f16.model();
axis_bfrp = f16.axis('bfrp');
axis_mrc = f16.axis('mrc');
axis_cg = f16.axis('cg');
axis_le = vital.Axis([0 -d 0], eye(3), axis_mrc, 'Name', 'engine_le');
axis_re = vital.Axis([0 d 0], eye(3), axis_mrc, 'Name', 'engine_re');
engine_le = vital.PropulsorComponent('engine_le', axis_le, @halfThrust, 'throttle_le');
engine_re = vital.PropulsorComponent('engine_re', axis_re, @halfThrust, 'throttle_re');
m = vital.AircraftModel(sprintf('HYPOTHETICAL twin-engine F-16 (d = %.2f m; test fixture)', d), ...
    [axis_bfrp axis_mrc axis_cg axis_le axis_re], {f16.component('aero'), engine_le, engine_re}, f16.MassProps, ...
    {'de', 'da', 'dr', 'throttle_le', 'throttle_re'}, 'Ref', f16.Ref, 'Limits', f16.Limits);
m = m.compile();
end

function [T, Q, info] = halfThrust(flight, throttle)
[T, Q, info] = vital.aircraft.f16.engineThrust(flight, throttle);
T = 0.5 * T; Q = 0.5 * Q;
info.thrust_lbf = 0.5 * info.thrust_lbf;
end
