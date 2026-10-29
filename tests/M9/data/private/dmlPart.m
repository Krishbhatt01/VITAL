function m = dmlPart(d, part)
%DMLPART  The vital.data model object of an AircraftData that holds one file part.
switch part
    case 'aero', m = d.aero;
    case 'propulsion', m = d.propulsion;
    case 'mass', m = d.mass;
    otherwise, m = d.controlLaw(part);
end
end
