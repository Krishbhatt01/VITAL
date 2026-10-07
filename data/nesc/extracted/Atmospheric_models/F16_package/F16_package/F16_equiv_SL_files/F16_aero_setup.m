%% M file script to provide data for F16_aero.mdl model
clear F16_aero_data; % remove any existing data structure
%% Block "const_1" has no data to save.
%% Block "divide_1" has no data to save.
%% Block "divide_23" has no data to save.
%% Block "power_22" has no data to save.
%% Block "minus_21" has no data to save.
%% Block "plus_19" has no data to save.
%% Block "times_18" has no data to save.
%% Block "plus_17" has no data to save.
%% Block "plus_54" has no data to save.
%% Block "aeroBodyForceCoefficient_Z" has no data to save.
%% Block "const_2" has no data to save.
%% Block "const_4" has no data to save.
%% Block "divide_4" has no data to save.
%% Block "times_25" has no data to save.
%% Block "const_6" has no data to save.
%% Block "divide_6" has no data to save.
%% Block "times_13" has no data to save.
%% Block "plus_10" has no data to save.
%% Block "plus_49" has no data to save.
%% Block "aeroBodyForceCoefficient_Y" has no data to save.
%% Block "times_42" has no data to save.
%% Block "plus_41" has no data to save.
%% Block "plus_56" has no data to save.
%% Block "aeroBodyMomentCoefficient_Roll" has no data to save.
%% Block "times_45" has no data to save.
%% Block "plus_44" has no data to save.
%% Block "plus_63" has no data to save.
%% Block "aeroBodyMomentCoefficient_Yaw" has no data to save.
%% Block "const_8" has no data to save.
%% Block "divide_8" has no data to save.
%% Block "times_15" has no data to save.
%% Block "times_43" has no data to save.
%% Block "times_46" has no data to save.
%% Block "const_11" has no data to save.
%% Block "times_11" has no data to save.
%% Block "const_13" has no data to save.
%% Block "const_15" has no data to save.
%% Block "const_19" has no data to save.
%% Block "const_23" has no data to save.
%% Block "const_25" has no data to save.
%% Block "const_27" has no data to save.
%% Block "times_27" has no data to save.
%% Block "divide_29" has no data to save.
%% Block "times_50" has no data to save.
%% Block "times_57" has no data to save.
%% Block "times_64" has no data to save.
%% Block "divide_31" has no data to save.
%% Block "times_30" has no data to save.
%% Block "times_48" has no data to save.
%% Block "plus_47" has no data to save.
%% Block "aeroBodyForceCoefficient_X" has no data to save.
%% Block "times_55" has no data to save.
%% Block "times_62" has no data to save.
%% Block "plus_61" has no data to save.
%% Block "aeroBodyMomentCoefficient_Pitch" has no data to save.
%% Block "const_35" has no data to save.
%% Block "lt_35" has no data to save.
%% Block "switch_33" has no data to save.
%% Block "const_39" has no data to save.
%% Block "lt_39" has no data to save.
%% Block "switch_37" has no data to save.
%% Block "trueAirspeed" has no data to save.
%% Block "trueAirspeed_unlim_limiter" has no data to save.
%% Block "angleOfAttack" has no data to save.
%% Block "ALPHA1" wishes to save the following breakpoint vector:
F16_aero_data.ALPHA1_pts = [[-10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0]];
%% Block "CX_fn" wishes to save the following data:
F16_aero_data.CX_table_def = [
-0.099, -0.081, -0.081, -0.063, -0.025, 0.044, 0.097, 0.113, 0.145, 0.167, 0.174, 0.166,
-0.048, -0.038, -0.04, -0.021, 0.016, 0.083, 0.127, 0.137, 0.162, 0.177, 0.179, 0.167,
-0.022, -0.02, -0.021, -0.0040, 0.032, 0.094, 0.128, 0.13, 0.154, 0.161, 0.155, 0.138,
-0.04, -0.038, -0.039, -0.025, 0.0060, 0.062, 0.087, 0.085, 0.1, 0.11, 0.104, 0.091,
-0.083, -0.073, -0.076, -0.072, -0.046, 0.012, 0.024, 0.025, 0.043, 0.053, 0.047, 0.04]';
%% Block "CZ0_fn" wishes to save the following data:
F16_aero_data.CZ0_table_def = [
0.77, 0.241, -0.1, -0.416, -0.731, -1.053, -1.366, -1.646, -1.917, -2.12, -2.248, -2.229];
%% Block "Cm0_fn" wishes to save the following data:
F16_aero_data.Cm0_table_def = [
0.205, 0.168, 0.186, 0.196, 0.213, 0.251, 0.245, 0.238, 0.252, 0.231, 0.198, 0.192,
0.081, 0.077, 0.107, 0.11, 0.11, 0.141, 0.127, 0.119, 0.133, 0.108, 0.081, 0.093,
-0.046, -0.02, -0.0090, -0.0050, -0.0060, 0.01, 0.0060, -0.0010, 0.014, 0.0, -0.013, 0.032,
-0.174, -0.145, -0.121, -0.127, -0.129, -0.102, -0.097, -0.113, -0.087, -0.084, -0.069, -0.0060,
-0.259, -0.202, -0.184, -0.193, -0.199, -0.15, -0.16, -0.167, -0.104, -0.076, -0.041, -0.0050]';
%% Block "Cl0_fn" wishes to save the following data:
F16_aero_data.Cl0_table_def = [
0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
-0.0010, -0.0040, -0.0080, -0.012, -0.016, -0.022, -0.022, -0.021, -0.015, -0.0080, -0.013, -0.015,
-0.0030, -0.0090, -0.017, -0.024, -0.03, -0.041, -0.045, -0.04, -0.016, -0.0020, -0.01, -0.019,
-0.0010, -0.01, -0.02, -0.03, -0.039, -0.054, -0.057, -0.054, -0.023, -0.0060, -0.014, -0.027,
0.0, -0.01, -0.022, -0.034, -0.047, -0.06, -0.069, -0.067, -0.033, -0.036, -0.035, -0.035,
0.0070, -0.01, -0.023, -0.034, -0.049, -0.063, -0.081, -0.079, -0.06, -0.058, -0.062, -0.059,
0.0090, -0.011, -0.023, -0.037, -0.05, -0.068, -0.089, -0.088, -0.091, -0.076, -0.077, -0.076]';
%% Block "minus_34" has no data to save.
%% Block "Cn0_fn" wishes to save the following data:
F16_aero_data.Cn0_table_def = [
0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
0.018, 0.019, 0.018, 0.019, 0.019, 0.018, 0.013, 0.0070, 0.0040, -0.014, -0.017, -0.033,
0.038, 0.042, 0.042, 0.042, 0.043, 0.039, 0.03, 0.017, 0.0040, -0.035, -0.047, -0.057,
0.056, 0.057, 0.059, 0.058, 0.058, 0.053, 0.032, 0.012, 0.0020, -0.046, -0.071, -0.073,
0.064, 0.077, 0.076, 0.074, 0.073, 0.057, 0.029, 0.0070, 0.012, -0.034, -0.065, -0.041,
0.074, 0.086, 0.093, 0.089, 0.08, 0.062, 0.049, 0.022, 0.028, -0.012, -0.0020, -0.013,
0.079, 0.09, 0.106, 0.106, 0.096, 0.08, 0.068, 0.03, 0.064, 0.015, 0.011, -0.0010]';
%% Block "minus_38" has no data to save.
%% Block "CXq_fn" wishes to save the following data:
F16_aero_data.CXq_table_def = [
-0.267, -0.11, 0.308, 1.34, 2.08, 2.91, 2.76, 2.05, 1.5, 1.49, 1.83, 1.21];
%% Block "CYr_fn" wishes to save the following data:
F16_aero_data.CYr_table_def = [
0.882, 0.852, 0.876, 0.958, 0.962, 0.974, 0.819, 0.483, 0.59, 1.21, -0.493, -1.04];
%% Block "times_53" has no data to save.
%% Block "plus_51" has no data to save.
%% Block "CYp_fn" wishes to save the following data:
F16_aero_data.CYp_table_def = [
-0.108, -0.108, -0.188, 0.11, 0.258, 0.226, 0.344, 0.362, 0.611, 0.529, 0.298, -0.227];
%% Block "times_52" has no data to save.
%% Block "CZq_fn" wishes to save the following data:
F16_aero_data.CZq_table_def = [
-8.8, -25.8, -28.9, -31.4, -31.2, -30.7, -27.7, -28.2, -29.0, -29.8, -38.3, -35.3];
%% Block "Clr_fn" wishes to save the following data:
F16_aero_data.Clr_table_def = [
-0.126, -0.026, 0.063, 0.113, 0.208, 0.23, 0.319, 0.437, 0.68, 0.1, 0.447, -0.33];
%% Block "times_60" has no data to save.
%% Block "plus_58" has no data to save.
%% Block "Clp_fn" wishes to save the following data:
F16_aero_data.Clp_table_def = [
-0.36, -0.359, -0.443, -0.42, -0.383, -0.375, -0.329, -0.294, -0.23, -0.21, -0.12, -0.1];
%% Block "times_59" has no data to save.
%% Block "Cmq_fn" wishes to save the following data:
F16_aero_data.Cmq_table_def = [
-7.21, -5.4, -5.23, -5.26, -6.11, -6.64, -5.69, -6.0, -6.2, -6.4, -6.6, -6.0];
%% Block "Cnr_fn" wishes to save the following data:
F16_aero_data.Cnr_table_def = [
-0.38, -0.363, -0.378, -0.386, -0.37, -0.453, -0.55, -0.582, -0.595, -0.637, -1.02, -0.84];
%% Block "times_67" has no data to save.
%% Block "plus_65" has no data to save.
%% Block "Cnp_fn" wishes to save the following data:
F16_aero_data.Cnp_table_def = [
0.061, 0.052, 0.052, -0.012, -0.013, -0.024, 0.05, 0.15, 0.13, 0.158, 0.24, 0.15];
%% Block "times_66" has no data to save.
%% Block "dlda_fn" wishes to save the following data:
F16_aero_data.dlda_table_def = [
-0.041, -0.052, -0.053, -0.056, -0.05, -0.056, -0.082, -0.059, -0.042, -0.038, -0.027, -0.017,
-0.041, -0.053, -0.053, -0.053, -0.05, -0.051, -0.066, -0.043, -0.038, -0.027, -0.023, -0.016,
-0.042, -0.053, -0.052, -0.051, -0.049, -0.049, -0.043, -0.035, -0.026, -0.016, -0.018, -0.014,
-0.04, -0.052, -0.051, -0.052, -0.048, -0.048, -0.042, -0.037, -0.031, -0.026, -0.017, -0.012,
-0.043, -0.049, -0.048, -0.049, -0.043, -0.042, -0.042, -0.036, -0.025, -0.021, -0.016, -0.011,
-0.044, -0.048, -0.048, -0.047, -0.042, -0.041, -0.02, -0.028, -0.013, -0.014, -0.011, -0.01,
-0.043, -0.049, -0.047, -0.045, -0.042, -0.037, -0.0030, -0.013, -0.01, -0.0030, -0.0070, -0.0080]';
%% Block "dldr_fn" wishes to save the following data:
F16_aero_data.dldr_table_def = [
0.0050, 0.017, 0.014, 0.01, -0.0050, 0.0090, 0.019, 0.0050, 0.0, -0.0050, -0.011, 0.0080,
0.0070, 0.016, 0.014, 0.014, 0.013, 0.0090, 0.012, 0.0050, 0.0, 0.0040, 0.0090, 0.0070,
0.013, 0.013, 0.011, 0.012, 0.011, 0.0090, 0.0080, 0.0050, 0.0, 0.0050, 0.0030, 0.0050,
0.018, 0.015, 0.015, 0.014, 0.014, 0.014, 0.014, 0.015, 0.013, 0.011, 0.0060, 0.0010,
0.015, 0.014, 0.013, 0.013, 0.012, 0.011, 0.011, 0.01, 0.0080, 0.0080, 0.0070, 0.0030,
0.021, 0.011, 0.01, 0.011, 0.01, 0.0090, 0.0080, 0.01, 0.0060, 0.0050, 0.0, 0.0010,
0.023, 0.01, 0.011, 0.011, 0.011, 0.01, 0.0080, 0.01, 0.0060, 0.014, 0.02, 0.0]';
%% Block "dnda_fn" wishes to save the following data:
F16_aero_data.dnda_table_def = [
0.0010, -0.027, -0.017, -0.013, -0.012, -0.016, 0.0010, 0.017, 0.011, 0.017, 0.0080, 0.016,
0.0020, -0.014, -0.016, -0.016, -0.014, -0.019, -0.021, 0.0020, 0.012, 0.016, 0.015, 0.011,
-0.0060, -0.0080, -0.0060, -0.0060, -0.0050, -0.0080, -0.0050, 0.0070, 0.0040, 0.0070, 0.0060, 0.0060,
-0.011, -0.011, -0.01, -0.0090, -0.0080, -0.0060, 0.0, 0.0040, 0.0070, 0.01, 0.0040, 0.01,
-0.015, -0.015, -0.014, -0.012, -0.011, -0.0080, -0.0020, 0.0020, 0.0060, 0.012, 0.011, 0.011,
-0.024, -0.01, -0.0040, -0.0020, -0.0010, 0.0030, 0.014, 0.0060, -0.0010, 0.0040, 0.0040, 0.0060,
-0.022, 0.0020, -0.0030, -0.0050, -0.0030, -0.0010, -0.0090, -0.0090, -0.0010, 0.0030, -0.0020, 0.0010]';
%% Block "dndr_fn" wishes to save the following data:
F16_aero_data.dndr_table_def = [
-0.018, -0.052, -0.052, -0.052, -0.054, -0.049, -0.059, -0.051, -0.03, -0.037, -0.026, -0.013,
-0.028, -0.051, -0.043, -0.046, -0.045, -0.049, -0.057, -0.052, -0.03, -0.033, -0.03, -0.0080,
-0.037, -0.041, -0.038, -0.04, -0.04, -0.038, -0.037, -0.03, -0.027, -0.024, -0.019, -0.013,
-0.048, -0.045, -0.045, -0.045, -0.044, -0.045, -0.047, -0.048, -0.049, -0.045, -0.033, -0.016,
-0.043, -0.044, -0.041, -0.041, -0.04, -0.038, -0.034, -0.035, -0.035, -0.029, -0.022, -0.0090,
-0.052, -0.034, -0.036, -0.036, -0.035, -0.028, -0.024, -0.023, -0.02, -0.016, -0.01, -0.014,
-0.062, -0.034, -0.027, -0.028, -0.027, -0.027, -0.023, -0.023, -0.019, -0.0090, -0.025, -0.01]';
%% Block "angleOfSideslip" has no data to save.
%% Block "BETA2" wishes to save the following breakpoint vector:
F16_aero_data.BETA2_pts = [[-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]];
%% Block "abs_32" has no data to save.
%% Block "BETA1" wishes to save the following breakpoint vector:
F16_aero_data.BETA1_pts = [[0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0]];
%% Block "bodyAngularRate_Roll" has no data to save.
%% Block "bodyAngularRate_Pitch" has no data to save.
%% Block "bodyAngularRate_Yaw" has no data to save.
%% Block "elevatorDeflection" has no data to save.
%% Block "DE1" wishes to save the following breakpoint vector:
F16_aero_data.DE1_pts = [[-24.0, -12.0, 0.0, 12.0, 24.0]];
%% Block "aileronDeflection" has no data to save.
%% Block "rudderDeflection" has no data to save.
%% Block "const_99" has no data to save.
%% Block "referenceWingChord" has no data to save.
%% Block "const_101" has no data to save.
%% Block "referenceWingSpan" has no data to save.
%% Block "const_103" has no data to save.
%% Block "referenceWingArea" has no data to save.
