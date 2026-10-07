function h = sha256File(file)
%SHA256FILE  Lower-case hex SHA-256 of a file's bytes (for the data manifest).
fid = fopen(file, 'r');
if fid < 0
    error('vital:io:cannotOpen', 'cannot open %s', file);
end
c = onCleanup(@() fclose(fid));
md = java.security.MessageDigest.getInstance('SHA-256');
while true
    chunk = fread(fid, 8*1024*1024, '*uint8');
    if isempty(chunk), break; end
    md.update(typecast(chunk, 'int8'));
end
h = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2)', 1, []));
end
