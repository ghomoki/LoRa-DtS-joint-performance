"""Interactive web front-end for the LoRa Direct-to-Satellite PDR model."""

import matplotlib.pyplot as plt
import numpy as np
import streamlit as st
from matplotlib.lines import Line2D

from lora_dts import packet_delivery_ratio, rician_k

st.set_page_config(page_title="LoRa DtS design space", layout="wide")

st.title(
    "Trading Range for Throughput: Joint Channel Modeling and Design "
    "Space Exploration for LoRa Direct-to-Satellite Links"
)

# Fixed scenario constants (everything not exposed in the UI keeps the
# model defaults; E_min and CR match the MATLAB scenario scripts).
E_MIN = 1.0  # Minimum elevation angle (deg)
CR = 1       # Coding rate index (4/5)

SF_VALUES = [7, 8, 9, 10, 11, 12]
BW_KHZ = [7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5, 125.0, 250.0, 500.0]
# Bandwidth grid of the design-space exploration (matches pareto_front.m)
DS_BW_KHZ = [31.25, 62.5, 125.0, 250.0, 500.0]

# Line colors of the MATLAB figures in scripts/, for figure parity with
# the paper. C_BLUE / C_ORANGE / C_GREEN are the sweep-script palette.
C_BLUE = "#0072BD"      # [0.00 0.45 0.74]
C_ORANGE = "#D95319"    # [0.85 0.33 0.10]
C_GREEN = "#77AC30"     # [0.47 0.67 0.19]
C_GRAY = "#808080"      # [0.50 0.50 0.50], sensitivity line
C_PLINK = "#05CFE6"     # [5 207 230]/256, P_link
C_PSUCCESS = "#30961A"  # [48 150 26]/256, P_success

# MATLAB's default axes appearance: 4:3 figure on a 0.94 gray canvas,
# white plot box with all four sides drawn, inward ticks, and a light
# solid grid painted under the data.
plt.rcParams.update({
    "figure.facecolor": "#F0F0F0",
    "figure.dpi": 140,
    "axes.facecolor": "white",
    "axes.edgecolor": "#262626",
    "axes.labelcolor": "#262626",
    "axes.linewidth": 0.8,
    "axes.axisbelow": True,
    "axes.grid": True,
    "grid.color": "#262626",
    "grid.alpha": 0.15,
    "grid.linewidth": 0.8,
    "grid.linestyle": "-",
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.color": "#262626",
    "ytick.color": "#262626",
    "xtick.top": True,
    "ytick.right": True,
    "font.family": ["Helvetica", "Arial", "DejaVu Sans"],
    "font.size": 10,
    "axes.labelsize": 11,   # MATLAB LabelFontSizeMultiplier = 1.1
    "legend.fontsize": 10,
    "legend.edgecolor": "#262626",
    "legend.framealpha": 1.0,
    "legend.borderpad": 0.4,
})

# MATLAB's default figure is 560x420 px. Reproducing that size at 10 pt
# text keeps the label-to-axes proportions identical to the paper figures;
# the raised dpi only renders it at more pixels for the browser.
FIGSIZE = (5.6, 4.2)

PARAM_LABELS = {
    "f_c_mhz": "Carrier frequency (MHz)",
    "h_km": "Altitude (km)",
    "p_l": "Payload length (bytes)",
    "sf": "Spreading factor",
    "b_khz": "Bandwidth (kHz)",
    "ldro": "LDRO",
}

# Axis labels and legend placement of the matching scripts/sweep_pdr_vs_*.m
AXIS_LABELS = {
    "f_c_mhz": "Carrier frequency (MHz)",
    "h_km": "Orbital altitude (km)",
    "p_l": "Application payload (bytes)",
    "sf": "Spreading factor",
    "b_khz": "Bandwidth (kHz)",
}
LEGEND_LOC = {
    "f_c_mhz": "upper right",
    "h_km": "upper right",
    "p_l": "upper right",
    "sf": "upper left",
    "b_khz": "upper left",
}


def bit_rate_bps(sf, b_khz, ldro):
    """LoRa bit rate: (SF - 2*LDRO) effective bits per symbol, B chips/s,
    2^SF chips per symbol, factor 4/(4+CR) for forward error correction."""
    return (sf - 2 * ldro) * (b_khz * 1e3) * (4 / (4 + CR)) / 2**sf


