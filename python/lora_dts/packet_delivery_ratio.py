"""LoRa Direct-to-Satellite PDR model, port of packetdeliveryratio.m."""

from dataclasses import dataclass

import numpy as np

from .conversions import db_to_lin, dbm_to_lin
from .link_success_prob import link_success_prob
from .lora_toa import lora_toa
from .pass_duration import pass_duration
from .rician_k import rician_k

R_E = 6371e3        # Earth radius                (m)
G = 9.80665         # Gravitational acceleration  (m/s^2)
C = 299792458.0     # Speed of light              (m/s)


@dataclass
class PassResult:
    """Per-packet results over the pass plus the aggregate PDR."""

    pdr: float                          # Packet delivery ratio over the pass
    time_s: np.ndarray                  # Packet start time from zenith  (s)
    elevation_deg: np.ndarray           # Elevation angle                (deg)
    slant_range_m: np.ndarray           # Slant range                    (m)
    doppler_shift_hz: np.ndarray        # Doppler shift                  (Hz)
    doppler_rate_hz_s: np.ndarray       # Doppler rate (diagnostic)      (Hz/s)
    packet_doppler_shift_hz: np.ndarray # Doppler shift within packet    (Hz)
    link_margin_db: np.ndarray          # Margin above sensitivity       (dB)
    p_link: np.ndarray                  # Link budget closure probability
    l_static: np.ndarray                # Static  Doppler failure (bool)
    l_dynamic: np.ndarray               # Dynamic Doppler failure (bool)

    @property
    def l_joint(self):
        """Joint Doppler failure per packet."""
        return self.l_static & self.l_dynamic


