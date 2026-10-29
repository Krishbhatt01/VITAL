classdef (TestTags = {'M9', 'DATA'}) tDataJson < vital.test.VitalTestCase
%TDATAJSON  D1 (docs/PLAN_DATA_LAYER.md) criterion 5: the aircraft-agnostic
%   .vital.json file.
%   PRE-REGISTERED (written before the classes existed):
%   1. ROUND TRIP IS BITWISE. For the F-16, the brick and the cannonball:
%      d.save(f); d2 = vital.data.AircraftData.load(f); every double of
%      d2.toStruct() equals d.toStruct() BIT FOR BIT (private/bitsEqual: typecast to
%      uint64), every size, class and text equal. Non-vacuous: more than 3,000
%      doubles compared for the F-16.
%   2. A second save of the loaded object is BYTE-identical to the first file.
%   3. Units and provenance survive: d2.validate() passes; units, source file,
%      line, SHA-256 and varID of CXT and of geometry.S are unchanged; the loaded
%      object still works: CXT.at, aero.runChecks() all pass, and
%      AircraftModel.fromData(d2) gives the same xdot (isequal) as fromData(d) on
%      20 seeded states (rng 91301).
%   4. HARD NUMBERS. A Parameter holding [0.1 1/3 pi -0 5e-324 realmax 1+eps
%      -2.5e-310 NaN Inf -Inf] written with vital.data.writeJson and read back with
%      vital.data.readJson + Parameter.fromStruct is bitwise equal (NaN as NaN; the
%      sign of -0 kept). A 2x3x2 array keeps its shape.
%   5. A HAND-AUTHORED file (tests/M9/data/toy_glider.vital.json: plain JSON numbers
%      and arrays, the format of FRAMEWORK_GUIDE "Aircraft data objects") loads,
%      validates, and its table and build-up evaluate: CL(alpha = 5 deg) = 0.1 * 5
%      + 0.2 = 0.7 by the table's linear interpolation (ANALYTIC).
%   6. Errors: a file whose expression calls anything but arithmetic, comparisons,
%      the allowed functions and v_ variables (e.g. system('dir'); added after the first
%      sabotage run: also fprintf(v_CL_alpha), which has no quote character):
%      vital:data:badExpression; a runtime function outside the vital namespace:
%      vital:data:badRuntime; a JSON file that is not a .vital.json:
%      vital:data:badFormat.

    properties
        D
        Tmp
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.D = struct('f16', vital.aircraft.f16.data(), 'brick', vital.aircraft.nesc.brick.data(), ...
                'cannonball', vital.aircraft.nesc.cannonball.data());
            tc.Tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
        end
    end

    methods (Test)
        function roundTripBitwise(tc)
            for name = fieldnames(tc.D).'
                d = tc.D.(name{1});
                f = fullfile(tc.Tmp, [name{1} '.vital.json']);
                d.save(f);
                d2 = vital.data.AircraftData.load(f);
                [ok, n, where] = bitsEqual(d.toStruct(), d2.toStruct());
                fprintf('[tDataJson] %s: %d doubles compared bit for bit, %s\n', name{1}, n, string(ok));
                tc.verifyTrue(ok, sprintf('%s: first difference at %s', name{1}, where));
                tc.verifyExact(ok, true, 'REG', 'PLAN_DATA_LAYER 5: save/load round trip is bitwise', 'Quantity', [name{1} ' round trip']);
                if strcmp(name{1}, 'f16')
                    tc.verifyWithin(n, 3000, Inf, 'REG', 'non-vacuous', 'Quantity', 'doubles compared');
                end
                f2 = fullfile(tc.Tmp, [name{1} '_2.vital.json']);
                d2.save(f2);
                tc.verifyExact(fileread(f2), fileread(f), 'REG', 'saving the loaded object gives the same bytes', ...
                    'Quantity', [name{1} ' re-save']);
            end
        end

        function unitsProvenanceAndUseSurvive(tc)
            d = tc.D.f16;
            f = fullfile(tc.Tmp, 'f16u.vital.json');
            d.save(f);
            d2 = vital.data.AircraftData.load(f);
            d2.validate();
            a = d.aero.table('CXT'); b = d2.aero.table('CXT');
            tc.verifyTrue(isequal(a.source, b.source) && strcmp(a.units, b.units) && isequal({a.breakpoints.units}, {b.breakpoints.units}), ...
                'CXT units and source unchanged');
            tc.verifyTrue(isequal(d.geometry.S.source, d2.geometry.S.source) && strcmp(d2.geometry.S.units, 'ft2'), 'S units and source');
            tc.verifyExact(b.at('alpha', 5, 'el', 0), a.at('alpha', 5, 'el', 0), 'REG', 'loaded table lookup', 'Quantity', 'CXT(5, 0)');
            rep = d2.aero.runChecks();
            tc.verifyTrue(all([rep.pass]), 'NASA aero checkData through the LOADED data object');
            m1 = vital.AircraftModel.fromData(d);
            m2 = vital.AircraftModel.fromData(d2);
            rng(91301);
            nBad = 0;
            for i = 1:20
                [x, u, env] = dataRandomPoint();
                nBad = nBad + ~isequal(m1.derivatives(x, u, env), m2.derivatives(x, u, env));
            end
            tc.verifyExact(nBad, 0, 'REG', 'the model from the loaded file = the model from the source files', 'Quantity', 'states that differ');
        end

        function hardNumbers(tc)
            vals = [0.1 1/3 pi -0 5e-324 realmax 1+eps -2.5e-310 NaN Inf -Inf];
            src = tc.D.f16.geometry.S.source;
            p = vital.data.Parameter('hard', vals, 'nd', src);
            q = vital.data.Parameter('cube', reshape((1:12) / 7, 2, 3, 2), 'nd', src);
            f = fullfile(tc.Tmp, 'hard.json');
            vital.data.writeJson(f, struct('p', p.toStruct(), 'q', q.toStruct()));
            s = vital.data.readJson(f);
            p2 = vital.data.Parameter.fromStruct(s.p);
            q2 = vital.data.Parameter.fromStruct(s.q);
            [ok, n] = bitsEqual(p.value, p2.value);
            tc.verifyTrue(ok && n == numel(vals), 'hard numbers bitwise');
            tc.verifyTrue(1 / p2.value(4) == -Inf, 'the sign of -0 is kept');
            tc.verifyTrue(bitsEqual(q.value, q2.value), '2x3x2 array keeps shape and bits');
        end

        function handAuthoredFile(tc)
            f = fullfile(fileparts(mfilename('fullpath')), 'toy_glider.vital.json');
            d = vital.data.AircraftData.load(f);
            d.validate();
            t = d.aero.table('CL_alpha');
            tc.verifyTol(t.at('alpha', 5), 0.7, 1e-15, 'abs', 'ANALYTIC', 'linear table 0.1/deg through 0.2 at alpha 0', 'Quantity', 'CL(5 deg)');
            c = d.aero.coefficients(struct('alpha', 5));
            tc.verifyTol(c.CL, 0.7, 1e-15, 'abs', 'ANALYTIC', 'build-up CL = CL_alpha table', 'Quantity', 'CL build-up');
            tc.verifyExact(d.geometry.S.units, 'm2', 'REG', 'units as authored', 'Quantity', 'S units');
            tc.verifyTrue(d.geometry.S.si() == d.geometry.S.value, 'm2 is SI');
        end

        function loadErrors(tc)
            good = fileread(fullfile(fileparts(mfilename('fullpath')), 'toy_glider.vital.json'));
            bad1 = strrep(good, '"expression": "v_CL_alpha"', '"expression": "system(''dir'')"');
            tc.assertNotEqual(bad1, good);
            f = fullfile(tc.Tmp, 'bad1.vital.json'); fid = fopen(f, 'w'); fwrite(fid, bad1); fclose(fid);
            tc.verifyError(@() vital.data.AircraftData.load(f), 'vital:data:badExpression');
            % added after the first sabotage run (SD-9 not detected: the quote in system('dir') is
            % also refused by the character check); a call without quotes reaches the name check only
            bad4 = strrep(good, '"expression": "v_CL_alpha"', '"expression": "fprintf(v_CL_alpha)"');
            f = fullfile(tc.Tmp, 'bad4.vital.json'); fid = fopen(f, 'w'); fwrite(fid, bad4); fclose(fid);
            tc.verifyError(@() vital.data.AircraftData.load(f), 'vital:data:badExpression');
            bad2 = strrep(good, '"loadsFcn": ""', '"loadsFcn": "system"');
            tc.assertNotEqual(bad2, good);
            f = fullfile(tc.Tmp, 'bad2.vital.json'); fid = fopen(f, 'w'); fwrite(fid, bad2); fclose(fid);
            tc.verifyError(@() vital.data.AircraftData.load(f), 'vital:data:badRuntime');
            f = fullfile(tc.Tmp, 'bad3.vital.json'); fid = fopen(f, 'w'); fwrite(fid, '{"hello": 1}'); fclose(fid);
            tc.verifyError(@() vital.data.AircraftData.load(f), 'vital:data:badFormat');
        end
    end
end
