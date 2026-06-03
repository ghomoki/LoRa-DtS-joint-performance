function P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin, N_MC, sigma_X_dB)
%LINK_SUCCESS_PROB  Monte Carlo link success probability under Rician
%   fading and log-normal shadowing.
%
%   P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin, N_MC, sigma_X_dB)
%
%   For a deterministic mean SNR (linear) on a Rician fading channel with
%   K-factor K and additional log-normal shadowing of standard deviation
%   sigma_X_dB (dB), returns the probability that the instantaneous SNR
%   exceeds the threshold D_SNR_lin (linear), estimated from N_MC samples.
%
%   Channel model: |h|^2 is the squared magnitude of a complex Gaussian
%   with non-zero mean (Rician), normalized to E[|h|^2] = 1. Following
%   Asad Ullah et al. (2022)'s Probability_SNR.m, the LOS component is
%   placed at 45 degrees in the complex plane (real and imaginary means
%   both equal to mu = sqrt(K/(2(K+1)))). This is mathematically
%   equivalent to the standard form with the LOS on the real axis, since
%   Rician statistics depend only on |LOS|^2, not its phase.

arguments
    SNR_mean_lin
    K
    D_SNR_lin
    N_MC
    sigma_X_dB
end

% Rician channel parameters (Omega = E[|h|^2] = 1)
mu      = sqrt(K       / (2 * (K + 1)));
sigma_h = sqrt(1       / (2 * (K + 1)));

% Sample the Rician squared envelope
hr   = sigma_h * randn(1, N_MC) + mu;
hi   = sigma_h * randn(1, N_MC) + mu;
h_sq = hr.^2 + hi.^2;

% Sample log-normal shadowing factor (linear, multiplies received power)
% X_g > 0 corresponds to extra dB of path loss, hence the negative exponent
X_g_dB = sigma_X_dB * randn(1, N_MC);
shadow = 10.^(-X_g_dB / 10);

% Instantaneous SNR and success fraction
SNR_inst = SNR_mean_lin * h_sq .* shadow;
P_link   = mean(SNR_inst >= D_SNR_lin);
end
