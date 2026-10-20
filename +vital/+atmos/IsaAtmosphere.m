classdef IsaAtmosphere < vital.atmos.Atmosphere
%ISAATMOSPHERE  ISA via the Aerospace Toolbox atmosisa (vital.env.atmosphere).
%   A = vital.atmos.IsaAtmosphere()                 standard day
%   A = vital.atmos.IsaAtmosphere('DeltaT', 10)     ISA + 10 K
%   atm = A.at(h)  is  vital.env.atmosphere(h, 'DeltaT', A.DeltaT)
%   Geometric height in; out of range -> vital:env:altitudeOutOfRange.
    methods
        function obj = IsaAtmosphere(opts)
            arguments
                opts.DeltaT (1,1) double = 0
            end
            vital.validate.finite(opts.DeltaT, 'DeltaT');
            obj.DeltaT = opts.DeltaT;
        end
        function atm = at(obj, h)
            atm = vital.env.atmosphere(h, 'DeltaT', obj.DeltaT);
        end
    end
end
