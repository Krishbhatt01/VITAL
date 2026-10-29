%RUN_DATA_EXAMPLE  Aircraft data as objects (D1; docs/PLAN_DATA_LAYER.md section 2,
%   FRAMEWORK_GUIDE "Aircraft data objects").
%
%   Run:  run_data_example        (a SCRIPT; prints only; its one JSON file goes to tempdir)
%
%   1. Reads the NESC F-16 from the NASA DAVE-ML files into a vital.data.AircraftData
%      (hash-checked against data/MANIFEST.json) and prints a summary.
%   2. Calls the data by name: the reference area with its units and source, the CXT
%      table and a lookup by input name, the T_MIL thrust table, the mass properties.
%   3. Replays the NASA checkData cases through the data object.
%   4. Builds the AircraftModel from the data and checks it against the shipped model.
%   5. Saves the aircraft-agnostic .vital.json file, loads it back and proves the round
%      trip bitwise.
%   6. Reads the NESC brick and cannonball with the same loader.

root = fileparts(mfilename('fullpath'));
addpath(root);

%% 1. the data object
f16_data = vital.aircraft.f16.data();
f16_data.summary();

%% 2. by name, with units and source
fprintf('\nReference area (a vital.data.Parameter):\n');
disp(f16_data.geometry.S);
table_cxt = f16_data.aero.table('CXT');
fprintf('Table CXT:\n');
disp(table_cxt);
cx = table_cxt.at('alpha', 5, 'el', 0);
fprintf('  CXT.at(''alpha'', 5, ''el'', 0) = %.6g (= CXT.at(''el'', 0, ''alpha'', 5) = %.6g, positional [el alpha] = %.6g)\n', ...
    cx, table_cxt.at('el', 0, 'alpha', 5), table_cxt.at([0 5]));
table_tmil = f16_data.propulsion.table('T_MIL');
fprintf('\nTable T_MIL:\n');
disp(table_tmil);
fprintf('  T_MIL at Mach 0.6, 20,000 ft = %.6g %s\n', table_tmil.at('RMACH', 0.6, 'ALT', 20000), table_tmil.units);
mass_f16 = f16_data.mass.massProperties(f16_data.axes.cg);
fprintf('\nmass_f16 = f16_data.mass.massProperties(f16_data.axes.cg):\n');
disp(mass_f16);
fprintf('  DXCG at CG_PCT_MAC = 25:'); disp(f16_data.mass.evaluated('DXCG'));
fprintf('  a gain of the NASA control law:'); disp(f16_data.controlLaw('control').parameter('longLQR11'));

%% 3. NASA check cases through the data object
rep = [f16_data.aero.runChecks(), f16_data.propulsion.runChecks()];
fprintf('\nNASA checkData through the data object: %d of %d static shots pass (F16_aero.dml 16, F16_prop.dml 9)\n', ...
    sum([rep.pass]), numel(rep));

%% 4. the model built from the data
f16 = vital.AircraftModel.fromData(f16_data);
k = vital.units.constants();
env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
cond = struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0);
tr = vital.trim.solve(f16.toRuntime(), env, cond);
same = isequal(f16.derivatives(tr.x, tr.u, env), vital.aircraft.f16.model().derivatives(tr.x, tr.u, env));
fprintf(['\nf16 = vital.AircraftModel.fromData(f16_data): README trim %s, alpha %.4f deg, de %.4f deg, throttle %.4f;\n' ...
    '  xdot identical to vital.aircraft.f16.model(): %d\n'], tr.status, rad2deg(tr.alpha), rad2deg(tr.u(1)), tr.u(4), same);
fprintf('  config() and the data object agree: S %d, mass %d, J %d, r_cg %d\n', ...
    isequal(f16_data.toConfig().S, vital.aircraft.f16.config().S), isequal(f16_data.mass.massSI(), vital.aircraft.f16.config().mass), ...
    isequal(f16_data.mass.inertiaSI(), vital.aircraft.f16.config().J), isequal(f16_data.toConfig().r_cg, vital.aircraft.f16.config().r_cg));

%% 5. the aircraft-agnostic file
file_json = fullfile(tempdir, 'f16.vital.json');
f16_data.save(file_json);
f16_loaded = vital.data.AircraftData.load(file_json);
s1 = f16_data.toStruct(); s2 = f16_loaded.toStruct();
bits = isequaln(s1, s2) && isequal(typecast(s1.aero.tables{1}.data(:), 'uint64'), typecast(s2.aero.tables{1}.data(:), 'uint64'));
d = dir(file_json);
fprintf('\nSaved %s (%.0f kB) and loaded it back: round trip bitwise %d; CXT(5, 0) from the file = %.6g\n', ...
    file_json, d.bytes / 1024, bits, f16_loaded.aero.table('CXT').at('alpha', 5, 'el', 0));
delete(file_json);

%% 6. the same format for other aircraft
brick_data = vital.aircraft.nesc.brick.data();
cannonball_data = vital.aircraft.nesc.cannonball.data();
fprintf('\n');
brick_data.summary();
cannonball_data.summary();
fprintf(['\nA later aircraft (e.g. the X-57) is written as a .vital.json file in the same format and read with\n' ...
    '  x57_data = vital.data.AircraftData.load(''x57.vital.json'')   (FRAMEWORK_GUIDE, "Aircraft data objects")\n']);
