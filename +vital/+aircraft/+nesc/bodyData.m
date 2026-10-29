function d = bodyData(name, opts)
%BODYDATA  The NESC atmospheric test bodies (sphere, brick) as vital.data.AircraftData
%   (D1, docs/PLAN_DATA_LAYER.md, ADR-042): the same loader as the F-16, so the format
%   is exercised on three aircraft.
%   d = vital.aircraft.nesc.bodyData('brick' | 'cannonball', 'DataRoot', root)
%   Use vital.aircraft.nesc.brick.data() / vital.aircraft.nesc.cannonball.data().
%   Files (data/nesc/extracted/Atmospheric_models, SHA-256 checked):
%     <name>_aero.dml     AeroDatabase: reference S = SWING; brick b = BSPAN,
%                         cbar = CBAR; the sphere's file has no reference lengths,
%                         so b = cbar = 0.5 ft, its 6-in diameter (header of
%                         cannonball_aero.dml, the value vital.nesc.vehicle uses);
%                         CD, CL (and CY) act along the air-relative velocity
%                         (wind axes; vital.nesc.bodyLoads), Cl Cm Cn in body axes
%     <name>_inertia.dml  MassData (constant; CG at the reference point)
%   Axes: bfrp (root, the reference point), mrc = bfrp, cg at [DXCG DYCG DZCG]
%   (zero in both files). No controls, no propulsion, no control laws.
%   runtime.loadsFcn = 'vital.nesc.bodyLoads'; no runtime components: these bodies
%   run through vital.nesc.vehicle and vital.plant.derivativesRotating, so
%   vital.AircraftModel.fromData refuses them (vital:data:noRuntime).
arguments
    name (1,:) char {mustBeMember(name, {'brick', 'cannonball'})}
    opts.DataRoot (1,:) char = ''
end
folder = 'nesc/extracted/Atmospheric_models/';
pa = vital.data.DaveModel.partsFromDaveML([folder name '_aero.dml'], 'aero', 'DataRoot', opts.DataRoot);
pm = vital.data.DaveModel.partsFromDaveML([folder name '_inertia.dml'], 'mass', 'DataRoot', opts.DataRoot);
v = @(id) pa.variables(strcmp({pa.variables.varID}, id));
par = @(x, nm) vital.data.Parameter(nm, x.value, x.units, x.source, 'Description', x.name);
ref.S = par(v('SWING'), 'S');
switch name
    case 'brick'
        ref.b = par(v('BSPAN'), 'b');
        ref.cbar = par(v('CBAR'), 'cbar');
        cmap = struct('role', {'CD', 'CY', 'CL', 'Cl', 'Cm', 'Cn'}, 'varID', {'CD', 'CY', 'CL', 'Cl', 'Cm', 'Cn'}, ...
            'axes', {'wind', 'body', 'wind', 'body', 'body', 'body'});
    case 'cannonball'
        s = pa.source;
        [path, sha] = vital.data.sourceFile(s.file, 'DataRoot', opts.DataRoot);
        txt = fileread(path);
        k = regexp(txt, '6" diameter', 'once');
        line = sum(txt(1:k) == newline) + 1;
        hs = vital.data.Source(s.file, line, sha, '', 'fileHeader', ...
            'the file defines no reference lengths: 0.5 ft = the 6-in diameter of the header (as vital.nesc.vehicle)');
        ref.b = vital.data.Parameter('b', 0.5, 'ft', hs, 'Description', 'reference span = diameter');
        ref.cbar = vital.data.Parameter('cbar', 0.5, 'ft', hs, 'Description', 'reference chord = diameter');
        cmap = struct('role', {'CD', 'CY', 'CL', 'Cl', 'Cm', 'Cn'}, 'varID', {'CD', 'CY', 'CL', 'Cl', 'Cm', 'Cn'}, ...
            'axes', {'wind', 'body', 'wind', 'body', 'body', 'body'});
end
aero = vital.data.AeroDatabase(pa, ref, 'mrc', cmap);
mass = vital.data.MassData(pm, struct());
src = @(s, note) vital.data.Source(s.file, s.line, s.sha256, s.varID, s.element, note);
cgs = mass.variable('DXCG').source;
ax = struct('name', {}, 'parent', {}, 'origin', {}, 'dcm', {});
ax(1) = axisDef('bfrp', '', zeros(3, 1), src(aero.source, 'root: the reference point of the aero and inertia files'));
ax(2) = axisDef('mrc', 'bfrp', zeros(3, 1), src(aero.source, 'moments about the reference point'));
ax(3) = axisDef('cg', 'bfrp', mass.cgSI(), src(cgs, '[DXCG DYCG DZCG] ft x 0.3048'));
ms = {aero, mass};
prov = struct('file', cellfun(@(m) m.source.file, ms, 'UniformOutput', false), ...
    'sha256', cellfun(@(m) m.source.sha256, ms, 'UniformOutput', false), ...
    'role', cellfun(@(m) m.role, ms, 'UniformOutput', false), 'name', cellfun(@(m) m.name, ms, 'UniformOutput', false));
p.name = name;
p.description = sprintf('NASA NESC atmospheric check-case %s (NASA/TM-2015-218675 Vol II B.1), from %s_aero.dml and %s_inertia.dml.', ...
    name, name, name);
p.options = struct();
p.axisDefs = ax;
p.aero = aero;
p.mass = mass;
p.provenance = prov;
p.runtime = struct('loadsFcn', 'vital.nesc.bodyLoads', 'components', [], 'aeroScaleNames', {{}}, 'configMeta', {{}}, ...
    'cgAxis', 'cg', 'root', 'bfrp');
d = vital.data.AircraftData(p);
end

function a = axisDef(name, parent, origin, source)
a = struct('name', name, 'parent', parent, ...
    'origin', vital.data.Parameter([name ' origin'], origin, 'm', source, 'Description', ['origin of axis ' name]), ...
    'dcm', eye(3));
end
