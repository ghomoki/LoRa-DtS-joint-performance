"""Analytic Rician link success probability, port of link_success_prob.m."""

import numpy as np
from scipy.stats import ncx2


def link_success_prob(snr_mean_lin, k, d_snr_lin):
    """Analytic link success probability under Rician fading.

    For a deterministic mean SNR (linear) on a Rician fading channel with
    K-factor k, returns the probability that the instantaneous SNR exceeds
    the threshold d_snr_lin (linear). Vectorized over all inputs.

    Channel model: |h|^2 is the squared magnitude of a complex Gaussian
    with non-zero mean (Rician), normalized to E[|h|^2] = 1, i.e.
    h = h_r + 1j*h_i with h_r, h_i ~ N(mu, sigma_h^2),
    mu = sqrt(K/(2(K+1))) and sigma_h^2 = 1/(2(K+1)). Then
    |h|^2 / sigma_h^2 follows a noncentral chi-square distribution with
    2 degrees of freedom and noncentrality lambda = 2K, so the success
    probability has the closed form

        P_link = P( SNR_mean * |h|^2 >= D_SNR )
               = Q_1( sqrt(2K), sqrt(2(K+1) D_SNR / SNR_mean) )

    where Q_1 is the first-order Marcum Q-function, evaluated here as the
    noncentral chi-square survival function.
    """
    k = np.asarray(k, dtype=float)
    x = 2.0 * (k + 1.0) * np.asarray(d_snr_lin, dtype=float) / snr_mean_lin
    p = ncx2.sf(x, df=2, nc=2.0 * k)
    return p.item() if np.ndim(p) == 0 else p
