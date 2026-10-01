"""Elevation-dependent Rician K-factor, SciPy-free web app build.

Overrides python/lora_dts/rician_k.py in the deployed site, so the browser
does not have to download SciPy. Must match it to floating-point precision;
see webapp/tests/test_scipy_free.py.
"""

import numpy as np

_E_DATA = [20.0, 30.0, 40.0, 60.0, 80.0]
_K_DATA = [3.07, 3.24, 3.60, 5.63, 17.06]


def _not_a_knot_spline(x, y):
    """Coefficients of the not-a-knot cubic spline through 5 points.

    Not-a-knot makes the third derivative continuous at x[1] and x[3], so
    the spline is one cubic on [x0, x2] and one on [x2, x4], joined with
    C2 continuity at x2. Each cubic is in powers of (e - x2). Returns the
    (left, right) coefficient rows, highest power first.
    """
    a = np.zeros((8, 8))
    rhs = np.zeros(8)
    row = 0
    for i, xi in enumerate(x):
        u = xi - x[2]
        powers = [u ** 3, u ** 2, u, 1.0]
        if i <= 2:
            a[row, 0:4] = powers
            rhs[row] = y[i]
            row += 1
        if i >= 2:
            a[row, 4:8] = powers
            rhs[row] = y[i]
            row += 1
    # Equal first and second derivatives at x2 (u = 0); the values already
    # agree through the shared interpolation point.
    a[6, [2, 6]] = [1.0, -1.0]
    a[7, [1, 5]] = [1.0, -1.0]
    coef = np.linalg.solve(a, rhs)
    return coef[0:4], coef[4:8]


# Same scheme as MATLAB griddedInterpolant(E_data, K_data, 'spline',
# 'spline') and the SciPy CubicSpline in the reference port.
_C_LEFT, _C_RIGHT = _not_a_knot_spline(_E_DATA, _K_DATA)


def rician_k(e_deg):
    """Elevation-dependent Rician K-factor for LEO satellite links.

    Fitted cubic spline to Kim et al. (2006)'s measured K values at
    {20, 30, 40, 60, 80} degrees elevation:
      - 20 < E < 80: cubic spline interpolation
      - E > 80:      cubic spline extrapolation (further increasing)
      - E < 20:      fixed to K(20) = 3.07, as extrapolation would result
                     in increasing K
    """
    e = np.maximum(np.asarray(e_deg, dtype=float), 20.0)
    u = e - _E_DATA[2]
    k = np.where(u <= 0, np.polyval(_C_LEFT, u), np.polyval(_C_RIGHT, u))
    return k.item() if np.ndim(e_deg) == 0 else k
