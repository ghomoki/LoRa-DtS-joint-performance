"""Elevation-dependent Rician K-factor, port of rician_K.m."""

import numpy as np
from scipy.interpolate import CubicSpline

_E_DATA = [20.0, 30.0, 40.0, 60.0, 80.0]
_K_DATA = [3.07, 3.24, 3.60, 5.63, 17.06]

# Not-a-knot cubic spline with cubic extrapolation: the same scheme as
# MATLAB griddedInterpolant(E_data, K_data, 'spline', 'spline').
_K_MODEL = CubicSpline(_E_DATA, _K_DATA, bc_type="not-a-knot",
                       extrapolate=True)


def rician_k(e_deg):
    """Rician K-factor for LEO satellite links at elevation e_deg (degrees).

    Fitted cubic spline to Kim et al. (2006)'s measured K values at
    {20, 30, 40, 60, 80} degrees elevation:
      - 20 < E < 80: cubic spline interpolation
      - E > 80:      cubic spline extrapolation (further increasing)
      - E < 20:      fixed to K(20) = 3.07, as extrapolation would result
                     in increasing K
    """
    e = np.maximum(np.asarray(e_deg, dtype=float), 20.0)
    k = _K_MODEL(e)
    return k.item() if np.ndim(e_deg) == 0 else k