@st.cache_data
def run_pass(f_c_mhz, h_km, p_l, sf, b_khz, ldro):
    return packet_delivery_ratio(
        E_MIN, b_khz, f_c_mhz, int(ldro), sf, p_l, h_km
    )


def param_inputs(tab, exclude=(), lora=True):
    """Render the model parameter widgets; returns {name: value}.

    Excluded parameters' slots are left empty; with lora=False only the
    scenario set (carrier frequency, altitude, payload) is rendered.
    """
    vals = {}
    scenario_col, lora_col = st.columns(2, gap="large")

    with scenario_col:
        c1, c2, c3 = st.columns(3)
        if "f_c_mhz" not in exclude:
            vals["f_c_mhz"] = c1.number_input(
                PARAM_LABELS["f_c_mhz"], min_value=100.0, max_value=3000.0,
                value=868.0, step=1.0, key=f"{tab}_f_c")
        if "h_km" not in exclude:
            vals["h_km"] = c2.number_input(
                PARAM_LABELS["h_km"], min_value=300, max_value=2500,
                value=550, step=10, key=f"{tab}_h")
        if "p_l" not in exclude:
            vals["p_l"] = c3.number_input(
                PARAM_LABELS["p_l"], min_value=1, max_value=255,
                value=50, step=1, key=f"{tab}_p_l")

    if lora:
        with lora_col:
            c4, c5, c6 = st.columns(3)
            if "sf" not in exclude:
                vals["sf"] = c4.selectbox(
                    PARAM_LABELS["sf"], SF_VALUES, index=3, key=f"{tab}_sf")
            if "b_khz" not in exclude:
                vals["b_khz"] = c5.selectbox(
                    PARAM_LABELS["b_khz"], BW_KHZ, index=7, key=f"{tab}_b")
            if "ldro" not in exclude:
                # Label above the switch, matching the other widgets
                c6.markdown(
                    f'<p style="font-size:14px; margin-bottom:0.25rem">'
                    f'{PARAM_LABELS["ldro"]}</p>',
                    unsafe_allow_html=True)
                vals["ldro"] = c6.toggle(
                    PARAM_LABELS["ldro"], value=False, key=f"{tab}_ldro",
                    label_visibility="collapsed")

    return vals


tab_single, tab_sweep, tab_ds = st.tabs(
    ["Single-pass analysis", "Parameter sweep", "Design space exploration"]
)

# --------------------------------------------------------------- Tab 1
with tab_single:
    p = param_inputs("single")
    res = run_pass(**p)
    p_success = ~res.l_static * ~res.l_dynamic * res.p_link
    t = res.time_s

    m1, m2 = st.columns(2)
    m1.metric("PDR", f"{res.pdr * 100:.1f} %")
    m2.metric("Data rate", f"{bit_rate_bps(p['sf'], p['b_khz'], p['ldro']):.0f} bps")

    c_plot1, c_plot2, c_plot3 = st.columns(3)

    # Panel 1: reception probability (scripts/pdr_three_failure_modes.m).
    # The Doppler markers are only drawn — and only appear in the legend —
    # when that failure mode actually fires, as in the MATLAB script.
    fig1, ax = plt.subplots(figsize=FIGSIZE)
    ax.plot(t, res.p_link, "-", color=C_PLINK, lw=1.3, label="$P_{link}$")
    ax.plot(t, p_success, "-", color=C_PSUCCESS, lw=2.3,
            label="$P_{success}$")
    if res.l_static.any():
        ax.plot(t[res.l_static], np.zeros(res.l_static.sum()), ".",
                color=C_BLUE, ms=6, ls="none", label="$L_{static}$ = true")
    if res.l_dynamic.any():
        ax.plot(t[res.l_dynamic], np.zeros(res.l_dynamic.sum()), ".",
                color=C_ORANGE, ms=6, ls="none", label="$L_{dynamic}$ = true")
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Packet reception probability")
    ax.set_xlim(t[0], t[-1])
    ax.set_ylim(-0.05, 1.05)
    ax.legend(loc="upper right")
    fig1.tight_layout()
    c_plot1.pyplot(fig1)
    plt.close(fig1)

    # Panel 2: link margin, with the dashed sensitivity line at 0 dB
    fig2, ax = plt.subplots(figsize=FIGSIZE)
    ax.plot(t, res.link_margin_db, "-", color=C_BLUE, lw=1.5)
    ax.axhline(0, ls="--", color=C_GRAY, lw=1.0)
    ax.text(t[0], 0, " sensitivity", color=C_GRAY, fontsize=9,
            ha="left", va="bottom")
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Link margin (dB)")
    ax.set_xlim(t[0], t[-1])
    fig2.tight_layout()
    c_plot2.pyplot(fig2)
    plt.close(fig2)

    # Panel 3: pass geometry — elevation with the Rician K factor it drives
    fig3, ax = plt.subplots(figsize=FIGSIZE)
    ax.plot(t, res.elevation_deg, "-", color=C_BLUE, lw=1.5)
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Elevation (deg)", color=C_BLUE)
    ax.tick_params(axis="y", colors=C_BLUE)
    ax.set_xlim(t[0], t[-1])
    ax.set_ylim(0, 90)
    ax_k = ax.twinx()
    ax_k.plot(t, rician_k(res.elevation_deg), "-", color=C_ORANGE, lw=1.5)
    ax_k.set_ylabel("Rician K factor", color=C_ORANGE)
    ax_k.tick_params(axis="y", colors=C_ORANGE, direction="in")
    ax_k.grid(False)
    fig3.tight_layout()
    c_plot3.pyplot(fig3)
    plt.close(fig3)

