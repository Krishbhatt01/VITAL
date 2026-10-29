classdef (TestTags = {'M9', 'DATA'}) tDataInventory < vital.test.VitalTestCase
%TDATAINVENTORY  D1 (docs/PLAN_DATA_LAYER.md) criteria 1 and 6: every entry of the
%   nine NASA DAVE-ML files is in the data objects, with the file's values, units
%   and source line, and every number carries units and a source.
%   PRE-REGISTERED (written before the classes existed):
%   1. COMPLETENESS (PUB, exact). For each of the nine files (dmlFiles: the five
%      F-16 files, brick_{aero,inertia}, cannonball_{aero,inertia}), an INDEPENDENT
%      regular-expression scan of the file text (private/dmlScan, no XML parser, no
%      vital.daveml.read) lists every variableDef, breakpointDef and function
%      (table). Each must be in the data object that holds the file
%      (vital.aircraft.f16.data(), vital.aircraft.nesc.brick.data(),
%      vital.aircraft.nesc.cannonball.data()):
%        variableDef  -> d.<part>.variable(varID): units equal to the attribute, the
%                        initialValue (when the file gives one) equal to the
%                        attribute's number EXACTLY, source.line equal to the line
%                        of the start tag, source.varID = varID;
%        breakpointDef-> d.<part>.breakpoint(bpID): values EXACTLY the <bpVals>,
%                        units, line;
%        function     -> d.<part>.table(output varID): data, in the file's order
%                        (last breakpoint fastest), EXACTLY the <dataTable> of its
%                        griddedTable, breakpoints in breakpointRefs order with the
%                        bpIDs and input names of the file, units = the output
%                        variable's units, source.line = the <function> line.
%      Every file's source carries the file's SHA-256 (= data/MANIFEST.json).
%      Any missing entry is LISTED in the failure message. Expected counts
%      (from the scan, non-vacuous): F-16 aero 50 variables, 4 breakpoint sets,
%      18 tables; prop 13 / 2 / 3; inertia 12; control 81; gnc 94; brick aero 21,
%      brick inertia 10, cannonball aero 7, cannonball inertia 10 variables.
%   2. UNITS AND SOURCE ON EVERYTHING (criterion 6). Every vital.data.Parameter
%      (geometry, limits, axis origins, every variable), every Table and every
%      Breakpoint of the three aircraft has non-empty units and a valid source
%      (file, line >= 1, 64-hex SHA-256). d.validate() passes on all three.
%      ADDED AFTER THE FIRST GREEN RUN (stricter): every units string is known to
%      vital.data.unitFactor.
%   3. CHECK CASES. The F-16 aero carries 16 checkData static shots and the prop 9,
%      each with the line of its <staticShot> (PUB: F16_aero.dml, F16_prop.dml).
%   4. GEOMETRY BY NAME (PUB, F16_aero.dml variableDefs sref, bspan, cbar):
%      d.geometry.S.value = 300 ft2 (si 300*0.3048^2), b = 30 ft, cbar = 11.32 ft,
%      sources at the variableDef lines of sref, bspan and cbar.

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
        function everyEntryPresentWithFileValues(tc)
            F = dmlFiles();
            expected = struct('F16_aero', [50 4 18], 'F16_prop', [13 2 3], 'F16_inertia', [12 0 0], ...
                'F16_control', [81 0 0], 'F16_gnc', [94 0 0], 'brick_aero', [21 0 0], 'brick_inertia', [10 0 0], ...
                'cannonball_aero', [7 0 0], 'cannonball_inertia', [10 0 0]);
            manifest = jsondecode(fileread(fullfile(vital.paths('data'), 'MANIFEST.json')));
            mf = manifest.files; if isstruct(mf), mf = num2cell(mf); end
            for i = 1:numel(F)
                file = fullfile(vital.paths('data'), F(i).rel);
                S = dmlScan(file);
                [~, key] = fileparts(F(i).rel);
                tc.verifyExact([numel(S.vars) numel(S.bps) numel(S.fns)], expected.(key), 'PUB', ...
                    [F(i).rel ': entries counted in the file'], 'Quantity', [key ' counts']);
                m = dmlPart(tc.D.(F(i).aircraft), F(i).part);
                k = find(cellfun(@(e) strcmp(e.path, F(i).rel), mf), 1);
                tc.verifyExact(m.source.sha256, mf{k}.sha256, 'PUB', 'data/MANIFEST.json', 'Quantity', [key ' SHA-256']);
                tc.verifyExact(m.source.file, F(i).rel, 'REG', 'source file relative to the data root', 'Quantity', [key ' file']);
                missing = {};
                for v = S.vars
                    try
                        x = m.variable(v.varID);
                    catch
                        missing{end+1} = sprintf('%s variableDef %s (line %d)', key, v.varID, v.line); %#ok<AGROW>
                        continue
                    end
                    ok = strcmp(x.varID, v.varID) && strcmp(x.units, v.units) && x.source.line == v.line && ...
                        strcmp(x.source.varID, v.varID) && strcmp(x.source.sha256, m.source.sha256);
                    if ~isnan(v.initialValue), ok = ok && isequal(x.value, v.initialValue); end
                    if ~ok, missing{end+1} = sprintf('%s variableDef %s: value/units/line differ', key, v.varID); end %#ok<AGROW>
                end
                for b = S.bps
                    try
                        x = m.breakpoint(b.bpID);
                    catch
                        missing{end+1} = sprintf('%s breakpointDef %s (line %d)', key, b.bpID, b.line); %#ok<AGROW>
                        continue
                    end
                    if ~(isequal(x.values, b.vals) && strcmp(x.units, b.units) && x.source.line == b.line)
                        missing{end+1} = sprintf('%s breakpointDef %s: values/units/line differ', key, b.bpID); %#ok<AGROW>
                    end
                end
                for f = S.fns
                    try
                        t = m.table(f.output);
                    catch
                        missing{end+1} = sprintf('%s function %s -> %s (line %d)', key, f.name, f.output, f.line); %#ok<AGROW>
                        continue
                    end
                    g = S.gts(strcmp({S.gts.gtID}, f.gtID));
                    d = numel(g.bpIDs);
                    if d > 1, inFileOrder = reshape(permute(t.data, d:-1:1), 1, []); else, inFileOrder = reshape(t.data, 1, []); end
                    vo = S.vars(strcmp({S.vars.varID}, f.output));
                    ok = isequal(inFileOrder, g.vals) && isequal({t.breakpoints.bpID}, g.bpIDs) && ...
                        isequal({t.breakpoints.name}, f.inputs) && strcmp(t.units, vo.units) && t.source.line == f.line && ...
                        strcmp(t.varID, f.output);
                    for j = 1:d
                        bj = S.bps(strcmp({S.bps.bpID}, g.bpIDs{j}));
                        ok = ok && isequal(t.breakpoints(j).values, bj.vals) && strcmp(t.breakpoints(j).units, bj.units);
                    end
                    if ~ok, missing{end+1} = sprintf('%s table %s: data/breakpoints/units/line differ', key, f.output); end %#ok<AGROW>
                end
                tc.verifyEmpty(missing, sprintf('entries missing or different in the data object:\n%s', strjoin(missing, newline)));
                tc.verifyExact(numel(missing), 0, 'PUB', [F(i).rel ' every entry present with the file''s values'], ...
                    'Quantity', [key ' missing entries']);
            end
        end

        function everyItemHasUnitsAndSource(tc)
            for name = fieldnames(tc.D).'
                d = tc.D.(name{1});
                d.validate();                                  % errors vital:data:noUnits / noProvenance
                items = {};
                for g = fieldnames(d.geometry).', items{end+1} = d.geometry.(g{1}); end %#ok<AGROW>
                for g = fieldnames(d.limits).', items{end+1} = d.limits.(g{1}); end %#ok<AGROW>
                for a = d.axisDefs(:).', items{end+1} = a.origin; end %#ok<AGROW>
                ms = d.models();
                for k = 1:numel(ms)
                    items = [items, num2cell(ms{k}.variables), num2cell(ms{k}.tables), num2cell(ms{k}.breakpoints)]; %#ok<AGROW>
                end
                bad = {};
                for k = 1:numel(items)
                    it = items{k};
                    if isempty(it.units) || isempty(it.source) || ~it.source.isValid() || ~knownUnits(it.units)
                        bad{end+1} = sprintf('%s %s', class(it), it.name); %#ok<AGROW>
                    end
                end
                tc.verifyExact(numel(bad), 0, 'REG', 'PLAN_DATA_LAYER criterion 6: units and source on everything', ...
                    'Quantity', [name{1} ' items without units or source']);
                tc.verifyEmpty(bad, strjoin(bad, newline));
                tc.verifyWithin(numel(items), 20, Inf, 'REG', 'non-vacuous', 'Quantity', [name{1} ' items checked']);
            end
        end

        function checkCasesCarriedWithLines(tc)
            F = dmlFiles();
            exp = struct('aero', 16, 'propulsion', 9);
            for part = {'aero', 'propulsion'}
                m = dmlPart(tc.D.f16, part{1});
                S = dmlScan(fullfile(vital.paths('data'), F(strcmp({F.part}, part{1}) & strcmp({F.aircraft}, 'f16')).rel));
                tc.verifyExact(numel(m.checkCases), exp.(part{1}), 'PUB', 'checkData staticShots in the file', ...
                    'Quantity', [part{1} ' check cases']);
                tc.verifyExact([m.checkCases.line], [S.shots.line], 'PUB', 'staticShot lines', 'Quantity', [part{1} ' check lines']);
                tc.verifyExact({m.checkCases.name}, {S.shots.name}, 'PUB', 'staticShot names', 'Quantity', [part{1} ' check names']);
            end
            tc.verifyExact(numel(tc.D.f16.checkCases), 25, 'PUB', '16 aero + 9 prop static shots', 'Quantity', 'all check cases');
        end

        function geometryByName(tc)
            k = vital.units.constants();
            g = tc.D.f16.geometry;
            F = dmlFiles();
            S = dmlScan(fullfile(vital.paths('data'), F(1).rel));
            line = @(id) S.vars(strcmp({S.vars.varID}, id)).line;
            tc.verifyExact([g.S.value g.b.value g.cbar.value], [300 30 11.32], 'PUB', 'F16_aero.dml sref, bspan, cbar', 'Quantity', 'S b cbar');
            tc.verifyExact({g.S.units g.b.units g.cbar.units}, {'ft2', 'ft', 'ft'}, 'PUB', 'F16_aero.dml units', 'Quantity', 'units');
            tc.verifyExact([g.S.si() g.b.si() g.cbar.si()], [300 * k.ft^2, 30 * k.ft, 11.32 * k.ft], 'ANALYTIC', ...
                'CONVENTIONS 1: ft = 0.3048 m exactly', 'Quantity', 'S b cbar SI');
            tc.verifyExact([g.S.source.line g.b.source.line g.cbar.source.line], [line('sref') line('bspan') line('cbar')], ...
                'PUB', 'variableDef lines', 'Quantity', 'geometry source lines');
            tc.verifyExact({g.S.source.varID g.b.source.varID g.cbar.source.varID}, {'sref', 'bspan', 'cbar'}, 'PUB', ...
                'DAVE-ML varIDs', 'Quantity', 'geometry varIDs');
        end
    end
end

function tf = knownUnits(u)
% added after GREEN (PLAN_DEVIATIONS test correction 3): the units string has an SI factor
try
    vital.data.unitFactor(u);
    tf = true;
catch
    tf = false;
end
end
