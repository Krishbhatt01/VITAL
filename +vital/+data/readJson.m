function s = readJson(file)
%READJSON  Read a file written by vital.data.writeJson (or authored by hand).
%   s = vital.data.readJson(file)   the jsondecode struct; numbers are decoded
%   where they are used (vital.data.internal.num). Errors: vital:data:fileNotFound,
%   vital:data:badFormat (not JSON).
arguments
    file (1,:) char
end
if ~isfile(file)
    error('vital:data:fileNotFound', 'file not found: %s', file);
end
try
    s = jsondecode(fileread(file, 'Encoding', 'UTF-8'));
catch err
    error('vital:data:badFormat', '%s is not valid JSON: %s', file, err.message);
end
end