# --------------------------------------------------------------- Tab 2
with tab_sweep:
    N_SWEEP = 15

    c_sel, c_min, c_max = st.columns([2, 1, 1])
    sweep_key = c_sel.selectbox(
        "Parameter to sweep", [k for k in PARAM_LABELS if k != "ldro"],
        format_func=PARAM_LABELS.get, key="sweep_param")

    # Sweep grid: min/max inputs for the continuous parameters, the full
    # discrete grid otherwise.
    if sweep_key == "f_c_mhz":
        lo = c_min.number_input("Min", 100.0, 3000.0, 400.0, key="sw_lo_f")
        hi = c_max.number_input("Max", 100.0, 3000.0, 2450.0, key="sw_hi_f")
        sweep_vals = list(np.linspace(lo, hi, N_SWEEP))
    elif sweep_key == "h_km":
        lo = c_min.number_input("Min", 300, 2500, 300, key="sw_lo_h")
        hi = c_max.number_input("Max", 300, 2500, 2500, key="sw_hi_h")
        sweep_vals = list(np.linspace(lo, hi, N_SWEEP))
    elif sweep_key == "p_l":
        lo = c_min.number_input("Min", 1, 255, 10, key="sw_lo_p")
        hi = c_max.number_input("Max", 1, 255, 250, key="sw_hi_p")
        sweep_vals = sorted(set(
            int(v) for v in np.linspace(lo, hi, N_SWEEP).round()))
    elif sweep_key == "sf":
        sweep_vals = SF_VALUES
    else:  # b_khz
        sweep_vals = BW_KHZ

    p = param_inputs("sweep", exclude=(sweep_key, "ldro"))

    # One line per LDRO state; LDRO-off points are skipped where LDRO is
    # mandated (symbol time 2^SF / B reaching 16.38 ms).
    pdr_on = np.full(len(sweep_vals), np.nan)
    pdr_off = np.full(len(sweep_vals), np.nan)
    with st.spinner("Sweeping..."):
        for i, v in enumerate(sweep_vals):
            q = {**p, sweep_key: v}
            pdr_on[i] = run_pass(**q, ldro=True).pdr * 100
            if 2 ** q["sf"] / q["b_khz"] < 16.38:
                pdr_off[i] = run_pass(**q, ldro=False).pdr * 100

    # Solid line for LDRO off, dashed for LDRO on, as in sweep_pdr_vs_*.m
    fig, ax = plt.subplots(figsize=FIGSIZE)
    if not np.all(np.isnan(pdr_off)):
        ax.plot(sweep_vals, pdr_off, "-", marker="o", color=C_BLUE,
                mfc=C_BLUE, lw=1.6, ms=5, label="LDRO off")
    ax.plot(sweep_vals, pdr_on, "--", marker="o", color=C_ORANGE,
            mfc=C_ORANGE, lw=1.6, ms=5, label="LDRO on")
    if sweep_key == "b_khz":
        ax.set_xscale("log")
        # Ticks on the bandwidth values themselves, as in sweep_pdr_vs_bw.m.
        # Rotated because the app offers 10 bandwidths where the script
        # plots 7, and upright labels would overlap.
        ax.set_xticks(sweep_vals, [f"{b:g}" for b in sweep_vals],
                      rotation=45, ha="right")
        ax.minorticks_off()
    elif sweep_key == "sf":
        ax.set_xticks(sweep_vals)
    ax.set_xlabel(AXIS_LABELS[sweep_key])
    ax.set_ylabel("PDR (%)")
    ax.set_xlim(min(sweep_vals), max(sweep_vals))
    ax.set_ylim(0, 100)
    ax.legend(loc=LEGEND_LOC[sweep_key])
    fig.tight_layout()
    st.columns(2)[0].pyplot(fig)
    plt.close(fig)

