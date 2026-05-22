classdef tau_test < matlab.unittest.TestCase
%TAU_TEST  Regression test for pass_duration.
%
%   The H=560 km case is anchored to the paper's own TLE-based access
%   window: Bandwidth_LoRa_Dopper_effect.m defines a Norby pass from
%   20:54:02 to 21:05:50, i.e. 708 s. Our geometric formula gives 708.9 s
%   for E_min=1 deg, matching to within ~1 s.
%
%   The other H values are locked-in regression values from the same
%   formula. They guard against accidental reintroduction of the paper's
%   eq. (4) bug (missing (R+H)/R factor), which would shift these values
%   downward by ~8%, ~11%, ~14%, ~19% respectively.

    properties (TestParameter)
        scenario = struct( ...
            'H560_E1',  struct(H=560,  E_min=1, expected=708.9), ...
            'H750_E1',  struct(H=750,  E_min=1, expected=849.5), ...
            'H1000_E1', struct(H=1000, E_min=1, expected=1022.3), ...
            'H1500_E1', struct(H=1500, E_min=1, expected=1351.2))
    end

    methods (Test)
        function matchesGeometricFormula(testCase, scenario)
            actual = pass_duration(scenario.H, scenario.E_min);
            testCase.verifyEqual(actual, scenario.expected, "AbsTol", 0.5);
        end
    end
end
