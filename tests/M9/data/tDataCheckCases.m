classdef (TestTags = {'M9', 'DATA'}) tDataCheckCases < vital.test.VitalTestCase
%TDATACHECKCASES  D1 (docs/PLAN_DATA_LAYER.md) criterion 3 and the "data object =
%   runtime" proof of plan section 2 ("a test proves the two are equal bit for bit").
%   PRE-REGISTERED (written before the classes existed):
%   1. NASA CHECK CASES (PUB). d.aero.runChecks() replays the 16 checkData static
%      shots of F16_aero.dml and d.propulsion.runChecks() the 9 of F16_prop.dml
%      through the data object's own build-up (aero.coefficients /
%      propulsion.thrust, i.e. DaveModel.evaluate, NOT the generated code). Every
%      checked output: |actual - expected| <= the file's own <tol> (NASA's rule
%      F16_aero_verify.m:686 is strict <, also required).
%   2. DATA OBJECT = GENERATED CODE, BITWISE (REG). For each of the nine files, the
%      model object's evaluate(in) returns a struct EQUAL (isequal: every field and
%      bit) to the generated function of the same file (vital.models.f16.aero, prop,
%      inertia, control, gnc; vital.models.nesc.brick_aero, ...) at 300 seeded
%      random input sets (rng 91201; every input variable of the file drawn in
%      +-2x a scale of 100 so the saturations and table clamps are exercised), and
%      once with only the required inputs (initialValue defaults used). A random
%      input set on which the generated code raises an error must raise the SAME
%      identifier from the data object; NaN equals NaN (isequaln).
%   3. Build-up by name: d.aero.equation('cx') is the MATLAB expression of the cx
%      variableDef (non-empty and it uses cxt), and d.aero.coefficients(in) gives
%      the same cx as vital.models.f16.aero(in).

    properties
        D
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.D = struct('f16', vital.aircraft.f16.data(), 'brick', vital.aircraft.nesc.brick.data(), ...
                'cannonball', vital.aircraft.nesc.cannonball.data());
        end
    end

    methods (Test)
        function aeroCheckData(tc)
            tc.replay(tc.D.f16.aero, 16, 'F16_aero.dml checkData (NASA NESC, 16 static shots)');
        end

        function propCheckData(tc)
            tc.replay(tc.D.f16.propulsion, 9, 'F16_prop.dml checkData (NASA NESC, 9 static shots)');
        end

        function evaluateEqualsGeneratedCode(tc)
            rng(91201);
            F = dmlFiles();
            for i = 1:numel(F)
                m = dmlPart(tc.D.(F(i).aircraft), F(i).part);
                gen = str2func(F(i).generated);
                vars = m.variables;
                ins = vars(strcmp({vars.kind}, 'input'));
                nBad = 0;
                for n = 1:300
                    in = struct();
                    for v = ins(:).'
                        in.(v.varID) = 200 * (rand - 0.5) * (1 + (rand > 0.5));
                    end
                    nBad = nBad + ~sameResult(@() m.evaluate(in), @() gen(in));
                end
                req = struct();
                for v = ins(:).'
                    if isnan(v.value), req.(v.varID) = 1.5; end
                end
                nBad = nBad + ~sameResult(@() m.evaluate(req), @() gen(req));
                [~, key] = fileparts(F(i).rel);
                tc.verifyExact(nBad, 0, 'REG', ['PLAN_DATA_LAYER 2: data object = ' F(i).generated ' bit for bit'], ...
                    'Quantity', [key ' evaluations that differ']);
            end
        end

        function buildUpByName(tc)
            a = tc.D.f16.aero;
            e = a.equation('cx');
            tc.verifyNotEmpty(e);
            tc.verifyTrue(contains(e, 'cxt'), 'the cx build-up uses the CX0 table cxt');
            in = struct('vt', 500, 'alpha', 8, 'beta', 2, 'p', 0.1, 'q', 0.05, 'r', -0.1, 'el', -3, 'ail', 4, 'rdr', 2);
            c = a.coefficients(in);
            g = vital.models.f16.aero(in);
            tc.verifyExact([c.cx c.cy c.cz c.cl c.cm c.cn], [g.cx g.cy g.cz g.cl g.cm g.cn], 'REG', ...
                'build-up evaluated from the data object = generated code', 'Quantity', 'CX..Cn');
        end
    end

    methods (Access = private)
        function replay(tc, m, nExpected, citation)
            rep = m.runChecks();
            tc.verifyExact(numel(rep), nExpected, 'PUB', citation, 'Quantity', 'static shots');
            n = 0;
            for r = rep(:).'
                for o = r.outputs(:).'
                    tc.verifyTol(o.actual, o.expected, o.tol, 'abs', 'PUB', sprintf('%s, shot "%s"', citation, r.name), ...
                        'Quantity', o.varID);
                    tc.verifyTrue(abs(o.actual - o.expected) < o.tol, sprintf('%s/%s strict < tol', r.name, o.varID));
                    n = n + 1;
                end
            end
            fprintf('[tDataCheckCases] %s: %d shots, %d outputs\n', citation, numel(rep), n);
            tc.verifyWithin(n, nExpected, Inf, 'REG', 'non-vacuous', 'Quantity', 'checked outputs');
        end
    end
end

function tf = sameResult(f1, f2)
% isequaln of the two results (NaN = NaN), or the SAME error identifier from both
try
    a = f1(); ea = '';
catch e
    a = []; ea = e.identifier;
end
try
    b = f2(); eb = '';
catch e
    b = []; eb = e.identifier;
end
tf = strcmp(ea, eb) && isequaln(a, b);
end
