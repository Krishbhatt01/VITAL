classdef (TestTags = {'M9', 'DATA'}) tDataExample < vital.test.VitalTestCase
%TDATAEXAMPLE  D1: run_data_example.m runs and shows the calls of
%   docs/PLAN_DATA_LAYER.md section 2.
%   PRE-REGISTERED (written before the example existed): the script runs without
%   error, writes nothing in the VITAL tree (its JSON goes to tempdir) and prints
%   the geometry S with its source (F16_aero.dml), the CXT table and a CXT value
%   by name, the T_MIL table, the mass properties, the NASA check-case result
%   (25 of 25 static shots pass), the model built from the data, the save/load
%   round trip (bitwise) and the brick and cannonball summaries.

    methods (Test)
        function exampleRuns(tc)
            before = dir(vital.paths('root'));
            out = evalc('run_data_example');
            after = dir(vital.paths('root'));
            tc.verifyEqual(sort({after.name}), sort({before.name}), 'no file written in the VITAL root');
            for s = {'F16_aero.dml', 'CXT', 'T_MIL', 'MassProperties', '25 of 25', 'fromData', 'bitwise', 'brick', 'cannonball'}
                tc.verifySubstring(out, s{1});
            end
        end
    end
end
