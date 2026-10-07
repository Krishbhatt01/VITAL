classdef DavemlCase < vital.test.VitalTestCase
%DAVEMLCASE  Base class for DAVE-ML tests: locates the NASA files and the
%   fixtures, and compiles a parsed model into a temporary folder that is
%   removed after the test. Lives in the framework package (not tests\) so
%   the runner's excluded-file check (FC-111) never mistakes it for a test.
    methods (Static)
        function f = f16File(name)
            f = fullfile(vital.paths('data'), 'nesc', 'extracted', 'Atmospheric_models', ...
                'F16_package', 'F16_package', 'F16_S119_source', name);
        end

        function f = fixture(name)
            f = fullfile(vital.paths('tests'), 'fixtures', 'daveml', name);
        end
    end

    methods
        function fh = compileToTemp(tc, model, name)
            d = tempname; mkdir(d);
            vital.daveml.compile(model, name, d);
            addpath(d);
            tc.addTeardown(@() rmdir(d, 's'));
            tc.addTeardown(@() rmpath(d));
            fh = str2func(name);
        end
    end
end
