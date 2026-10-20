classdef (Abstract) Atmosphere
%ATMOSPHERE  Abstract atmosphere model (0.8.1-OOP, ADR-037).
%   atm = A.at(h)   struct of arrays the size of h (geometric height, m):
%                   T (K), p (Pa), rho (kg/m^3), a (m/s), H (geopotential, m), h
%   DeltaT          ISA + dT offset (K), carried to the plant as env.deltaT
%   The plant (vital.plant.derivatives) always evaluates vital.env.atmosphere
%   (atmosisa) with env.deltaT; a subclass describes that same atmosphere to the
%   object layer. Concrete: vital.atmos.IsaAtmosphere (the default).
    properties (SetAccess = protected)
        DeltaT (1,1) double = 0
    end
    methods (Abstract)
        atm = at(obj, h)
    end
end
