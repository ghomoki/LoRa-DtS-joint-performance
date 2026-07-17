"""Overhead-pass geometry, port of pass_duration.m."""

import math

R_E = 6371e3    # Earth radius               (m)
G = 9.80665     # Gravitational acceleration (m/s^2)


def pass_duration(h_km, e_min_deg):
    """Pass duration and orbital velocity for a direct overhead pass.

    Returns (tau, v): the visibility time in seconds for a satellite in a
    circular orbit at altitude h_km passing directly overhead a ground
    station, subject to a minimum elevation angle e_min_deg, and the
    orbital velocity in m/s.
    """
    h = h_km * 1e3
    e_min = math.radians(e_min_deg)

    # Slant range at minimum elevation
    d_m = R_E * (math.sqrt(((h + R_E) / R_E) ** 2 - math.cos(e_min) ** 2)
                 - math.sin(e_min))

    # Angle at Earth center from zenith to minimum elevation
    alpha = math.asin(d_m * math.cos(e_min) / (R_E + h))

    # Orbital velocity of circular orbit
    v = math.sqrt(G * R_E / (1 + h / R_E))

    # Pass time = 2 * (orbit radius * angle, orbit arc length) / velocity
    tau = 2 * (R_E + h) * alpha / v
    return tau, v
