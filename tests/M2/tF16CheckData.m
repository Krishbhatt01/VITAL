classdef (TestTags = {'M2'}) tF16CheckData < vital.test.DavemlCase
%TF16CHECKDATA  M2: the generated F-16 models reproduce every <checkData>
%   static shot embedded in the NASA DAVE-ML files, to the tolerance each
%   file states. This is the published evidence that VITAL implements the
%   same F-16 as NASA's tools (NESC_EXTRACT_F16.md B.1, B.2).

    methods (Test)
        function aeroCheckData(tc)
            m = vital.daveml.read(tc.f16File('F16_aero.dml'));
            tc.replayShots(m, @vital.models.f16.aero, 'F16_aero.dml');
        end

        function propCheckData(tc)
            m = vital.daveml.read(tc.f16File('F16_prop.dml'));
            tc.replayShots(m, @vital.models.f16.prop, 'F16_prop.dml');
        end

        function inertiaAtNescCg(tc)
            o = vital.models.f16.inertia(struct('CG_PCT_MAC', 25));
            c = 'F16_inertia.dml:141-160: DXCG = 0.01 CBAR (35 - CG_PCT_MAC); NESC tests use 25 % (TM Vol II p.604)';
            tc.verifyTol(o.DXCG, 1.132, 1e-12, 'abs', 'PUB', c, 'Quantity', 'DXCG at 25 %', 'Unit', 'ft');
            tc.verifyTol(o.XMASS, 637.1595, 0, 'abs', 'PUB', 'F16_inertia.dml:111', 'Quantity', 'XMASS', 'Unit', 'slug');
            tc.verifyTol([o.XIXX o.XIYY o.XIZZ o.XIZX], [9496 55814 63100 982], 0, 'abs', 'PUB', 'F16_inertia.dml:63-87', ...
                'Quantity', 'inertias', 'Unit', 'slug ft2');
            tc.verifyTol(vital.models.f16.inertia(struct()).DXCG, 0, 0, 'abs', 'PUB', 'default CG_PCT_MAC = 35 % (initialValue)', ...
                'Quantity', 'DXCG default', 'Unit', 'ft');
        end

        function generatedFilesAreCurrent(tc)
            % The committed generated models are exactly what the compiler produces from
            % the hashed NASA sources today (no hand edits; deterministic generation).
            d = tempname; mkdir(d); c = onCleanup(@() rmdir(d, 's'));
            vital.aircraft.f16.generateModels(d);
            pkg = fullfile(vital.paths('root'), '+vital', '+models', '+f16');
            for n = {'aero', 'prop', 'inertia'}
                a = fileread(fullfile(pkg, [n{1} '.m']));
                b = fileread(fullfile(d, [n{1} '.m']));
                tc.verifyTrue(strcmp(a, b), ['generated +vital/+models/+f16/' n{1} '.m differs from a fresh compile']);
            end
        end

        function checkDataMismatchIsDetected(tc)
            % FC-205: a corrupted table must be caught by the checkData replay.
            m = vital.daveml.read(tc.f16File('F16_aero.dml'));
            k = find(strcmp({m.functions.output}, 'cxt'));
            % Corrupt CX at (el = 0 deg, alpha = 5 deg): the grid point the "Nominal" shot
            % (alpha 5, el 0; F16_aero.dml:1564) evaluates, so the replay must see it.
            m.functions(k).data(3, 4) = m.functions(k).data(3, 4) + 0.01;
            fh = tc.compileToTemp(m, 'vitalfx_corruptaero');
            tc.verifyError(@() vital.daveml.runCheckData(m, fh, 'Strict', true), 'vital:daveml:checkDataMismatch');
        end
    end

    methods (Access = private)
        function replayShots(tc, m, fh, fileName)
            rep = vital.daveml.runCheckData(m, fh);
            tc.assertNumElements(rep, numel(m.checks));
            for s = rep(:)'
                for o = s.outputs(:)'
                    tc.verifyTol(o.actual, o.expected, o.tol, 'abs', 'PUB', ...
                        sprintf('%s checkData "%s"', fileName, s.name), 'Quantity', [s.name ': ' o.varID]);
                end
                for iv = s.internal(:)'
                    tc.verifyTol(iv.actual, iv.expected, 1e-6, 'abs', 'PUB', ...
                        sprintf('%s internalValues "%s"', fileName, s.name), 'Quantity', [s.name ': internal ' iv.varID]);
                end
            end
        end
    end
end
