function C = dcmEcefToNed(lat, lon)
%DCMECEFTONED  C_ne: ECEF components -> local North-East-Down components.
%   Geodetic latitude defines the local vertical (TM Vol II p.601).
%   Matches the Aerospace Toolbox dcmecef2ned(lat_deg, lon_deg).
vital.validate.finite([lat lon], 'lat/lon');
sp = sin(lat); cp = cos(lat); sl = sin(lon); cl = cos(lon);
C = [-sp*cl, -sp*sl,  cp;
     -sl,     cl,     0;
     -cp*cl, -cp*sl, -sp];
end
