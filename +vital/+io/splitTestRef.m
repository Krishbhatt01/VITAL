function [file, method] = splitTestRef(ref)
%SPLITTESTREF  'tests/M1/tFoo.m#barBaz' -> file 'tests/M1/tFoo.m', method 'barBaz'.
ref = erase(string(ref), "`");
parts = split(ref, "#");
if numel(parts) ~= 2 || ~endsWith(parts(1), ".m") || strlength(parts(2)) == 0
    error('vital:io:badTestRef', 'test reference must be "path/File.m#method", got "%s"', ref);
end
file = char(parts(1));
method = char(parts(2));
end
