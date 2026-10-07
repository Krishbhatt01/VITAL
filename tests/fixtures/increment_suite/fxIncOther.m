classdef (TestTags = {'FIXTURE','M5'}) fxIncOther < matlab.unittest.TestCase
%FXINCOTHER  Another current-milestone increment in progress elsewhere: must be
%   skipped by an increment run that does not list it.
    methods (Test)
        function unexpected(~), error('fixture:otherWork', 'work in progress by someone else'); end
    end
end
