classdef pdr_test < matlab.unittest.TestCase
%PDR_TEST  End-to-end regression test for the full PDR pipeline.
%
%   Locks in PDR values for two reference scenarios with a fixed RNG seed:
%     - "comfortable": low altitude (560 km), low SF (10), narrow B (31.25 kHz)
%       with LDRO on at 436.7 MHz. Link budget is generous (margin > 15 dB
%       throughout), so the result is essentially Doppler-only.
%     - "stressed":    high altitude (1500 km), SF=10, B=125 kHz, LDRO off
%       at 915 MHz. Link margin sweeps through 0 dB, so both Doppler and
%       link-budget mechanisms contribute substantively to packet loss.
%
%   Tolerance set tight (AbsTol = 1e-4) because the function is fully
%   deterministic given the RNG seed. If a benign refactor reorders RNG
%   calls and the expected values shift by more than this, re-baseline.

    methods (TestClassSetup)
        function addProjectRootToPath(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
        end
    end

    methods (Test)
        function comfortableLink(testCase)
            rng(0);
            [pdr, ~, ~, ~, ~] = packetdeliveryratio( ...
                10, 31.25, 436.7, true, 10, 55, 560);
            testCase.verifyEqual(pdr, 0.030906, "AbsTol", 1e-4);
        end

        function stressedLink(testCase)
            rng(0);
            [pdr, ~, ~, ~, ~] = packetdeliveryratio( ...
                1, 125, 915, false, 10, 55, 1500);
            testCase.verifyEqual(pdr, 0.284741, "AbsTol", 1e-4);
        end
    end
end
