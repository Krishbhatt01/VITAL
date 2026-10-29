function d = data(opts)
%DATA  The NESC cannonball as a vital.data.AircraftData (D1; see vital.aircraft.nesc.bodyData).
%   cannonball_data = vital.aircraft.nesc.cannonball.data()
%   cannonball_data = vital.aircraft.nesc.cannonball.data('DataRoot', folder)
arguments
    opts.DataRoot (1,:) char = ''
end
d = vital.aircraft.nesc.bodyData('cannonball', 'DataRoot', opts.DataRoot);
end
