classdef rician_K_test < matlab.unittest.TestCase
%RICIAN_K_TEST  Regression test for the elevation-dependent K(E) spline.
%
%   Covers:
%     - Exact match at each of Kim's Table II data points
%     - Flat floor behavior below 20 deg
%     - Spline interpolation between data points
%     - Spline extrapolation above 80 deg
%
%   The values for interior and extrapolated points are locked-in from the
%   current cubic-spline implementation; they guard against accidental
%   changes to the interpolation method or data points.

    methods (TestClassSetup)
        function addProjectRootToPath(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
        end
    end

    properties (TestParameter)
        scenario = struct( ...
            'data_E20',          struct(E=20,  expected=3.07,    tol=1e-6), ...
            'data_E30',          struct(E=30,  expected=3.24,    tol=1e-6), ...
            'data_E40',          struct(E=40,  expected=3.60,    tol=1e-6), ...
            'data_E60',          struct(E=60,  expected=5.63,    tol=1e-6), ...
            'data_E80',          struct(E=80,  expected=17.06,   tol=1e-6), ...
            'floor_E1',          struct(E=1,   expected=3.07,    tol=1e-6), ...
            'floor_E10',         struct(E=10,  expected=3.07,    tol=1e-6), ...
            'floor_E19_99',      struct(E=19.99, expected=3.07,  tol=1e-6), ...
            'interp_E50',        struct(E=50,  expected=4.068,   tol=0.01), ...
            'interp_E70',        struct(E=70,  expected=9.542,   tol=0.01), ...
            'extrap_E85',        struct(E=85,  expected=22.563,  tol=0.05), ...
            'extrap_E90',        struct(E=90,  expected=29.438,  tol=0.05))
    end

    methods (Test)
        function matchesSplineModel(testCase, scenario)
            actual = rician_K(scenario.E);
            testCase.verifyEqual(actual, scenario.expected, "AbsTol", scenario.tol);
        end

        function vectorized(testCase)
            % rician_K should accept and return arrays
            E = [10, 20, 50, 80, 90];
            K = rician_K(E);
            testCase.verifySize(K, size(E));
            testCase.verifyEqual(K(1), 3.07, "AbsTol", 1e-6);  % floor
            testCase.verifyEqual(K(2), 3.07, "AbsTol", 1e-6);  % data point
            testCase.verifyEqual(K(4), 17.06, "AbsTol", 1e-6); % data point
        end
    end
end
