classdef (TestTags = {'M9', 'I0'}) tI0NescAircraftModel < vital.test.VitalTestCase
%TI0NESCAIRCRAFTMODEL  Increment I0 (ADR-041): NON-F-16 vehicles with PUBLISHED answers
%   built as vital.AircraftModel objects with ZERO controls: the NESC dropped sphere
%   (case 1), the tumbling bricks (cases 2, 3) and the cannonballs (cases 9, 10).
%   Fixtures: tests/reference/nescAircraftModel.m (rotated CG axis with the inertia
%   in its components; aero data on a ROTATED and OFFSET axis) and
%   tests/reference/nescModelRun.m (model.toRuntime() -> vital.sim.run with
%   vital.plant.derivativesRotating; the case's env, x0, dt, duration and guards
%   from vital.nesc.caseDef; no production change).
%   Cases 4-8 use the same two vehicles in other Earth/wind environments; they stay
%   covered by tests/M5/tNescCases01to10.m through the struct path and are left out
%   here to keep this file near the 60 s budget (docs/AGENT_BRIEF.md).
%
%   PRE-REGISTERED:
%   1. caseNN (PUB): exactly the M5 criterion of tests/M5/tNescCases01to10.m: for
%      every band signal of the case, VITAL lies in [min_s ref_s - delta, max_s ref_s
%      + delta] on the reference time base, delta = max(floor, rel_floor max|ref|,
%      k spread) as registered in docs/NESC_CASE_MATRIX.json (ADR-009/015;
%      vital.nesc.compare). Reported quantity: the worst envelope excess (<= 0 passes).
%      The run must COMPLETE (no guard stop).
%   2. modelPathEqualsStructPath (REG, 1e-9 of each signal's max |value| plus 1e-3 of
%      its registered band floor, so that a signal that is exactly 0 on the struct path,
%      e.g. the sphere's moment about the CM, may carry the round-off of the offset
%      transfer, ~1e-16 of |d x F|): for case 3
%      (brick with damping: moments) and case 9 (cannonball with drag: forces), every
%      NESC signal of the model path equals vital.nesc.runCase (the vehicle struct
%      path). Both integrate the same physics with the same RK4 steps; the model path
%      only adds rotations by orthonormal DCMs and an offset transfer, i.e. round-off
%      of order 1e-15 per step, amplified over 3,000 steps of a smooth system; 1e-9
%      leaves a wide margin and still catches any physics difference, which the bands
%      would see at about 1e-4 (density) to 1e-6 (forces) of scale. This also checks
%      the copy of runCase's signal mapping in nescModelRun.m.
%   3. zeroControlModelBuilds (ANALYTIC): the model has no controls, its compiled
%      axes are NOT identities (the rotation path is exercised), and its compiled
%      inertia about the CG in body axes equals the published tensor
%      (vital.nesc.vehicle J, 1e-12 of its largest entry).

    properties (Constant)
        Cite = 'NESC Atmos CSVs (TM-2015-218675 Vol II App. D); band NESC_CASE_MATRIX.json (ADR-009), vehicle as AircraftModel'
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
        end
    end

    methods (Access = private)
        function checkCase(tc, id)
            res = nescModelRun(id);
            tc.assertEqual(res.status, 'COMPLETED', sprintf('case %s stopped: %s', id, res.stopReason));
            cmp = vital.nesc.compare(res);
            for c = cmp(:).'
                if strcmp(c.status, 'NOT_ASSESSABLE')
                    tc.verifyFail(sprintf('case %s %s NOT_ASSESSABLE: %s', id, c.signal, c.reason));
                    continue
                end
                tc.verifyWithin(c.worst, -Inf, 0, 'PUB', tc.Cite, ...
                    'Quantity', sprintf('case %s %s envelope excess (AircraftModel)', id, c.signal), 'Unit', c.unit);
            end
        end
    end

    methods (Test)
        function case01DroppedSphere(tc), tc.checkCase('1'); end
        function case02TumblingBrick(tc), tc.checkCase('2'); end
        function case03TumblingBrickDamped(tc), tc.checkCase('3'); end
        function case09EastwardCannonball(tc), tc.checkCase('9'); end
        function case10NorthwardCannonball(tc), tc.checkCase('10'); end

        function modelPathEqualsStructPath(tc)
            for id = {'3', '9'}
                a = nescModelRun(id{1});
                b = vital.nesc.runCase(id{1});
                tc.assertEqual(a.t, b.t);
                band = b.caseDef.band;
                for f = fieldnames(b.sig).'
                    s = b.sig.(f{1});
                    j = find(strcmp({band.signal}, f{1}), 1);
                    fl = 0; if ~isempty(j), fl = band(j).floor; end
                    tc.verifyTol(a.sig.(f{1}), s, 1e-9 * max(abs(s)) + 1e-3 * fl, 'abs', 'REG', 'class header 2: same physics, same RK4 steps', ...
                        'Quantity', sprintf('case %s %s model - struct', id{1}, f{1}), 'Unit', b.units.(f{1}));
                end
            end
        end

        function zeroControlModelBuilds(tc)
            for v = {'brick', 'cannonball'}
                m = nescAircraftModel(v{1}, struct());
                ACv = vital.nesc.vehicle(v{1});
                tc.verifyEmpty(m.Controls, 'a NESC vehicle has no controls');
                tc.verifyFalse(any(m.Compiled.identity), 'the aero data axis must be rotated (rotation path exercised)');
                tc.verifyTol(m.Compiled.J, ACv.J, 1e-12 * max(abs(ACv.J(:))), 'abs', 'ANALYTIC', ...
                    'C'' (C J C'') C = J for the rotated CG axis (class header 3)', ...
                    'Quantity', [v{1} ' compiled J about the CG, body axes'], 'Unit', 'kg m^2');
            end
        end
    end
end