def packet_delivery_ratio(e_min, b_khz, f_c_mhz, ldro, sf, p_l, h_km, *,
                          r_p=5, n_preamble=8, ih=0, crc=1, cr=1,
                          pl_overhead=5, g_t=2, g_r=2, p_tx_dbm=20,
                          nf_db=6):
    """LoRa Direct-to-Satellite packet delivery ratio with Doppler +
    link-budget constraints.

    For a direct overhead satellite pass at packet reporting interval r_p,
    and for each candidate packet:
      1. Evaluates static and dynamic Doppler failure conditions.
      2. Computes the deterministic mean SNR from the link budget (Friis
         path loss, antenna gains, receiver noise figure).
      3. Evaluates the link success probability under elevation-dependent
         Rician fading analytically.
      4. Combines: P_success = (1 - L_static)*(1 - L_dynamic)*P_link.

    PDR is the mean of P_success over all packets in the pass.

    Parameters
    ----------
    e_min : float
        Minimum elevation angle (deg).
    b_khz : float
        Bandwidth setting (kHz).
    f_c_mhz : float
        Carrier frequency (MHz).
    ldro : int or bool
        Low data rate optimization (0/1).
    sf : int
        Spreading factor (7..12).
    p_l : int
        Packet payload length (bytes).
    h_km : float
        Satellite altitude (km).
    r_p : float
        Packet reporting interval (s).
    n_preamble : int
        LoRa preamble length (symbols).
    ih : int
        Implicit header (0/1).
    crc : int
        Cyclic redundancy check (0/1).
    cr : int
        Coding rate index (1..4).
    pl_overhead : int
        MAC overhead added to payload (bytes).
    g_t, g_r : float
        Tx / Rx antenna gain (dBi).
    p_tx_dbm : float
        Tx power (dBm).
    nf_db : float
        Receiver noise figure (dB).
    """
    # Convert to SI base units
    b = b_khz * 1e3      # kHz -> Hz
    f_c = f_c_mhz * 1e6  # MHz -> Hz
    h = h_km * 1e3       # km  -> m

    # Time on Air
    toa = lora_toa(sf, b_khz, p_l, ldro, n_preamble=n_preamble, ih=ih,
                   crc=crc, cr=cr, pl_overhead=pl_overhead) * 1e-3  # ms -> s

    # Pass geometry
    tau, v = pass_duration(h_km, e_min)
    omega = np.sqrt(G / R_E) * (1 + h / R_E) ** -1.5  # Angular rate (rad/s)
    u_geo = 1 + h / R_E                               # Cached ratio for cosBeta

    # Doppler tolerance thresholds
    f_static = 0.25 * b
    l_ldro = 1 + 15 * ldro                # 16 if LDRO on, else 1
    f_dynamic = l_ldro * b / (3 * 2 ** sf)

    # Link budget, deterministic part
    d_snr_db = -2.5 * (sf - 4)                        # Receiver SNR threshold
    p_tx_w = dbm_to_lin(p_tx_dbm)
    g_t_lin = db_to_lin(g_t)
    g_r_lin = db_to_lin(g_r)
    d_snr_lin = db_to_lin(d_snr_db)
    sigma_w_dbm = -174 + nf_db + 10 * np.log10(b)     # AWGN power
    sigma_w_w = dbm_to_lin(sigma_w_dbm)
    sensitivity_dbm = sigma_w_dbm + d_snr_db          # Receiver sensitivity

    def orbital_state(t):
        """Orbital state at relative time t (s) from zenith. Vectorized."""
        phi = t * omega
        cos_phi = np.cos(phi)
        sin_phi = np.sin(phi)

        d = np.sqrt(R_E ** 2 + (R_E + h) ** 2 - 2 * R_E * (R_E + h) * cos_phi)
        sin_e = ((R_E + h) * cos_phi - R_E) / d
        e_deg = np.degrees(np.arcsin(sin_e))

        cos_beta = sin_phi / np.sqrt(u_geo ** 2 - 2 * u_geo * cos_phi + 1)
        f_d = f_c / (1 + v / C * cos_beta) - f_c
        return d, e_deg, f_d

    # Packet start times over the pass. Accumulating addition mirrors the
    # MATLAB while loop so both implementations emit identical packet grids.
    t_list = []
    t = -tau / 2
    while t <= tau / 2:
        t_list.append(t)
        t += r_p
    t = np.array(t_list)

    # Doppler shift at packet beginning and end
    d_t, e_t_deg, f_d = orbital_state(t)
    _, _, f_d_end = orbital_state(t + toa)
    # Doppler shift within packet
    delta_f_e = f_d - f_d_end

    # Doppler rate via central difference over 1 ms (diagnostic only)
    dt = 1e-3
    _, _, f_d_plus = orbital_state(t + dt / 2)
    _, _, f_d_minus = orbital_state(t - dt / 2)
    df_d_dt = (f_d_plus - f_d_minus) / dt

    # Per-packet Doppler failure decisions
    l_static = np.abs(f_d) >= f_static
    l_dynamic = np.abs(delta_f_e) >= f_dynamic

    # Friis free-space path loss
    pl_lin = (C / (4 * np.pi * d_t * f_c)) ** 2
    # Received power
    p_rx_mean_w = p_tx_w * g_t_lin * g_r_lin * pl_lin
    # Received SNR
    snr_mean_lin = p_rx_mean_w / sigma_w_w
    # Rician factor
    k = rician_k(e_t_deg)

    # Link budget closure probability
    p_link = link_success_prob(snr_mean_lin, k, d_snr_lin)
    # Combined link budget + Doppler packet success probability
    p_success = ~l_static * ~l_dynamic * p_link

    # Link margin (dB) above receiver sensitivity, for diagnostics
    p_rx_dbm = p_tx_dbm + g_t + g_r + 10 * np.log10(pl_lin)
    link_margin_db = p_rx_dbm - sensitivity_dbm

    return PassResult(
        pdr=float(np.mean(p_success)),
        time_s=t,
        elevation_deg=e_t_deg,
        slant_range_m=d_t,
        doppler_shift_hz=f_d,
        doppler_rate_hz_s=df_d_dt,
        packet_doppler_shift_hz=delta_f_e,
        link_margin_db=link_margin_db,
        p_link=p_link,
        l_static=l_static,
        l_dynamic=l_dynamic,
    )
