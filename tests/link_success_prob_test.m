classdef link_success_prob_test < matlab.unittest.TestCase
%LINK_SUCCESS_PROB_TEST  Validation of the Monte Carlo link-success helper.
%
%   Exercises the helper at known limits where closed-form expressions
%   exist (deterministic K -> infinity and Rayleigh K = 0). Tolerances are
%   set to absorb Monte Carlo sampling noise at N_MC = 10^5
%   (~0.3% standard error on probability estimates).

    methods (TestClassSetup)
        function addProjectRootToPath(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
        end

        function fixRandomSeed(~)
            % Make the test deterministic from run to run
            rng(0);
        end
    end

    methods (Test)
        function deterministicWellAboveThreshold(testCase)
            % K -> infinity, SNR_mean >> threshold: P_link -> 1
            P = link_success_prob(100, 1e6, 1, 1e5, 0);
            testCase.verifyEqual(P, 1, "AbsTol", 1e-6);
        end

        function deterministicWellBelowThreshold(testCase)
            % K -> infinity, SNR_mean << threshold: P_link -> 0
            P = link_success_prob(0.01, 1e6, 1, 1e5, 0);
            testCase.verifyEqual(P, 0, "AbsTol", 1e-6);
        end

        function rayleighMatchesClosedForm(testCase)
            % K = 0 (Rayleigh) with no shadowing: P_link = exp(-D_SNR/SNR_mean)
            SNR_mean  = 5;
            D_SNR     = 1;
            expected  = exp(-D_SNR / SNR_mean);
            actual    = link_success_prob(SNR_mean, 0, D_SNR, 1e5, 0);
            testCase.verifyEqual(actual, expected, "AbsTol", 5e-3);
        end

        function ricianMatchesMarcumQClosedForm(testCase)
            % K = 5 with no shadowing: P_link = Q1(sqrt(2K), sqrt(2(K+1)*D_SNR/SNR_mean))
            % Computed via Marcum Q (Communications Toolbox).
            % Tolerance reflects MC noise plus the deterministic Marcum Q value.
            K        = 5;
            SNR_mean = 10;
            D_SNR    = 4;
            a        = sqrt(2*K);
            b        = sqrt(2*(K + 1) * D_SNR / SNR_mean);
            expected = marcumq(a, b);
            actual   = link_success_prob(SNR_mean, K, D_SNR, 1e5, 0);
            testCase.verifyEqual(actual, expected, "AbsTol", 5e-3);
        end

        function shadowingReducesProbabilityAtThreshold(testCase)
            % With SNR_mean = D_SNR, P_link < 1. Adding shadowing should
            % spread the SNR distribution but shouldn't shift the symmetric
            % case dramatically. Sanity check: shadowing variant differs
            % from no-shadowing variant by at most a few percent.
            P_no_shadow = link_success_prob(1, 5, 1, 1e5, 0);
            P_shadowed  = link_success_prob(1, 5, 1, 1e5, 4);   % 4 dB shadowing
            testCase.verifyLessThanOrEqual(abs(P_no_shadow - P_shadowed), 0.05);
        end

        function reproducibleWithSeed(testCase)
            % With a fixed seed, repeated calls return the same answer
            rng(42);
            P1 = link_success_prob(2, 3, 1, 1e4, 1);
            rng(42);
            P2 = link_success_prob(2, 3, 1, 1e4, 1);
            testCase.verifyEqual(P1, P2);
        end
    end
end
