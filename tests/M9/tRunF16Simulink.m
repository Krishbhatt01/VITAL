classdef (TestTags = {'M9'}) tRunF16Simulink < vital.test.VitalTestCase
%TRUNF16SIMULINK  M9-A user entry point run_f16_simulink (PLAN_M9 4):
%   trims at the README point, runs the Simulink path and vital.sim.run with the
%   M7 SAS (Kq 0.02, Ka 0.14, Kr 0.82) and an elevator doublet, returns the
%   comparison (E <= 1e-9, PLAN_M9 7), prints it and draws a figure (saved as PNG
%   when SaveDir is given).

    methods (Test)
        function entryPointCompares(tc)
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.addTeardown(@() close('all'));
            res = [];
            txt = evalc('res = run_f16_simulink(''tFinal'', 2, ''Plot'', true, ''SaveDir'', d);');
            tc.verifyEqual(res.slx.status, 'COMPLETED');
            tc.verifyEqual(res.mat.status, 'COMPLETED');
            tc.verifyWithin(res.cmp.E, 0, 1e-9, 'INDEP', 'PLAN_M9 7', 'Quantity', 'entry point E');
            tc.verifyNotEmpty(regexp(txt, 'max scaled state difference', 'once'), 'summary printed');
            tc.verifyNotEmpty(dir(fullfile(d, '*.png')), 'figure saved');
        end
    end
end
