"""Validation of the analytic link-success helper.

Checks the noncentral chi-square closed form at limits where independent
expressions exist (deterministic K -> infinity, Rayleigh K = 0), and
regression-tests it against Monte Carlo sampling of the Rician envelope
(the scheme the analytic form replaced) across the K range used by the
elevation-dependent model (3.07 .. 17.06).
"""

import math

import numpy as np
import pytest

from lora_dts import link_success_prob


def test_deterministic_well_above_threshold():
    # K -> infinity, SNR_mean >> threshold: P_link -> 1
    assert link_success_prob(100, 1e6, 1) == pytest.approx(1, abs=1e-12)


def test_deterministic_well_below_threshold():
    # K -> infinity, SNR_mean << threshold: P_link -> 0
    assert link_success_prob(0.01, 1e6, 1) == pytest.approx(0, abs=1e-12)


def test_rayleigh_matches_closed_form():
    # K = 0 (Rayleigh): P_link = exp(-D_SNR/SNR_mean)
    snr_mean, d_snr = 5, 1
    assert link_success_prob(snr_mean, 0, d_snr) == pytest.approx(
        math.exp(-d_snr / snr_mean), abs=1e-12)


@pytest.mark.parametrize("k", [0, 0.5, 3.07, 5.63, 17.06])
@pytest.mark.parametrize("ratio", [0.5, 1, 2, 10])
def test_regression_against_monte_carlo(k, ratio):
    # The analytic form must reproduce Monte Carlo sampling of the Rician
    # squared envelope to within sampling noise: std err <= 0.5/sqrt(N_MC)
    # = 5e-4 per point, abs tol 5e-3 gives 10 sigma headroom.
    rng = np.random.default_rng(0)
    n_mc = 10 ** 6
    mu = math.sqrt(k / (2 * (k + 1)))
    sigma_h = math.sqrt(1 / (2 * (k + 1)))
    h_sq = ((sigma_h * rng.standard_normal(n_mc) + mu) ** 2
            + (sigma_h * rng.standard_normal(n_mc) + mu) ** 2)
    p_mc = np.mean(ratio * h_sq >= 1)
    assert link_success_prob(ratio, k, 1) == pytest.approx(p_mc, abs=5e-3)


def test_matches_matlab_reference():
    # Values from MATLAB link_success_prob.m (ncx2cdf 'upper'), R2025b
    snr = [2, 2, 5, 5, 0.5]
    k = [0, 3.07, 5.63, 17.06, 3.07]
    expected = [0.606530659712633, 0.755660285295824, 0.974058375837543,
                0.999477301961728, 0.081087088397468]
    np.testing.assert_allclose(link_success_prob(snr, k, 1), expected,
                               atol=1e-12)


def test_vectorized_over_inputs():
    s = np.array([1.0, 2.0, 5.0])
    k = np.array([0.0, 3.07, 17.06])
    p = link_success_prob(s, k, 1)
    expected = [link_success_prob(si, ki, 1) for si, ki in zip(s, k)]
    np.testing.assert_allclose(p, expected, rtol=0)
