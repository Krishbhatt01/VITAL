classdef (TestTags = {'M9'}) tSlxBuild < vital.test.VitalTestCase
%TSLXBUILD  M9-A: the generated Simulink model (docs/PLAN_M9.md sections 2, 4, 8).
%   PRE-REGISTERED (before vital.slx existed):
%   1. Two builds from the same script give the same structure hash (blocks,
%      types, key parameters, MATLAB Function code, lines, solver settings).
%   2. Block list, exactly: Clock (DigitalClock; BlockType name corrected after the RED run, the registered block is the Digital Clock), FCS (MATLAB Function),
%      Integrator (Integrator), Plant (MATLAB Function), u (Outport), x (Outport),
%      and exactly 7 links (source/port->destination/port): Clock->FCS/1,
%      Integrator->FCS/2, Integrator->Plant/1, Integrator->x, FCS->Plant/2, FCS->u,
%      Plant->Integrator.
%   3. The committed models/VitalPlant.slx has the hash of a fresh build: it is a
%      generated artifact and was not edited by hand.
%   4. Solver: SolverType Fixed-step, Solver ode4 (a continuous fixed-step solver;
%      FixedStepDiscrete would not integrate the Integrator), FixedStep is the
%      variable dt, StartTime 0. A run reports ode4, the step dt and stop time N dt.

    properties
        Tmp
    end

    methods (TestClassSetup)
        function makeTmp(tc)
            tc.Tmp = tempname; mkdir(tc.Tmp);
            tc.addTeardown(@() rmdir(tc.Tmp, 's'));
        end
    end

    methods (Test)
        function buildIsReproducible(tc)
            d1 = fullfile(tc.Tmp, 'b1'); d2 = fullfile(tc.Tmp, 'b2');
            s1 = vital.slx.build('Folder', d1);
            s2 = vital.slx.build('Folder', d2);
            tc.verifyTrue(isfile(fullfile(d1, 'VitalPlant.slx')), 'model file written');
            tc.verifyExact(s2.hash, s1.hash, 'REG', 'PLAN_M9 8: same script, same structure', 'Quantity', 'structure hash');
            tc.verifyExact(s2.text, s1.text, 'REG', 'PLAN_M9 8', 'Quantity', 'structure text');
        end

        function blockListAsRegistered(tc)
            s = vital.slx.build('Folder', fullfile(tc.Tmp, 'b3'));
            names = sort({s.blocks.name});
            tc.verifyEqual(names, {'Clock', 'FCS', 'Integrator', 'Plant', 'u', 'x'});
            types = containers.Map({s.blocks.name}, {s.blocks.type});
            tc.verifyEqual(types('Integrator'), 'Integrator');
            tc.verifyEqual(types('Clock'), 'DigitalClock');
            tc.verifyEqual(types('x'), 'Outport');
            tc.verifyEqual(types('u'), 'Outport');
            tc.verifyEqual(types('Plant'), 'MATLAB Function');
            tc.verifyEqual(types('FCS'), 'MATLAB Function');
            tc.verifyEqual(sort(s.lines), sort({'Clock/1->FCS/1', 'Integrator/1->FCS/2', 'Integrator/1->Plant/1', ...
                'Integrator/1->x/1', 'FCS/1->Plant/2', 'FCS/1->u/1', 'Plant/1->Integrator/1'}));
        end

        function committedArtifactIsUnedited(tc)
            f = vital.slx.modelFile();
            tc.assertTrue(isfile(f), ['missing ' f]);
            sc = vital.slx.structure(f);
            sf = vital.slx.build('Folder', fullfile(tc.Tmp, 'b4'));
            tc.verifyExact(sc.hash, sf.hash, 'REG', ...
                'PLAN_M9 4: models/VitalPlant.slx must equal a fresh vital.slx.build (regenerate, never hand-edit)', ...
                'Quantity', 'committed vs regenerated structure hash');
        end

        function solverConfiguration(tc)
            s = vital.slx.build('Folder', fullfile(tc.Tmp, 'b5'));
            tc.verifyEqual(s.solver.SolverType, 'Fixed-step');
            tc.verifyEqual(s.solver.Solver, 'ode4');
            tc.verifyEqual(s.solver.FixedStep, 'dt');
            tc.verifyEqual(s.solver.StartTime, '0');
        end

        function runReportsSolverStepAndStopTime(tc)
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            env = struct('g', 32.174 * 0.3048, 'wind_n', [0; 0; 0], 'deltaT', 0);
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'CG', 25, 'g_ftps2', 32.174);
            out = vital.slx.simulate(AC, env, r.trim.x, r.trim.u, 'dt', 0.02, 'tFinal', 0.3);
            tc.verifyEqual(out.slx.solver, 'ode4');
            tc.verifyTol(out.slx.fixedStep, 0.02, 1e-15, 'abs', 'ANALYTIC', 'dt passed through', 'Quantity', 'FixedStep', 'Unit', 's');
            tc.verifyTol(out.slx.stopTime, 0.3, 1e-12, 'abs', 'ANALYTIC', 'StopTime = N dt', 'Quantity', 'StopTime', 'Unit', 's');
            tc.verifyNumElements(out.t, 16);
        end
    end
end
