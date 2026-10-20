classdef (Abstract) ControlLaw
%CONTROLLAW  Base class of the M7 control laws as objects (0.8.1-OOP, ADR-037).
%   A law holds its gains; build() makes the vital.sim.run controller struct by
%   calling the existing functional law (the laws are NOT re-implemented):
%     c = law.build(AC, env, tr)    AC runtime struct, env, OK vital.trim.solve
%                                   struct (or vital.TrimResult)
%     b = law.builder()             @(AC, env, tr) law.build(AC, env, tr), the
%                                   form vital.fq.f16Factory('Controller', b) takes
%   Subclasses: PitchSasLaw (vital.ctrl.pitchSas), YawDamperLaw (yawDamper),
%   NescLqrLaw (nescLqr), CombinedLaw (combine).
%   Errors: those of the functional laws, at build time.
    properties (SetAccess = protected)
        Name (1,:) char
    end
    methods (Abstract)
        c = buildStruct(obj, AC, env, tr)
    end
    methods
        function c = build(obj, AC, env, tr)
            if isa(AC, 'vital.Aircraft'), AC = AC.toRuntime(); end
            if isa(tr, 'vital.TrimResult'), tr = tr.toStruct(); end
            c = obj.buildStruct(AC, env, tr);
        end
        function b = builder(obj)
            b = @(AC, env, tr) obj.build(AC, env, tr);
        end
    end
end
