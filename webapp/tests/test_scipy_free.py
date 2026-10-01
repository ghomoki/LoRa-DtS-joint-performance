"""Regression tests of the web app's SciPy-free model build.

The deployed site is python/lora_dts with webapp/lora_dts copied over it
(see .github/workflows/deploy-pages.yml), which replaces the two modules
that use SciPy. These tests assemble the package the same way and require
it to reproduce the SciPy reference port, both module by module and in
every result the app shows, to floating-point precision.

Run from the repository root:  py -m pytest webapp/tests
"""

import importlib
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python"))

import lora_dts as ref  # noqa: E402  SciPy reference port

# Absolute tolerance on probabilities (P_link, PDR) and on K. Observed
# differences are ~3e-14; anything model-relevant would be orders larger.
ATOL = 1e-13

# Paper baseline and the app's constants (webapp/streamlit_app.py)
E_MIN = 1.0
SF_VALUES = [7, 8, 9, 10, 11, 12]
BW_KHZ = [7.81, 15.63, 31.25, 62.5, 125.0, 250.0, 500.0]
DS_BW_KHZ = [31.25, 62.5, 125.0, 250.0, 500.0]
P_TX_DBM = list(range(-4, 18)) + [20]
BASELINE = dict(f_c_mhz=915.0, h_km=1000, p_l=100, sf=8, b_khz=62.5,
                ldro=False, p_tx_dbm=20, g_t=2.0, g_r=2.0)


@pytest.fixture(scope="session")
def web(tmp_path_factory):
    """The package as deployed: reference modules + web app overrides."""
    site = tmp_path_factory.mktemp("site")
    pkg = site / "lora_dts_web"
    shutil.copytree(ROOT / "python" / "lora_dts", pkg,
                    ignore=shutil.ignore_patterns("__pycache__"))
    overrides = sorted((ROOT / "webapp" / "lora_dts").glob("*.py"))
    assert {p.name for p in overrides} == {"rician_k.py",
                                          "link_success_prob.py"}
    for p in overrides:
        shutil.copy(p, pkg / p.name)
    sys.path.insert(0, str(site))
    return importlib.import_module("lora_dts_web")


def run(pkg, f_c_mhz, h_km, p_l, sf, b_khz, ldro, p_tx_dbm, g_t, g_r):
    """One pass exactly as the app's run_pass() calls the model."""
    return pkg.packet_delivery_ratio(
        E_MIN, b_khz, f_c_mhz, int(ldro), sf, p_l, h_km,
        p_tx_dbm=p_tx_dbm, g_t=g_t, g_r=g_r)


def assert_same_pass(a, b):
    assert a.pdr == pytest.approx(b.pdr, abs=ATOL, rel=0)
    np.testing.assert_allclose(a.p_link, b.p_link, atol=ATOL, rtol=0)
    # Everything upstream of the two replaced modules is shared code
    for field in ("time_s", "elevation_deg", "doppler_shift_hz",
                  "doppler_rate_hz_s", "packet_doppler_shift_hz",
                  "link_margin_db", "l_static", "l_dynamic"):
        np.testing.assert_array_equal(getattr(a, field), getattr(b, field))


# --- No SciPy -------------------------------------------------------------

def test_web_build_does_not_import_scipy(web):
    # Fresh interpreter with SciPy made unimportable
    code = (
        "import sys; sys.modules['scipy'] = None\n"
        f"sys.path.insert(0, {str(Path(web.__file__).parents[1])!r})\n"
        "import lora_dts_web as m\n"
        "r = m.packet_delivery_ratio(1.0, 62.5, 915.0, 0, 8, 100, 1000)\n"
        "print(r.pdr)\n")
    out = subprocess.run([sys.executable, "-c", code], capture_output=True,
                         text=True)
    assert out.returncode == 0, out.stderr
    assert float(out.stdout) == pytest.approx(ref.packet_delivery_ratio(
        1.0, 62.5, 915.0, 0, 8, 100, 1000).pdr, abs=ATOL, rel=0)


