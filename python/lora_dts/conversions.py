"""dB / dBm to linear-scale conversions."""

import numpy as np


def db_to_lin(x_db):
    """Convert a dB value to linear scale. Vectorized."""
    return 10.0 ** (np.asarray(x_db, dtype=float) / 10.0)


def dbm_to_lin(x_dbm):
    """Convert a dBm value to linear scale (watts). Vectorized."""
    return 10.0 ** ((np.asarray(x_dbm, dtype=float) - 30.0) / 10.0)
