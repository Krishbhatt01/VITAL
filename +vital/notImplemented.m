function notImplemented(what)
%NOTIMPLEMENTED  Raise the one error that marks a RED-for-the-right-reason test.
%   Every stub calls this. run_vital_tests treats a failure caused by
%   'vital:notImplemented' as RED-expected; any other error is RED-unexpected.
arguments
    what (1,:) char = 'feature'
end
error('vital:notImplemented', '%s is not implemented yet.', what);
end