def test_app_and_index_do_not_request_scipy():
    app = (ROOT / "webapp" / "streamlit_app.py").read_text(encoding="utf-8")
    index = (ROOT / "webapp" / "index.html").read_text(encoding="utf-8")
    assert "scipy" not in app.lower()
    assert '"scipy"' not in index


# --- Module level ---------------------------------------------------------

def test_rician_k_dense_grid(web):
    # Below the 20 deg clamp, interpolation range, extrapolation to zenith
    e = np.linspace(-10.0, 95.0, 210001)
    np.testing.assert_allclose(web.rician_k(e), ref.rician_k(e),
                               atol=ATOL, rtol=0)


@pytest.mark.parametrize("e", [-5.0, 0.0, 19.99, 20.0, 30.0, 40.0, 60.0,
                               80.0, 90.0])
def test_rician_k_knots_and_scalars(web, e):
    k = web.rician_k(e)
    assert isinstance(k, float)
    assert k == pytest.approx(ref.rician_k(e), abs=ATOL, rel=0)


def test_rician_k_measured_values():
    # Must still interpolate Kim et al. (2006)'s values exactly
    k = importlib.import_module("lora_dts_web").rician_k(
        np.array([20.0, 30.0, 40.0, 60.0, 80.0]))
    np.testing.assert_allclose(k, [3.07, 3.24, 3.60, 5.63, 17.06],
                               atol=ATOL, rtol=0)


def test_link_success_prob_dense_grid(web):
    # K from Rayleigh to beyond K(90 deg) = 29.4; mean SNR from 40 dB below
    # to 60 dB above the threshold
    k = np.linspace(0.0, 40.0, 401)[:, None]
    ratio = np.logspace(-4, 6, 1001)[None, :]
    np.testing.assert_allclose(web.link_success_prob(ratio, k, 1.0),
                               ref.link_success_prob(ratio, k, 1.0),
                               atol=ATOL, rtol=0)


def test_link_success_prob_threshold_scaling(web):
    # Only SNR_mean / D_SNR matters, for every SF threshold
    for sf in SF_VALUES:
        d_snr = 10 ** (-2.5 * (sf - 4) / 10)
        snr = np.logspace(-3, 1, 201) * d_snr
        k = np.full_like(snr, 5.63)
        np.testing.assert_allclose(web.link_success_prob(snr, k, d_snr),
                                   ref.link_success_prob(snr, k, d_snr),
                                   atol=ATOL, rtol=0)


def test_link_success_prob_closed_forms(web):
    # Rayleigh: exp(-D/S); deterministic limits; MATLAB reference values
    assert web.link_success_prob(5, 0, 1) == pytest.approx(
        math.exp(-0.2), abs=1e-15)
    assert web.link_success_prob(100, 1e4, 1) == pytest.approx(1, abs=1e-12)
    assert web.link_success_prob(0.01, 1e4, 1) == pytest.approx(0, abs=1e-12)
    np.testing.assert_allclose(
        web.link_success_prob([2, 2, 5, 5, 0.5],
                              [0, 3.07, 5.63, 17.06, 3.07], 1),
        [0.606530659712633, 0.755660285295824, 0.974058375837543,
         0.999477301961728, 0.081087088397468], atol=1e-12)


def test_link_success_prob_shapes(web):
    assert isinstance(web.link_success_prob(2.0, 3.07, 1.0), float)
    p = web.link_success_prob(np.ones((3, 4)), np.full(4, 3.07), 1.0)
    assert p.shape == (3, 4)
    assert np.all((p >= 0) & (p <= 1))


# --- Every result the app shows -------------------------------------------

def test_baseline_pass(web):
    a, b = run(web, **BASELINE), run(ref, **BASELINE)
    assert_same_pass(a, b)
    assert round(a.pdr, 4) == 0.1322  # Paper, section 3.1: PDR = 13.2%


