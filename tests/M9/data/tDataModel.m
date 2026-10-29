classdef (TestTags = {'M9', 'DATA'}) tDataModel < vital.test.VitalTestCase
%TDATAMODEL  D1 (docs/PLAN_DATA_LAYER.md) criterion 4: the AircraftModel built from
%   the data object, and config() checked against the data object.
%   PRE-REGISTERED (written before the classes existed):
%   1. BITWISE EQUIVALENCE over the 1,100-state set of the 0.9.1-CORE gate (rng 91001,
%      the 11 configurations of tests/M9/core/tCoreModel.m, 100 states each:
%      default, each AeroScale multiplier alone, all 8, CG 30 % with BfrpOffset
%      [0.5 -0.1 0.2] m and Cm_q 0.5; out-of-envelope points included):
%      m = vital.AircraftModel.fromData(vital.aircraft.f16.data(CG, Bfrp), 'AeroScale', s),
%      the FROZEN 0.9.1-CORE builder (private/legacyF16Model, built from config) and
%      the shipped vital.aircraft.f16.model(cfg) give IDENTICAL xdot (isequal, every
%      bit) and identical y.F_b, y.M_cg, y.F_R, y.M_R, y.alpha, y.beta, y.V, y.qbar,
%      y.mach, y.nz, y.outOfEnvelope on every state: max |difference| = 0 (REG).
%   2. SAME MODEL: fromData's axes, mass properties, Ref, Limits, Controls,
%      component names, classes, axes, channels and coefficient arguments are
%      isequal to the frozen builder's; Meta equal except Meta.source (which now
%      names the data object).
%   3. config() = DATA (exact). AC = vital.aircraft.f16.config(opts) and
%      d.toConfig(opts) have the same fields and isequal values (S, b, cbar, mass,
%      J, r_cg, r_mrc, limits, controlNames, aeroScale, loadsFcn, name, cgPctMac),
%      for the default and for CG 30 % with BfrpOffset [0.5 -0.1 0.2] m.
%   4. The NESC sphere and brick: S, b, cbar, mass, J and r_cg of their data objects
%      are isequal to vital.nesc.vehicle('brick' / 'cannonball') (the existing
%      runtime, from the generated code).
%   5. README TRIM through vital.aircraft.f16.model().toRuntime() equals the trim
%      of config() to 1e-12 abs in x and u, status OK (REG; the F-16 anchor).
%   6. The CG axis of the model is the data's CG axis: at CG 30 % with BfrpOffset,
%      m.MassProps.CgAxis.Name = 'cg' and its origin = AC.r_cg exactly (it differs
%      from the MRC by 0.05 cbar, so a wrong axis is visible).
%   7. Errors: fromData of the brick (no runtime components declared):
%      vital:data:noRuntime; an unknown AeroScale name: vital:badInput.

    properties
        D
        env
    end

    methods (TestClassSetup)
        function setup(tc)
            k = vital.units.constants();
            tc.D = vital.aircraft.f16.data();
            tc.env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
        end
    end

    methods (Test)
        function fromDataBitwiseOver1100States(tc)
            rng(91001);
            cfgs = dataConfigurations();
            nPer = 100;
            worst = 0; nTot = 0; nOut = 0;
            fields = {'F_b', 'M_cg', 'F_R', 'M_R', 'alpha', 'beta', 'V', 'qbar', 'mach', 'nz', 'outOfEnvelope'};
            for c = 1:numel(cfgs)
                o = cfgs{c};
                [dOpts, aOpts] = splitOpts(o);
                m = vital.AircraftModel.fromData(vital.aircraft.f16.data(dOpts{:}), aOpts{:});
                L = legacyF16Model(o{:});
                S = vital.aircraft.f16.model(o{:});
                for i = 1:nPer
                    [x, u, env] = dataRandomPoint();
                    [xa, ya] = m.derivatives(x, u, env);
                    [xb, yb] = L.derivatives(x, u, env);
                    [xc, yc] = S.derivatives(x, u, env);
                    d = max([abs(xa - xb); abs(xc - xb)]);
                    if ~(isequal(xa, xb) && isequal(xc, xb)), d = max(d, realmin); end
                    for f = fields
                        if ~(isequal(ya.(f{1}), yb.(f{1})) && isequal(yc.(f{1}), yb.(f{1})))
                            d = max([d; realmin; abs(double(ya.(f{1})(:)) - double(yb.(f{1})(:)))]);
                        end
                    end
                    worst = max(worst, d);
                    nTot = nTot + 1; nOut = nOut + yb.outOfEnvelope;
                end
            end
            fprintf('[tDataModel] %d states (%d out of envelope): max |fromData - 0.9.1-CORE| = %.3g\n', nTot, nOut, worst);
            tc.verifyExact(worst, 0, 'REG', 'PLAN_DATA_LAYER 4: fromData bitwise = vital.aircraft.f16.model of 0.9.1-CORE', ...
                'Quantity', 'max |difference| over xdot and y');
            tc.verifyExact(nTot, 1100, 'REG', 'the 1,100-state set', 'Quantity', 'states');
            tc.verifyWithin(nOut, 100, Inf, 'REG', 'non-vacuous: out-of-envelope states', 'Quantity', 'out-of-envelope states');
        end

        function sameModelStructure(tc)
            for o = {{}, {'CG_PCT_MAC', 30, 'BfrpOffset', [0.5; -0.1; 0.2], 'AeroScale', struct('Cm_q', 0.5)}}
                [dOpts, aOpts] = splitOpts(o{1});
                m = vital.AircraftModel.fromData(vital.aircraft.f16.data(dOpts{:}), aOpts{:});
                L = legacyF16Model(o{1}{:});
                tc.verifyTrue(isequal(m.Axes, L.Axes), 'axes');
                tc.verifyTrue(isequal(m.MassProps, L.MassProps), 'mass properties');
                tc.verifyTrue(isequal(m.Ref, L.Ref) && isequal(m.Limits, L.Limits) && isequal(m.Controls, L.Controls) && ...
                    strcmp(m.Name, L.Name), 'Ref, Limits, Controls, Name');
                tc.verifyTrue(isequal(rmfield(m.Meta, 'source'), rmfield(L.Meta, 'source')), 'Meta apart from source');
                tc.verifyExact(numel(m.Components), numel(L.Components), 'REG', 'two components', 'Quantity', 'components');
                for k = 1:numel(L.Components)
                    a = m.Components{k}; b = L.Components{k};
                    ok = strcmp(class(a), class(b)) && strcmp(a.Name, b.Name) && isequal(a.Axis, b.Axis) && ...
                        isequal(a.Channels, b.Channels) && a.Enabled == b.Enabled;
                    if isa(b, 'vital.AeroTableComponent')
                        ok = ok && strcmp(func2str(a.CoeffFcn), func2str(b.CoeffFcn)) && isequal(a.CoeffArgs, b.CoeffArgs) && ...
                            isequal([a.S a.b a.cbar], [b.S b.b b.cbar]);
                    else
                        ok = ok && strcmp(func2str(a.ThrustFcn), func2str(b.ThrustFcn));
                    end
                    tc.verifyTrue(ok, sprintf('component %s identical', b.Name));
                end
            end
        end

        function configEqualsData(tc)
            for o = {{}, {'CG_PCT_MAC', 30, 'BfrpOffset', [0.5; -0.1; 0.2]}}
                AC = vital.aircraft.f16.config(o{1}{:});
                A2 = vital.aircraft.f16.data(o{1}{:}).toConfig();
                tc.verifyExact(sort(fieldnames(A2)), sort(fieldnames(AC)), 'REG', 'same fields as config()', 'Quantity', 'config fields');
                for f = fieldnames(AC).'
                    if isfield(A2, f{1})
                        tc.verifyTrue(isequal(A2.(f{1}), AC.(f{1})), sprintf('config field %s identical', f{1}));
                    end
                end
                tc.verifyExact([A2.S A2.b A2.cbar A2.mass], [AC.S AC.b AC.cbar AC.mass], 'PUB', ...
                    'F16_aero.dml sref/bspan/cbar, F16_inertia.dml XMASS (config() hand copy)', 'Quantity', 'S b cbar m');
                tc.verifyExact([A2.J(:); A2.r_cg; A2.r_mrc], [AC.J(:); AC.r_cg; AC.r_mrc], 'PUB', ...
                    'F16_inertia.dml XIXX..XIYZ, DXCG..DZCG', 'Quantity', 'J r_cg r_mrc');
            end
        end

        function nescBodiesEqualVehicle(tc)
            for name = {'brick', 'cannonball'}
                d = vital.aircraft.nesc.(name{1}).data();
                V = vital.nesc.vehicle(name{1});
                tc.verifyExact([d.geometry.S.si() d.geometry.b.si() d.geometry.cbar.si()], [V.S V.b V.cbar], 'REG', ...
                    'vital.nesc.vehicle (generated code)', 'Quantity', [name{1} ' S b cbar']);
                tc.verifyExact(d.mass.massSI(), V.mass, 'REG', 'vital.nesc.vehicle', 'Quantity', [name{1} ' mass']);
                tc.verifyExact(d.mass.inertiaSI(), V.J, 'REG', 'vital.nesc.vehicle', 'Quantity', [name{1} ' J']);
                tc.verifyExact(d.axes.cg.originIn(d.axes.(d.runtime.root)), V.r_cg, 'REG', 'vital.nesc.vehicle', 'Quantity', [name{1} ' r_cg']);
            end
        end

        function readmeTrimUnchanged(tc)
            k = vital.units.constants();
            cond = struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0);
            t1 = vital.trim.solve(vital.aircraft.f16.config(), tc.env, cond);
            t2 = vital.trim.solve(vital.AircraftModel.fromData(tc.D).toRuntime(), tc.env, cond);
            tc.verifyEqual(t2.status, 'OK');
            tc.verifyTol(t2.x, t1.x, 1e-12, 'abs', 'REG', 'README trim through fromData = config trim', 'Quantity', 'trim x');
            tc.verifyTol(t2.u, t1.u, 1e-12, 'abs', 'REG', 'README trim through fromData = config trim', 'Quantity', 'trim u');
        end

        function cgAxisIsTheCg(tc)
            o = {'CG_PCT_MAC', 30, 'BfrpOffset', [0.5; -0.1; 0.2]};
            AC = vital.aircraft.f16.config(o{:});
            m = vital.AircraftModel.fromData(vital.aircraft.f16.data(o{:}));
            tc.verifyExact(m.MassProps.CgAxis.Name, 'cg', 'REG', 'the data''s cg axis', 'Quantity', 'CG axis name');
            tc.verifyExact(m.MassProps.CgAxis.originIn(m.axis('bfrp')), AC.r_cg, 'PUB', ...
                'F16_inertia.dml DXCG = 0.01 cbar (35 - 30) ft forward of the MRC, minus BfrpOffset', 'Quantity', 'CG origin');
        end

        function fromDataErrors(tc)
            tc.verifyError(@() vital.AircraftModel.fromData(vital.aircraft.nesc.brick.data()), 'vital:data:noRuntime');
            tc.verifyError(@() vital.AircraftModel.fromData(tc.D, 'AeroScale', struct('Cnr_table', 2)), 'vital:badInput');
        end
    end
end

function [dOpts, aOpts] = splitOpts(o)
% data options (CG, BfrpOffset) vs model options (AeroScale)
dOpts = {}; aOpts = {};
for k = 1:2:numel(o)
    if strcmp(o{k}, 'AeroScale'), aOpts = [aOpts, o(k:k+1)]; else, dOpts = [dOpts, o(k:k+1)]; end %#ok<AGROW>
end
end
