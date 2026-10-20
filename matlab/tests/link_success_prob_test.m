classdef link_success_prob_test < matlab.unittest.TestCase
%LINK_SUCCESS_PROB_TEST  Validation of the analytic link-success helper.
%
%   Checks the noncentral chi-square closed form at limits where
%   independent expressions exist (deterministic K -> infinity, Rayleigh
%   K = 0, Marcum Q identity), and regression-tests it against Monte
%   Carlo sampling of the Rician envelope across the K range used by the
%   elevation-dependent model (3.07 .. 17.06).

    methods (TestClassSetup)
        function addProjectRootToPath(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
        end
    end

    methods (Test)
        function deterministicWellAboveThreshold(testCase)
            % K -> infinity, SNR_mean >> threshold: P_link -> 1
            P = link_success_prob(100, 1e6, 1);
            testCase.verifyEqual(P, 1, "AbsTol", 1e-12);
        end

        function deterministicWellBelowThreshold(testCase)
            % K -> infinity, SNR_mean << threshold: P_link -> 0
            P = link_success_prob(0.01, 1e6, 1);
            testCase.verifyEqual(P, 0, "AbsTol", 1e-12);
        end

        function rayleighMatchesClosedForm(testCase)
            % K = 0 (Rayleigh): P_link = exp(-D_SNR/SNR_mean)
            SNR_mean = 5;
            D_SNR    = 1;
            actual   = link_success_prob(SNR_mean, 0, D_SNR);
            testCase.verifyEqual(actual, exp(-D_SNR/SNR_mean), "AbsTol", 1e-12);
        end

        function matchesMarcumQClosedForm(testCase)
            % Identity: noncentral chi-square upper tail with 2 degrees of
            % freedom equals the first-order Marcum Q-function,
            % Q1(sqrt(2K), sqrt(2(K+1)*D_SNR/SNR_mean)).
            K        = 5;
            SNR_mean = 10;
            D_SNR    = 4;
            expected = marcumq(sqrt(2*K), sqrt(2*(K + 1)*D_SNR/SNR_mean));
            actual   = link_success_prob(SNR_mean, K, D_SNR);
            testCase.verifyEqual(actual, expected, "AbsTol", 1e-12);
        end

        function regressionAgainstMonteCarlo(testCase)
            % The analytic form must reproduce Monte Carlo sampling of the
            % Rician squared envelope (the scheme it replaced) to within
            % sampling noise: std err <= 0.5/sqrt(N_MC) = 5e-4 per point,
            % AbsTol = 5e-3 gives 10 sigma headroom.
            rng(0);
            N_MC = 1e6;
            for K = [0, 0.5, 3.07, 5.63, 17.06]
                for r = [0.5, 1, 2, 10]   % SNR_mean / D_SNR ratio
                    mu      = sqrt(K / (2*(K + 1)));
                    sigma_h = sqrt(1 / (2*(K + 1)));
                    h_sq    = (sigma_h*randn(1, N_MC) + mu).^2 ...
                            + (sigma_h*randn(1, N_MC) + mu).^2;
                    P_mc    = mean(r * h_sq >= 1);
                    testCase.verifyEqual(link_success_prob(r, K, 1), P_mc, ...
                        "AbsTol", 5e-3, ...
                        sprintf("Mismatch vs Monte Carlo at K=%.2f, SNR/D=%.1f", K, r));
                end
            end
        end

        function vectorizedOverInputs(testCase)
            S = [1, 2, 5];
            K = [0, 3.07, 17.06];
            P = link_success_prob(S, K, 1);
            expected = arrayfun(@(s, k) link_success_prob(s, k, 1), S, K);
            testCase.verifyEqual(P, expected);
        end
    end
end