def test_single_pass_tab_inputs(web):
    # One-at-a-time changes of every input over its full UI range
    grid = {
        "f_c_mhz": np.linspace(100.0, 3000.0, 30),
        "h_km": np.linspace(300, 2500, 23).round().astype(int),
        "p_l": [1, 10, 50, 100, 150, 200, 255],
        "sf": SF_VALUES,
        "b_khz": BW_KHZ,
        "ldro": [False, True],
        "p_tx_dbm": P_TX_DBM,
        "g_t": np.arange(-10.0, 30.5, 2.5),
        "g_r": np.arange(-10.0, 30.5, 2.5),
    }
    for key, values in grid.items():
        for v in values:
            p = {**BASELINE, key: v}
            assert_same_pass(run(web, **p), run(ref, **p))


def test_random_input_combinations(web):
    rng = np.random.default_rng(0)
    for _ in range(300):
        p = dict(
            f_c_mhz=float(rng.uniform(100.0, 3000.0)),
            h_km=int(rng.integers(300, 2501)),
            p_l=int(rng.integers(1, 256)),
            sf=int(rng.choice(SF_VALUES)),
            b_khz=float(rng.choice(BW_KHZ)),
            ldro=bool(rng.integers(2)),
            p_tx_dbm=int(rng.choice(P_TX_DBM)),
            g_t=float(rng.uniform(-10.0, 30.0)),
            g_r=float(rng.uniform(-10.0, 30.0)),
        )
        assert_same_pass(run(web, **p), run(ref, **p))


# Default sweep ranges and scenario lists of the sweep tab (paper Figs. 3-7)
_MISSION = [(8, 62.5, False), (10, 125.0, False), (12, 250.0, True)]
SWEEPS = {
    "f_c_mhz": (list(np.linspace(433.0, 2400.0, 15)), _MISSION),
    "h_km": (list(np.linspace(300, 2000, 15)), _MISSION),
    "p_l": (sorted({int(v) for v in np.linspace(10, 200, 15).round()}),
            _MISSION),
    "sf": (SF_VALUES, [(8, b, l) for b in (62.5, 125.0) for l in (0, 1)]),
    "b_khz": (BW_KHZ, [(sf, 62.5, l) for sf in (8, 10, 12) for l in (0, 1)]),
}


@pytest.mark.parametrize("sweep_key", list(SWEEPS))
def test_paper_sweeps(web, sweep_key):
    values, scenarios = SWEEPS[sweep_key]
    base = {k: v for k, v in BASELINE.items()
            if k not in ("sf", "b_khz", "ldro")}
    for sf, b_khz, ldro in scenarios:
        sp = {"sf": sf, "b_khz": b_khz, "ldro": bool(ldro)}
        for v in values:
            p = {**base, **sp, sweep_key: v}
            assert_same_pass(run(web, **p), run(ref, **p))


def _design_space(pkg):
    """PDR (%) and Pareto set, as design_space_results() in the app."""
    configs = [(sf, b, ldro) for sf in SF_VALUES for b in DS_BW_KHZ
               for ldro in ([True] if 2**sf / b >= 16.38 else [False, True])]
    base = {k: v for k, v in BASELINE.items()
            if k not in ("sf", "b_khz", "ldro")}
    pdr = np.array([run(pkg, **base, sf=sf, b_khz=b, ldro=l).pdr * 100
                    for sf, b, l in configs])
    rate = np.array([(sf - 2 * l) * b * 1e3 * 0.8 / 2**sf
                     for sf, b, l in configs])
    pareto = np.array([
        not np.any((pdr >= pdr[i]) & (rate >= rate[i])
                   & ((pdr > pdr[i]) | (rate > rate[i])))
        for i in range(len(configs))]) & (pdr > 1.0)
    return pdr, pareto


def test_design_space(web):
    pdr_web, pareto_web = _design_space(web)
    pdr_ref, pareto_ref = _design_space(ref)
    np.testing.assert_allclose(pdr_web, pdr_ref, atol=100 * ATOL, rtol=0)
    np.testing.assert_array_equal(pareto_web, pareto_ref)
