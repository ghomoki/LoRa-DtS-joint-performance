function P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin)
%LINK_SUCCESS_PROB  Analytic link success probability under Rician fading.
%
%   For a deterministic mean SNR in linear units on a Rician fading channel with
%   Rician K-factor K, this function returns the probability of packet reception,
%   the probability of the instantaneous SNR exceeding the threshold D_SNR_lin.
%   
%   Channel model: |h|^2 is the squared magnitude of a complex Gaussian
%   with non-zero mean (the Rician distribution), normalized to E[|h|^2] = 1,
%   i.e. h = h_r + i*h_i with h_r, h_i ~ N(mu, sigma_h^2),
%   mu = sqrt(K/(2(K+1))) and sigma_h^2 = 1/(2(K+1)). Then
%   |h|^2 / sigma_h^2 follows a noncentral chi-square distribution with
%   2 degrees of freedom and noncentrality lambda = 2K, so the success
%   probability has the closed form
%
%       P_link = P( SNR_mean * |h|^2 >= D_SNR )
%              = Q_1( sqrt(2K), sqrt(2(K+1) D_SNR / SNR_mean) )
%
%   where Q_1 is the first-order Marcum Q-function, evaluated here as the
%   noncentral chi-square complementary cdf.
%
%   Note for the channel model: large K and therefore weak fading benefits P_link at a positive
%   link margin. Small uncertainty guarantees reception. But at a negative link margin, it is
%   actually small K that benefits reception. Upfading allows for some packets to still reach
%   the receiver where a direct LOS link would certainly not close the link budget.
%   Combined with K increasing with elevation, this means that high elevation can lower link
%   success in some cases, leading to a P_link pattern with a peak before and after zenith.
%
%   tests/link_success_prob_test.m regression-checks this against Monte Carlo sampling
%   of the envelope. The former is simpler, but this analytic implementation is much faster.
arguments
    SNR_mean_lin
    K
    D_SNR_lin
end

x      = 2 .* (K + 1) .* D_SNR_lin ./ SNR_mean_lin;
P_link = ncx2cdf(x, 2, 2 .* K, 'upper');
end
