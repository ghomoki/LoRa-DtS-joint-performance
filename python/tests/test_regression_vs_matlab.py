"""Regression tests pinning the Python port to the MATLAB implementation.

All expected values were generated with the MATLAB model (R2025b) at the
repository state where both implementations use the analytic (noncentral
chi-square) link success probability, printed at 12+ significant digits.
The pipeline is fully deterministic, so tolerances only absorb
cross-library floating-point noise.
"""

import numpy as np
import pytest

from lora_dts import lora_toa, packet_delivery_ratio, pass_duration, rician_k


class TestLoraToa:
    def test_datasheet_defaults(self):
        assert lora_toa(10, 31.25, 55, 1) == pytest.approx(3088.384, abs=1e-9)

    def test_pdr_config(self):
        toa = lora_toa(10, 31.25, 55, 1, n_preamble=8, ih=0, crc=1, cr=1,
                       pl_overhead=5)
        assert toa == pytest.approx(3284.992, abs=1e-9)

    def test_sf7_fast(self):
        toa = lora_toa(7, 500, 255, 0, n_preamble=6, ih=1, crc=0, cr=4)
        assert toa == pytest.approx(154.176, abs=1e-9)

    def test_sf12_ldro_min_payload(self):
        assert lora_toa(12, 125, 1, 1) == pytest.approx(958.464, abs=1e-9)


class TestPassDuration:
    @pytest.mark.parametrize("h_km, e_min, tau_ref, v_ref", [
        (560, 10, 483.491877574741, 7578.268588478022),
        (1500, 1, 1351.155268152175, 7111.365274021420),
        (2000, 15, 1172.944646376198, 6895.714493744924),
    ])
    def test_matches_matlab(self, h_km, e_min, tau_ref, v_ref):
        tau, v = pass_duration(h_km, e_min)
        assert tau == pytest.approx(tau_ref, abs=1e-8)
        assert v == pytest.approx(v_ref, abs=1e-8)


class TestRicianK:
    def test_matches_matlab_spline(self):
        e = [5, 10, 20, 25, 30, 45, 60, 70, 80, 85, 90]
        expected = [3.07, 3.07, 3.07, 3.109375, 3.24, 3.7753125, 5.63,
                    9.5425, 17.06, 22.5628125, 29.4375]
        np.testing.assert_allclose(rician_k(np.array(e)), expected,
                                   atol=1e-10)

    def test_scalar_input_returns_scalar(self):
        assert isinstance(rician_k(45.0), float)


class TestPacketDeliveryRatio:
    def test_comfortable_link(self):
        # Doppler-dominated: generous link budget at 560 km, SF10, LDRO on
        res = packet_delivery_ratio(10, 31.25, 436.7, True, 10, 55, 560)
        assert len(res.time_s) == 97
        assert res.pdr == pytest.approx(0.030871060259, abs=1e-9)

    def test_stressed_link(self):
        # Link margin sweeps through 0 dB: both Doppler and link budget
        # contribute to packet loss
        res = packet_delivery_ratio(1, 125, 915, False, 10, 55, 1500)
        assert len(res.time_s) == 271
        assert res.pdr == pytest.approx(0.057956850261, abs=1e-9)

    def test_sf12_eu868(self):
        res = packet_delivery_ratio(5, 125, 868, False, 12, 20, 780)
        assert res.pdr == pytest.approx(0.158457252599, abs=1e-9)

    def test_non_default_options(self):
        res = packet_delivery_ratio(15, 62.5, 915, True, 11, 100, 2000,
                                    r_p=10, p_tx_dbm=14, g_t=0, g_r=6,
                                    nf_db=4, cr=2)
        assert res.pdr == pytest.approx(0.112795369843, abs=1e-9)

    def test_result_arrays_consistent(self):
        res = packet_delivery_ratio(10, 31.25, 436.7, True, 10, 55, 560)
        n = len(res.time_s)
        for name in ("elevation_deg", "slant_range_m", "doppler_shift_hz",
                     "doppler_rate_hz_s", "packet_doppler_shift_hz",
                     "link_margin_db", "p_link", "l_static", "l_dynamic"):
            assert len(getattr(res, name)) == n, name
        assert np.all((res.p_link >= 0) & (res.p_link <= 1))
        assert res.l_joint.dtype == bool
