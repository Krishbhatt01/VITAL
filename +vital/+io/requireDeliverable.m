function requireDeliverable(file)
%REQUIREDELIVERABLE  A missing specification file counts as "not implemented".
%   Tests of documents and data files call this first, so that before the
%   deliverable exists the test is RED for the right reason
%   (vital:notImplemented) rather than failing on a file-open error.
if ~isfile(file)
    vital.notImplemented(sprintf('deliverable %s', file));
end
end