# --------------------------------------------------------------- Tab 3
with tab_ds:
    p = param_inputs("ds", lora=False)

    # LDRO is mandatory when the symbol time reaches 16.38 ms; elsewhere
    # both LDRO choices are separate design points (as in pareto_front.m).
    configs = []
    for sf in SF_VALUES:
        for b in DS_BW_KHZ:
            ldro_choices = [True] if 2**sf / b >= 16.38 else [False, True]
            configs.extend((sf, b, ldro) for ldro in ldro_choices)

    pdr_pct = np.empty(len(configs))
    rate = np.empty(len(configs))
    with st.spinner(f"Computing {len(configs)} configurations..."):
        for i, (sf, b, ldro) in enumerate(configs):
            pdr_pct[i] = run_pass(**p, sf=sf, b_khz=b, ldro=ldro).pdr * 100
            rate[i] = bit_rate_bps(sf, b, ldro)

    # Pareto-optimal: no other point has both higher PDR and higher rate.
    # Points below a 1% PDR floor are not real design choices.
    viable = pdr_pct > 1.0
    is_pareto = np.array([
        not np.any((pdr_pct >= pdr_pct[i]) & (rate >= rate[i])
                   & ((pdr_pct > pdr_pct[i]) | (rate > rate[i])))
        for i in range(len(configs))
    ]) & viable

    sf_colors = plt.cm.turbo(np.linspace(0, 1, len(SF_VALUES)))
    bw_markers = ["o", "s", "^", "d", "v"]

    fig, ax = plt.subplots(figsize=FIGSIZE)
    for i, (sf, b, ldro) in enumerate(configs):
        if not viable[i]:
            continue
        color = sf_colors[SF_VALUES.index(sf)]
        marker = bw_markers[DS_BW_KHZ.index(b)]
        face = color if ldro else "w"
        if is_pareto[i]:
            ax.scatter(rate[i], pdr_pct[i], s=64, marker=marker, zorder=3,
                       edgecolors=[color], facecolors=[face], linewidths=1.8)
        else:
            ax.scatter(rate[i], pdr_pct[i], s=16, marker=marker, zorder=2,
                       edgecolors=[color], facecolors=[face], linewidths=0.6,
                       alpha=0.55)

    ax.set_xscale("log")
    ax.set_xlim(90, 2e4)
    ax.set_ylim(0, 100)
    ax.set_xlabel("Bit rate (bps)")
    ax.set_ylabel("PDR (%)")

    legend_handles = [
        Line2D([], [], ls="", marker="s", ms=8, color=sf_colors[s],
               label=f"SF{sf}")
        for s, sf in enumerate(SF_VALUES)
    ] + [
        Line2D([], [], ls="", marker=m, ms=8, color="k",
               label=f"B={b:g} kHz")
        for m, b in zip(bw_markers, DS_BW_KHZ)
    ] + [
        Line2D([], [], ls="", marker="o", ms=8, mfc="k", mec="k",
               label="LDRO on"),
        Line2D([], [], ls="", marker="o", ms=8, mfc="w", mec="k",
               label="LDRO off"),
    ]
    ax.legend(handles=legend_handles, loc="center left",
              bbox_to_anchor=(1.02, 0.5), fontsize=9)
    fig.tight_layout()
    st.columns([3, 2])[0].pyplot(fig)
    plt.close(fig)
