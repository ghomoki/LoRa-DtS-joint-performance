classdef pdr_test < matlab.unittest.TestCase
%PDR_TEST  End-to-end regression test for the full PDR pipeline.
%
%   Locks in PDR values for two reference scenarios:
%     - "comfortable": low altitude (560 km), low SF (10), narrow B (31.25 kHz)
%       with LDRO on at 436.7 MHz. Link budget is generous, so the result
%       is essentially Doppler-only.
%     - "stressed":    high altitude (1500 km), SF=10, B=125 kHz, LDRO off
%       at 915 MHz. Link margin sweeps through 0 dB, so both Doppler and
%       link-budget mechanisms contribute substantively to packet loss.
%
%   The pipeline is fully deterministic (the link success probability is
%   analytic, no Monte Carlo), so the tolerance only absorbs cross-platform
%   floating-point noise. If a deliberate model change shifts the values,
%   re-baseline.

    methods (TestClassSetup)
        function addProjectRootToPath(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
        end
    end

    methods (Test)
        function comfortableLink(testCase)
            [pdr, ~, ~, ~, ~] = packetdeliveryratio( ...
                10, 31.25, 436.7, true, 10, 55, 560);
            testCase.verifyEqual(pdr, 0.030871060259, "AbsTol", 1e-9);
        end

        function stressedLink(testCase)
            [pdr, ~, ~, ~, ~] = packetdeliveryratio( ...
                1, 125, 915, false, 10, 55, 1500);
            testCase.verifyEqual(pdr, 0.057956850261, "AbsTol", 1e-9);
        end
    end
end
