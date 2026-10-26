function f = modelFile()
%MODELFILE  Full path of the committed, generated model models/VitalPlant.slx
%   (docs/PLAN_M9.md section 4). Regenerate with vital.slx.build().
f = fullfile(vital.paths('root'), 'models', 'VitalPlant.slx');
end
