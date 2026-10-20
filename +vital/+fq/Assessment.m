classdef Assessment
%ASSESSMENT  A vital.fq.assess result as an object (0.8.1-OOP, ADR-037).
%   A = vital.fq.Assessment(res)    res: the vital.fq.assess struct
%   (usually made by vital.Aircraft.assess)
%   A.Groups, A.Rules, A.Points      the engine's group, record and point structs
%   A.level(group)                   worstLevel of that group (NaN if unrated)
%   A.toStruct()                     res unchanged (vital.fq.writeReport takes it)
%   A.write(dir, name)               vital.fq.writeReport(res, dir, name)
%   Errors: vital:badInput (res lacks groups/rules/points), vital:fq:unknownGroup.
    properties (SetAccess = private)
        Groups struct
        Rules struct
        Points struct
        Label (1,:) char
    end
    properties (Access = private)
        Raw struct
    end
    methods
        function obj = Assessment(res)
            if ~isstruct(res) || ~isscalar(res) || ~all(isfield(res, {'groups', 'rules', 'points'}))
                error('vital:badInput', 'an Assessment needs a vital.fq.assess result.');
            end
            obj.Raw = res; obj.Groups = res.groups; obj.Rules = res.rules; obj.Points = res.points;
            if isfield(res, 'label'), obj.Label = res.label; end
        end
        function res = toStruct(obj)
            res = obj.Raw;
        end
        function L = level(obj, group)
            k = strcmp({obj.Groups.group}, group);
            if ~any(k)
                error('vital:fq:unknownGroup', 'no group ''%s'' in this assessment.', group);
            end
            L = obj.Groups(k).worstLevel;
        end
        function files = write(obj, dir, name)
            files = vital.fq.writeReport(obj.Raw, dir, name);
        end
    end
end
