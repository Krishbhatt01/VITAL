classdef (TestTags = {'M9', 'DATA'}) tDataValidate < vital.test.VitalTestCase
%TDATAVALIDATE  D1 (docs/PLAN_DATA_LAYER.md) criteria 6 and 7: validation of units
%   and provenance, and the read-only, hash-checked data folder.
%   PRE-REGISTERED (written before the classes existed):
%   1. NO PROVENANCE IS AN ERROR: a Parameter without a source, a Table whose source
%      is removed (withSource([])), and an AircraftData whose struct has one table's
%      source removed (fromStruct, which validates) all raise
%      vital:data:noProvenance from validate(). A source with a malformed SHA-256
%      (not 64 hex) is not a valid source either (noProvenance).
%   2. NO UNITS IS AN ERROR: a Parameter with units '' and an AircraftData with the
%      units of geometry.S removed raise vital:data:noUnits.
%   3. data/ UNCHANGED (PUB: data/MANIFEST.json): each of the nine DAVE-ML files hashes
%      to its manifest SHA-256 through vital.data.sourceFile (which returns the hash
%      it checked) and through vital.io.sha256File directly.
%   4. A CHANGED FILE IS REFUSED: the five F-16 files copied to a temporary data root
%      (same relative paths) load with vital.aircraft.f16.data('DataRoot', tmp) and
%      equal the real one (toStruct isequaln); after ONE byte is appended to the copy
%      of F16_inertia.dml the same call raises vital:data:hashMismatch, and so does
%      d.verifySources('DataRoot', tmp) for an object read earlier; d.verifySources()
%      on the real data passes. A path not in the manifest:
%      vital:data:notInManifest.

    properties
        D
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.D = vital.aircraft.f16.data();
        end
    end

    methods (Test)
        function noProvenanceIsError(tc)
            src = tc.D.geometry.S.source;
            tc.verifyError(@() vital.data.Parameter('S', 300, 'ft2', []).validate(), 'vital:data:noProvenance');
            t = tc.D.aero.table('CXT');
            t.validate();
            tc.verifyError(@() t.withSource([]).validate(), 'vital:data:noProvenance');
            s = tc.D.toStruct();
            s.aero.tables{1}.source = [];
            tc.verifyError(@() vital.data.AircraftData.fromStruct(s), 'vital:data:noProvenance');
            bad = vital.data.Source(src.file, src.line, 'abc', src.varID, src.element, '');
            tc.verifyFalse(bad.isValid());
            tc.verifyError(@() vital.data.Parameter('S', 300, 'ft2', bad).validate(), 'vital:data:noProvenance');
            vital.data.Parameter('S', 300, 'ft2', src).validate();      % a complete one passes
        end

        function noUnitsIsError(tc)
            src = tc.D.geometry.S.source;
            tc.verifyError(@() vital.data.Parameter('S', 300, '', src).validate(), 'vital:data:noUnits');
            tc.verifyError(@() vital.data.unitFactor('furlong'), 'vital:data:unknownUnits');   % added after GREEN (FC-1079)
            s = tc.D.toStruct();
            s.aero.reference.S.units = '';
            tc.verifyError(@() vital.data.AircraftData.fromStruct(s), 'vital:data:noUnits');
        end

        function dataFolderUnchanged(tc)
            F = dmlFiles();
            manifest = jsondecode(fileread(fullfile(vital.paths('data'), 'MANIFEST.json')));
            mf = manifest.files; if isstruct(mf), mf = num2cell(mf); end
            for i = 1:numel(F)
                e = mf{find(cellfun(@(x) strcmp(x.path, F(i).rel), mf), 1)};
                [p, sha] = vital.data.sourceFile(F(i).rel);
                tc.verifyExact(sha, e.sha256, 'PUB', 'data/MANIFEST.json', 'Quantity', [F(i).rel ' (sourceFile)']);
                tc.verifyExact(vital.io.sha256File(p), e.sha256, 'PUB', 'data/MANIFEST.json', 'Quantity', [F(i).rel ' (direct)']);
            end
        end

        function changedFileIsRefused(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            F = dmlFiles();
            F = F(strcmp({F.aircraft}, 'f16'));
            for i = 1:numel(F)
                dst = fullfile(tmp, F(i).rel);
                if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
                copyfile(fullfile(vital.paths('data'), F(i).rel), dst);
            end
            d2 = vital.aircraft.f16.data('DataRoot', tmp);
            tc.verifyTrue(isequaln(d2.toStruct(), tc.D.toStruct()), 'an untouched copy gives the same data object');
            tc.D.verifySources();
            tc.D.verifySources('DataRoot', tmp);
            fid = fopen(fullfile(tmp, F(3).rel), 'a'); fwrite(fid, ' '); fclose(fid);
            tc.verifyError(@() vital.aircraft.f16.data('DataRoot', tmp), 'vital:data:hashMismatch');
            tc.verifyError(@() tc.D.verifySources('DataRoot', tmp), 'vital:data:hashMismatch');
            tc.verifyError(@() vital.data.sourceFile('nesc/extracted/no_such_file.dml'), 'vital:data:notInManifest');
        end
    end
end
