"""Interactive web front-end for the LoRa Direct-to-Satellite PDR model."""

import pandas as pd
import streamlit as st

from lora_dts import lora_toa, packet_delivery_ratio, pass_duration

st.set_page_config(page_title="LoRa DtS PDR model", layout="wide")

st.title("LoRa Direct-to-Satellite Packet Delivery Ratio")
st.caption(
    "Doppler, link-budget and Rician-fading model of a direct overhead "
    "LEO satellite pass. The link success probability is evaluated "
    "analytically (noncentral chi-square survival function)."
)

LORA_BANDWIDTHS_KHZ = [7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5,
                       125.0, 250.0, 500.0]

with st.sidebar:
    st.header("LoRa configuration")
    sf = st.slider("Spreading factor", 7, 12, 10)
    b_khz = st.select_slider("Bandwidth (kHz)", options=LORA_BANDWIDTHS_KHZ,
                             value=125.0)
    f_c_mhz = st.number_input("Carrier frequency (MHz)", min_value=100.0,
                              max_value=3000.0, value=868.0, step=0.1)
    ldro = st.toggle("Low data rate optimization (LDRO)", value=False)
    p_l = st.slider("Payload (bytes)", 1, 255, 55)

    st.header("Orbit and pass")
    h_km = st.slider("Satellite altitude (km)", 300, 2500, 780, step=10)
    e_min = st.slider("Minimum elevation (deg)", 0, 45, 5)
    r_p = st.slider("Packet reporting interval (s)", 1, 60, 5)

    with st.expander("Link budget"):
        p_tx_dbm = st.slider("Tx power (dBm)", 0, 30, 20)
        g_t = st.slider("Tx antenna gain (dBi)", -5, 15, 2)
        g_r = st.slider("Rx antenna gain (dBi)", -5, 15, 2)
        nf_db = st.slider("Rx noise figure (dB)", 0, 12, 6)

    with st.expander("Packet structure"):
        n_preamble = st.slider("Preamble length (symbols)", 6, 20, 8)
        cr = st.select_slider("Coding rate", options=[1, 2, 3, 4], value=1,
                              format_func=lambda i: f"4/{4 + i}")
        pl_overhead = st.slider("MAC overhead (bytes)", 0, 20, 5)

res = packet_delivery_ratio(
    e_min, b_khz, f_c_mhz, int(ldro), sf, p_l, h_km,
    r_p=r_p, n_preamble=n_preamble, cr=cr, pl_overhead=pl_overhead,
    g_t=g_t, g_r=g_r, p_tx_dbm=p_tx_dbm, nf_db=nf_db,
)
tau, _ = pass_duration(h_km, e_min)
toa_ms = lora_toa(sf, b_khz, p_l, int(ldro), n_preamble=n_preamble,
                  cr=cr, pl_overhead=pl_overhead)
p_success = ~res.l_static * ~res.l_dynamic * res.p_link

m1, m2, m3, m4, m5 = st.columns(5)
m1.metric("PDR", f"{res.pdr:.3f}")
m2.metric("Packets in pass", len(res.time_s))
m3.metric("Time on air", f"{toa_ms / 1000:.2f} s")
m4.metric("Pass duration", f"{tau / 60:.1f} min")
m5.metric("Doppler-blocked packets",
          f"{(res.l_static | res.l_dynamic).mean():.0%}")

left, right = st.columns(2)

with left:
    st.subheader("Packet success probability")
    st.line_chart(
        pd.DataFrame(
            {
                "P_link (fading only)": res.p_link,
                "P_success (incl. Doppler)": p_success,
            },
            index=pd.Index(res.time_s, name="Time from zenith (s)"),
        )
    )

    st.subheader("Link margin")
    st.line_chart(
        pd.DataFrame(
            {"Link margin (dB)": res.link_margin_db},
            index=pd.Index(res.time_s, name="Time from zenith (s)"),
        )
    )

with right:
    st.subheader("Doppler shift vs. static tolerance")
    st.line_chart(
        pd.DataFrame(
            {
                "Doppler shift (Hz)": res.doppler_shift_hz,
                "+B/4": [0.25 * b_khz * 1e3] * len(res.time_s),
                "-B/4": [-0.25 * b_khz * 1e3] * len(res.time_s),
            },
            index=pd.Index(res.time_s, name="Time from zenith (s)"),
        )
    )

    st.subheader("Pass geometry")
    st.line_chart(
        pd.DataFrame(
            {"Elevation (deg)": res.elevation_deg},
            index=pd.Index(res.time_s, name="Time from zenith (s)"),
        )
    )

with st.expander("Per-packet results table"):
    st.dataframe(
        pd.DataFrame(
            {
                "Time (s)": res.time_s,
                "Elevation (deg)": res.elevation_deg,
                "Slant range (km)": res.slant_range_m / 1e3,
                "Doppler shift (Hz)": res.doppler_shift_hz,
                "Packet Doppler shift (Hz)": res.packet_doppler_shift_hz,
                "Link margin (dB)": res.link_margin_db,
                "P_link": res.p_link,
                "Static loss": res.l_static,
                "Dynamic loss": res.l_dynamic,
                "P_success": p_success,
            }
        ),
        width="stretch",
    )
