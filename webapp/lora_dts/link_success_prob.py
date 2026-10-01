"""Analytic Rician link success probability, SciPy-free web app build.

Overrides python/lora_dts/link_success_prob.py in the deployed site, so the
browser does not have to download SciPy. Must match it to floating-point
precision; see webapp/tests/test_scipy_free.py.
"""

import math

import numpy as np

# Poisson terms kept beyond the mean K: the dropped tail mass is far below
# 1e-16 for any K, which bounds the truncation error of P_link.
_TAIL_SIGMAS = 12
_TAIL_EXTRA = 40


def link_success_prob(snr_mean_lin, k, d_snr_lin):
    """Analytic link success probability under Rician fading.

    Same closed form as the reference port,

        P_link = Q_1( sqrt(2K), sqrt(2(K+1) D_SNR / SNR_mean) ),

    i.e. the survival function at x of a noncentral chi-square with 2
    degrees of freedom and noncentrality 2K. Evaluated as its Poisson
    mixture of central chi-squares with even degrees of freedom, whose
    survival functions are finite sums (y = x/2):

        P_link = sum_j e^-K K^j / j!  *  sum_{i<=j} e^-y y^i / i!

    All terms are positive, so there is no cancellation. Vectorized over
    all inputs.
    """
    k, snr, d_snr = np.broadcast_arrays(
        np.asarray(k, dtype=float), np.asarray(snr_mean_lin, dtype=float),
        np.asarray(d_snr_lin, dtype=float))
    shape = k.shape
    y = ((k + 1.0) * d_snr / snr).ravel()
    k = k.ravel()

    k_max = float(k.max()) if k.size else 0.0
    n = int(k_max + _TAIL_SIGMAS * math.sqrt(k_max) + _TAIL_EXTRA)
    j = np.arange(n)
    log_fact = np.array([math.lgamma(i + 1.0) for i in range(n)])

    def log_poisson(mean):
        """log(e^-mean mean^j / j!) for every j, one row per mean."""
        with np.errstate(divide="ignore", invalid="ignore"):
            log_mean = np.log(mean)[:, None]
            # j * log(mean) taken as 0 at j = 0, also when mean = 0
            j_log = np.where(j == 0, 0.0, j * log_mean)
        return j_log - mean[:, None] - log_fact

    weights = np.exp(log_poisson(k))
    # They sum to 1 up to the negligible tail; renormalizing removes the
    # rounding of exp() at large K
    weights /= weights.sum(axis=1, keepdims=True)
    # Central chi-square survival functions for 2, 4, ..., 2n dof
    sf_central = np.cumsum(np.exp(log_poisson(y)), axis=1)
    p = np.sum(weights * sf_central, axis=1).reshape(shape)
    return p.item() if p.ndim == 0 else p
