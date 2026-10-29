function m = nescAircraftModel(name, overrides)
%NESCAIRCRAFTMODEL  A NESC atmospheric test vehicle (sphere or brick) built as a
%   vital.AircraftModel with ZERO controls (TEST FIXTURE; increment I0, ADR-041).
%   m = nescAircraftModel(name, overrides)
%     name       'cannonball' | 'brick' (vital.nesc.vehicle)
%     overrides  the case's coefficient overrides (vital.nesc.caseDef(id).overrides)
%   Returned compiled. Physics identical to vital.nesc.vehicle + vital.nesc.bodyLoads
%   (NASA/TM-2015-218675 Vol II B.1.1 / B.1.3), but deliberately routed through
%   NON-TRIVIAL axes so that the PUB check cases exercise the rotation and transfer
%   paths of the object core:
%     - the CG axis 'cg' is ROTATED (3-2-1 Euler [0.3 -0.2 0.7] rad) and the inertia
%       tensor is given in its components, J_cg = C J_b C' (compile() must rotate it
%       back with about(); the brick's products of inertia then become non-zero);
%     - the aero component sits on a 'aeroData' axis that is ROTATED (Euler
%       [0.4 -0.3 1.1] rad) and OFFSET d = [0.05 -0.02 0.03] m from the CM; its
%       coefficients are the published body-axis loads expressed about d in that
%       axis: F_d = C_db F, M_d = C_db (M_cm - d x F)   (moment transfer from the
%       CM, which is the BFRP origin: DXCG = DYCG = DZCG = 0).
%   The compiled path must undo both exactly: F_b = C_db' F_d, M_cm = C_db' M_d + d x F_b.
ACv = vital.nesc.vehicle(name, overrides);
root = vital.Axis.root('bfrp');
Ccg = vital.frames.dcm321(0.3, -0.2, 0.7);            % C_cg_bfrp
cg = vital.Axis(ACv.r_cg, Ccg, root, 'Name', 'cg');
Jcg = Ccg * ACv.J * Ccg.';
Jcg = (Jcg + Jcg.') / 2;
d = [0.05; -0.02; 0.03];
Cd = vital.frames.dcm321(0.4, -0.3, 1.1);             % C_data_bfrp
data = vital.Axis(d, Cd, root, 'Name', 'aeroData');
aero = vital.AeroTableComponent('aero', data, @dataAxisCoefficients, 'S', ACv.S, 'b', ACv.b, 'cbar', ACv.cbar, ...
    'Channels', {}, 'CoeffArgs', {ACv, Cd, d});
mp = vital.MassProperties(ACv.mass, cg, vital.InertiaTensor(Jcg, cg));
m = vital.AircraftModel(sprintf('NESC %s as an AircraftModel (I0 test fixture)', name), [root cg data], {aero}, mp, {}, ...
    'Ref', struct('S', ACv.S, 'b', ACv.b, 'cbar', ACv.cbar));
m = m.compile();
end

function [c, info] = dataAxisCoefficients(fl, ACv, Cd, d)
% published loads (body axes, about the CM) -> coefficients in the data axis about d
[F, M, i] = vital.nesc.bodyLoads(fl.Air, [], fl.H, fl.Atm, ACv);
Fd = Cd * F;
Md = Cd * (M - cross(d, F));
qS = fl.Air.qbar * ACv.S;
if qS > 0
    c = [Fd.' / qS, Md(1) / (qS * ACv.b), Md(2) / (qS * ACv.cbar), Md(3) / (qS * ACv.b)];
else
    c = zeros(1, 6);                                    % bodyLoads is exactly zero at qbar = 0
end
info.outOfEnvelope = logical(i.outOfEnvelope);
end
