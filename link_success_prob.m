function P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin)
%LINK_SUCCESS_PROB  Analytic link success probability under Rician fading.
%
%   P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin)
%
%   For a deterministic mean SNR (linear) on a Rician fading channel with
%   K-factor K, returns the probability that the instantaneous SNR
%   exceeds the threshold D_SNR_lin (linear). Vectorized over all inputs.
%
%   Channel model: |h|^2 is the squared magnitude of a complex Gaussian
%   with non-zero mean (Rician), normalized to E[|h|^2] = 1, i.e.
%   h = h_r + 1i*h_i with h_r, h_i ~ N(mu, sigma_h^2),
%   mu = sqrt(K/(2(K+1))) and sigma_h^2 = 1/(2(K+1)). Then
%   |h|^2 / sigma_h^2 follows a noncentral chi-square distribution with
%   2 degrees of freedom and noncentrality lambda = 2K, so the success
%   probability has the closed form
%
%       P_link = P( SNR_mean * |h|^2 >= D_SNR )
%              = Q_1( sqrt(2K), sqrt(2(K+1) D_SNR / SNR_mean) )
%
%   where Q_1 is the first-order Marcum Q-function, evaluated here as the
%   noncentral chi-square upper tail. tests/link_success_prob_test.m
%   regression-checks this against Monte Carlo sampling of the envelope.
arguments
    SNR_mean_lin
    K
    D_SNR_lin
end

x      = 2 .* (K + 1) .* D_SNR_lin ./ SNR_mean_lin;
P_link = ncx2cdf(x, 2, 2 .* K, 'upper');
end
