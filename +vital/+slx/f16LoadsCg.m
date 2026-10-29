function [F_b, M_cg, air] = f16LoadsCg(Vb, w, C_be, Xe, u)
%F16LOADSCG  Aerodynamic + propulsive loads of the NESC F-16 about the CG, body
%   axes, for the Simulink model models/F16Trim6DOF.slx (called through
%   coder.extrinsic from its MATLAB Function block).
%   vital.slx.f16LoadsCg('setup', P)   P from vital.slx.trim6dofSetup (stores the
%                                      AircraftModel P.f16, built from the NASA
%                                      DAVE-ML data objects, and the environment)
%   [F_b, M_cg, air] = vital.slx.f16LoadsCg(Vb, w, C_be, Xe, u)
%     Vb (m/s), w (rad/s): body velocity and rates; C_be: DCM NED -> body;
%     Xe: NED position (m, altitude = -Xe(3)); u = [de da dr throttle].
%     F_b (N), M_cg (N m): aero + thrust only. WEIGHT IS NOT INCLUDED: the model
%     adds m * C_be * [0 0 g]' in its own blocks, so it can be seen and switched.
%     air = [V alpha beta Mach qbar h] (m/s, rad, rad, -, Pa, m).
%   Formula: the AircraftModel's compiled loads with g = 0 in vital.loads.sumLoadsAtCG,
%   i.e. sum of component forces, and moments moved from the BFRP to the CG
%   (M_cg = M_bfrp - r_cg x F); proven equal to vital.plant.derivatives
%   (tests/M9/core/tCoreModel, tests/M9/data/tDataModel).
persistent M ENV0
if ischar(Vb)
    if ~strcmp(Vb, 'setup')
        error('vital:badInput', 'unknown command ''%s''.', Vb);
    end
    M = w.f16;
    ENV0 = w.env;
    ENV0.g = 0;
    F_b = []; M_cg = []; air = [];
    return
end
if isempty(M)
    error('vital:slx:notSetUp', 'call vital.slx.f16LoadsCg(''setup'', P) first (the model InitFcn does).');
end
x = [Vb(:); w(:); vital.frames.dcm2quat(C_be); Xe(:)];
[~, y] = M.derivatives(x, u(:), ENV0);
F_b = y.F_b;
M_cg = y.M_cg;
air = [y.V; y.alpha; y.beta; y.mach; y.qbar; y.h];
end
