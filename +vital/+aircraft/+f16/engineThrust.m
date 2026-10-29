function [T, Q, info] = engineThrust(flight, throttle)
%ENGINETHRUST  F-16 engine thrust for a vital.PropulsorComponent (0.9.1-CORE).
%   [T, Q, info] = vital.aircraft.f16.engineThrust(flight, throttle)
%     throttle 0..1 (power lever angle PWR = 100 throttle, %; F16_prop.dml)
%     T  thrust along the engine axis +x (N) = FEX lbf;  Q  torque about +x (N m) = TEL
%     info.outOfEnvelope, info.thrust_lbf (= FEX, as vital.aircraft.f16.loads)
%   The same call and unit conversion as vital.aircraft.f16.loads. F16_prop.dml
%   defines FEY = FEZ = TEM = TEN = 0; a non-zero value would not fit a propulsor
%   (thrust along +x) and is the error vital:model:unsupported.
persistent k                              % the unit constants are fixed: built once (ADR-043 cost note)
if isempty(k), k = vital.units.constants(); end
p = vital.models.f16.prop(struct('PWR', 100 * throttle, 'ALT', flight.H / k.ft, 'RMACH', flight.Air.mach));
if p.FEY ~= 0 || p.FEZ ~= 0 || p.TEM ~= 0 || p.TEN ~= 0
    error('vital:model:unsupported', 'F-16 engine model gives off-axis force or moment; not a propulsor.');
end
T = p.FEX * k.lbf;
Q = p.TEL * k.lbf * k.ft;
info.outOfEnvelope = p.outOfEnvelope;
info.thrust_lbf = p.FEX;
end
