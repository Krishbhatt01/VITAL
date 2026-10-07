function p = paths(key)
%PATHS  Absolute VITAL locations.
%   p = vital.paths('root')  folder that holds +vital, startup_vital.m
%   p = vital.paths('data')  reference data; the VITAL_DATA_ROOT environment
%                            variable overrides it (used by sabotage copies,
%                            which do not duplicate the 40+ MB data folder).
%   p = vital.paths('docs'|'tests'|'reports'|'rules'|'aircraft')
arguments
    key (1,:) char {mustBeMember(key, {'root','data','docs','tests','reports','rules','aircraft'})}
end
root = fileparts(fileparts(mfilename('fullpath')));
switch key
    case 'root'
        p = root;
    case 'data'
        env = getenv('VITAL_DATA_ROOT');
        if ~isempty(env), p = env; else, p = fullfile(root, 'data'); end
    otherwise
        p = fullfile(root, key);
end
end
