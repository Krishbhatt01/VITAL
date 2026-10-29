function d = data(opts)
%DATA  The NESC brick as a vital.data.AircraftData (D1; see vital.aircraft.nesc.bodyData).
%   brick_data = vital.aircraft.nesc.brick.data()
%   brick_data = vital.aircraft.nesc.brick.data('DataRoot', folder)
arguments
    opts.DataRoot (1,:) char = ''
end
d = vital.aircraft.nesc.bodyData('brick', 'DataRoot', opts.DataRoot);
end
