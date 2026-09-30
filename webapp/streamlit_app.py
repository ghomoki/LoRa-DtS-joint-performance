"""Interactive web front-end for the LoRa Direct-to-Satellite PDR model."""

import base64
import io

import matplotlib.pyplot as plt
import numpy as np
import streamlit as st
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator, StrMethodFormatter

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

# SX1276 modulation parameter space, as stated in section 2 of the paper
SF_VALUES = [7, 8, 9, 10, 11, 12]
BW_KHZ = [7.81, 15.63, 31.25, 62.5, 125.0, 250.0, 500.0]
# Bandwidth grid of the design-space exploration (matches pareto_front.m)
DS_BW_KHZ = [31.25, 62.5, 125.0, 250.0, 500.0]

# Baseline scenario of the paper (section 3.1): PDR = 13.2%, DR = 1.56 kbps
DEF_F_C_MHZ = 915.0
DEF_H_KM = 1000
DEF_P_L = 100
DEF_SF = 8
DEF_B_KHZ = 62.5
DEF_P_TX_DBM = 20
DEF_G_DBI = 2.0

# SX1276 output power settings (datasheet, RF power amplifiers): -4 to +15 dBm on
# the RFO pin, +2 to +17 dBm on PA_BOOST, both in 1 dB steps, plus the
# +20 dBm high-power mode on PA_BOOST. +18 and +19 dBm are not available.
P_TX_DBM = list(range(-4, 18)) + [20]

# Starting scenario lists of the sweep tab: those of the paper's figures
# (sweep_pdr_vs_*.m). The swept parameter's own entry is ignored.
_MISSION_SWEEP_SCENARIOS = [
    {"sf": 8, "b_khz": 62.5, "ldro": False},
    {"sf": 10, "b_khz": 125.0, "ldro": False},
    {"sf": 12, "b_khz": 250.0, "ldro": True},
]
DEFAULT_SCENARIOS = {
    "f_c_mhz": _MISSION_SWEEP_SCENARIOS,   # Fig. 3
    "h_km": _MISSION_SWEEP_SCENARIOS,      # Fig. 4
    "p_l": _MISSION_SWEEP_SCENARIOS,       # Fig. 5
    "sf": [                                # Fig. 6
        {"sf": DEF_SF, "b_khz": b, "ldro": ldro}
        for b in (62.5, 125.0) for ldro in (False, True)
    ],
    "b_khz": [                             # Fig. 7
        {"sf": sf, "b_khz": DEF_B_KHZ, "ldro": ldro}
        for sf in (8, 10, 12) for ldro in (False, True)
    ],
}

# Line colors of the MATLAB figures in scripts/, for figure parity with
# the paper. C_BLUE / C_ORANGE / C_GREEN are the sweep-script palette.
C_BLUE = "#0072BD"      # [0.00 0.45 0.74]
C_ORANGE = "#D95319"    # [0.85 0.33 0.10]
C_GREEN = "#77AC30"     # [0.47 0.67 0.19]
C_GRAY = "#808080"      # [0.50 0.50 0.50], sensitivity line
C_PLINK = "#05CFE6"     # [5 207 230]/256, P_link
C_PSUCCESS = "#30961A"  # [48 150 26]/256, P_success
# Sweep scenario colors: the scripts' three, then MATLAB's remaining
# default line colors
SWEEP_PALETTE = [C_BLUE, C_ORANGE, C_GREEN,
                 "#7E2F8E", "#EDB120", "#4DBEEE", "#A2142F"]

# MATLAB's axes appearance as exported for the paper: white canvas, only
# the left and bottom axes (the scripts call `hold on` before plotting,
# which leaves Box off), inward ticks, a light solid grid under the data,
# limits rounded out to the nearest ticks, square-cornered legend box.
plt.rcParams.update({
    "figure.facecolor": "white",
    "savefig.facecolor": "white",
    "axes.facecolor": "white",
    "axes.edgecolor": "#262626",
    "axes.labelcolor": "#262626",
    "axes.linewidth": 0.5,
    "axes.axisbelow": True,
    "axes.grid": True,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.autolimit_mode": "round_numbers",
    "axes.xmargin": 0,
    "axes.ymargin": 0,
    "grid.color": "#262626",
    "grid.alpha": 0.15,
    "grid.linewidth": 0.5,
    "grid.linestyle": "-",
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.color": "#262626",
    "ytick.color": "#262626",
    "font.family": ["Helvetica", "Arial", "DejaVu Sans"],
    "font.size": 10,
    "axes.labelsize": 11,   # MATLAB LabelFontSizeMultiplier = 1.1
    "legend.fontsize": 10,
    "legend.edgecolor": "#262626",
    "legend.framealpha": 1.0,
    "legend.fancybox": False,
    "legend.borderpad": 0.4,
    "axes.unicode_minus": False,   # MATLAB tick labels use a plain hyphen
})

# Aspect ratio of the paper's exported figures (figures/*_fix.png, about
# 1.56:1). The single-figure size also matches their text-to-plot scale.
FIGSIZE = (7.0, 4.5)        # parameter sweep
FIGSIZE_PANEL = (6.2, 3.98) # single-pass panels, 2 x 2 grid
FIGSIZE_DS = (7.0, 4.4)     # design space, legend outside

# Displayed width in CSS pixels. Fixed rather than stretched to the
# column, so the figures stay legible instead of growing with the window.
# About 100 px per figure inch, so text is the same size on every tab.
WIDTH_WIDE = 700
WIDTH_PANEL = 620
WIDTH_LEGEND = 760


def new_axes(figsize=FIGSIZE):
    """Figure and axes with MATLAB's tick density and labels: about ten
    intervals per linear axis (e.g. PDR every 10%), so the grid has as many
    lines as in the paper, and labels without trailing zeros ("0", "0.2",
    "1"). Log scales and explicit ticks set afterwards override it."""
    fig, ax = plt.subplots(figsize=figsize)
    for axis in (ax.xaxis, ax.yaxis):
        axis.set_major_locator(MaxNLocator(nbins=10, steps=[1, 2, 5, 10]))
        axis.set_major_formatter(StrMethodFormatter("{x:g}"))
    return fig, ax


def right_axis(ax, color):
    """Second y axis on the right, like MATLAB's yyaxis: its own spine and
    colored ticks, the same tick density, and the grid left to the left
    axis only."""
    ax_r = ax.twinx()
    ax_r.spines["right"].set_visible(True)
    ax_r.yaxis.set_major_locator(MaxNLocator(nbins=10, steps=[1, 2, 5, 10]))
    ax_r.yaxis.set_major_formatter(StrMethodFormatter("{x:g}"))
    ax_r.tick_params(axis="y", colors=color, direction="in")
    ax_r.grid(False)
    return ax_r


def show_fig(fig, container=None, width=WIDTH_WIDE, caption=None):
    """Render fig at a fixed display width, with an optional caption (HTML)
    beneath it at the same width. Embedded as an <img> rather than
    st.image, which would downsample it to that width on the server; this
    way the 200 dpi render stays sharp on high-density screens."""
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=200)
    plt.close(fig)
    data = base64.b64encode(buf.getvalue()).decode()
    html = (f'<img src="data:image/png;base64,{data}" '
            f'style="width:{width}px; max-width:100%">')
    if caption:
        html += (f'<div style="max-width:{width}px; font-size:0.875rem; '
                 f'color:rgba(49,51,63,0.7); margin-top:0.25rem">'
                 f'{caption}</div>')
    (container or st).markdown(html, unsafe_allow_html=True)


# Figure captions: the paper's wording, with the values shown filled in
_SYMBOLS = {"f_c_mhz": "<i>F</i><sub><i>C</i></sub>", "h_km": "<i>h</i>",
            "p_l": "PL", "sf": "SF", "b_khz": "<i>B</i>",
            "p_tx_dbm": "<i>P</i><sub>Tx</sub>",
            "g_t": "<i>G</i><sub>Tx</sub>", "g_r": "<i>G</i><sub>Rx</sub>"}
_UNITS = {"f_c_mhz": " MHz", "h_km": " km", "p_l": " bytes",
          "sf": "", "b_khz": " kHz",
          "p_tx_dbm": " dBm", "g_t": " dBi", "g_r": " dBi"}


def caption_values(p, keys, extra=()):
    """'F_C = 915 MHz, h = 1000 km, and PL = 100 bytes' for the given keys
    (plus any extra items), joined as in the paper's captions."""
    items = [f"{_SYMBOLS[k]} = {p[k]:g}{_UNITS[k]}" for k in keys]
    items += list(extra)
    if len(items) <= 2:
        return " and ".join(items)
    return ", ".join(items[:-1]) + ", and " + items[-1]

PARAM_LABELS = {
    "f_c_mhz": "Carrier frequency (MHz)",
    "h_km": "Altitude (km)",
    "p_l": "Payload length (bytes)",
    "sf": "Spreading factor",
    "b_khz": "Bandwidth (kHz)",
    "ldro": "LDRO",
}

# Input widget labels, led by the paper's symbol for each parameter (widget
# labels render LaTeX; PARAM_LABELS stays plain for the sweep dropdown,
# whose options cannot)
WIDGET_LABELS = {
    "f_c_mhz": "$F_C$, Carrier frequency (MHz)",
    "h_km": "$h$, Altitude (km)",
    "p_l": "PL, Payload length (bytes)",
    "sf": "SF, Spreading factor",
    "b_khz": "$B$, Bandwidth (kHz)",
    "p_tx_dbm": r"$P_\mathrm{Tx}$, Tx power (dBm)",
    "g_t": r"$G_\mathrm{Tx}$, Tx antenna gain (dBi)",
    "g_r": r"$G_\mathrm{Rx}$, Rx antenna gain (dBi)",
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
def run_pass(f_c_mhz, h_km, p_l, sf, b_khz, ldro, p_tx_dbm, g_t, g_r):
    return packet_delivery_ratio(
        E_MIN, b_khz, f_c_mhz, int(ldro), sf, p_l, h_km,
        p_tx_dbm=p_tx_dbm, g_t=g_t, g_r=g_r,
    )


def link_inputs(tab, container):
    """Render the link budget widgets into container; returns {name: value}."""
    c1, c2, c3 = container.columns(3)
    return {
        "p_tx_dbm": c1.selectbox(
            WIDGET_LABELS["p_tx_dbm"], P_TX_DBM,
            index=P_TX_DBM.index(DEF_P_TX_DBM), key=f"{tab}_p_tx"),
        "g_t": c2.number_input(
            WIDGET_LABELS["g_t"], min_value=-10.0, max_value=30.0,
            value=DEF_G_DBI, step=0.5, format="%.1f", key=f"{tab}_g_t"),
        "g_r": c3.number_input(
            WIDGET_LABELS["g_r"], min_value=-10.0, max_value=30.0,
            value=DEF_G_DBI, step=0.5, format="%.1f", key=f"{tab}_g_r"),
    }


def param_inputs(tab, exclude=(), lora=True):
    """Render the model parameter widgets; returns {name: value}.

    Excluded parameters' slots are left empty; with lora=False the LoRa
    set is omitted and the link budget set takes its place.
    """
    vals = {}
    scenario_col, lora_col = st.columns(2, gap="large")

    with scenario_col:
        c1, c2, c3 = st.columns(3)
        if "f_c_mhz" not in exclude:
            vals["f_c_mhz"] = c1.number_input(
                WIDGET_LABELS["f_c_mhz"], min_value=100.0, max_value=3000.0,
                value=DEF_F_C_MHZ, step=1.0, key=f"{tab}_f_c")
        if "h_km" not in exclude:
            vals["h_km"] = c2.number_input(
                WIDGET_LABELS["h_km"], min_value=300, max_value=2500,
                value=DEF_H_KM, step=10, key=f"{tab}_h")
        if "p_l" not in exclude:
            vals["p_l"] = c3.number_input(
                WIDGET_LABELS["p_l"], min_value=1, max_value=255,
                value=DEF_P_L, step=1, key=f"{tab}_p_l")

    if lora:
        with lora_col:
            c4, c5, c6 = st.columns(3)
            if "sf" not in exclude:
                vals["sf"] = c4.selectbox(
                    WIDGET_LABELS["sf"], SF_VALUES,
                    index=SF_VALUES.index(DEF_SF), key=f"{tab}_sf")
            if "b_khz" not in exclude:
                vals["b_khz"] = c5.selectbox(
                    WIDGET_LABELS["b_khz"], BW_KHZ,
                    index=BW_KHZ.index(DEF_B_KHZ), key=f"{tab}_b")
            if "ldro" not in exclude:
                # Label above the switch, matching the other widgets
                c6.markdown(
                    f'<p style="font-size:14px; margin-bottom:0.25rem">'
                    f'{PARAM_LABELS["ldro"]}</p>',
                    unsafe_allow_html=True)
                vals["ldro"] = c6.toggle(
                    PARAM_LABELS["ldro"], value=False, key=f"{tab}_ldro",
                    label_visibility="collapsed")
        # Link budget on a second row, under the mission parameters
        vals.update(link_inputs(tab, st.columns(2, gap="large")[0]))
    else:
        vals.update(link_inputs(tab, lora_col))

    return vals


def tab_key(tab):
    """Widget key prefix for a tab's inputs. It carries a version number
    that Reset bumps, so the tab's widgets are rebuilt at their defaults
    (deleting widget state alone leaves the old value displayed)."""
    return f"{tab}{st.session_state.get(f'ver_{tab}', 0)}"


def reset_button(tab, on_reset=None):
    """Reset button that reverts the tab's inputs to the paper baseline."""
    def reset():
        st.session_state[f"ver_{tab}"] = st.session_state.get(f"ver_{tab}", 0) + 1
        if on_reset:
            on_reset()

    st.button("Reset", key=f"reset_{tab}", on_click=reset,
              help="Revert to the paper's baseline scenario")


tab_single, tab_sweep, tab_ds = st.tabs(
    ["Single-pass analysis", "Parameter sweep", "Design space exploration"]
)

# --------------------------------------------------------------- Tab 1
with tab_single:
    reset_button("single")
    p = param_inputs(tab_key("single"))
    res = run_pass(**p)
    p_success = ~res.l_static * ~res.l_dynamic * res.p_link
    t = res.time_s

    m1, m2 = st.columns(2)
    m1.metric("PDR", f"{res.pdr * 100:.1f} %")
    m2.metric("Data rate", f"{bit_rate_bps(p['sf'], p['b_khz'], p['ldro']):.0f} bps")

    # 2 x 2 grid: reception probability and link margin on top, pass
    # geometry and Doppler below
    c_plot1, c_plot2 = st.columns(2)
    c_plot3, c_plot4 = st.columns(2)

    # Panel 1: reception probability (scripts/pdr_three_failure_modes.m).
    # The Doppler markers are only drawn — and only appear in the legend —
    # when that failure mode actually fires, as in the MATLAB script.
    # No xlim in the scripts: MATLAB rounds the limits out to the ticks.
    fig1, ax = new_axes(FIGSIZE_PANEL)
    # Upright symbols, as MATLAB's TeX interpreter renders P_{link}
    ax.plot(t, res.p_link, "-", color=C_PLINK, lw=1.3,
            label=r"$\mathrm{P_{link}}$")
    ax.plot(t, p_success, "-", color=C_PSUCCESS, lw=2.3,
            label=r"$\mathrm{P_{success}}$")
    if res.l_static.any():
        ax.plot(t[res.l_static], np.zeros(res.l_static.sum()), ".",
                color=C_BLUE, ms=6, ls="none",
                label=r"$\mathrm{L_{static}}$ = true")
    if res.l_dynamic.any():
        ax.plot(t[res.l_dynamic], np.zeros(res.l_dynamic.sum()), ".",
                color=C_ORANGE, ms=6, ls="none",
                label=r"$\mathrm{L_{dynamic}}$ = true")
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Packet reception probability")
    ax.set_ylim(-0.05, 1.05)
    ax.legend(loc="upper right")
    fig1.tight_layout()
    show_fig(fig1, c_plot1, WIDTH_PANEL, caption=(
        "Packet reception probability and failure modes for a full "
        "satellite pass at "
        + caption_values(p, ["f_c_mhz", "h_km", "p_l", "sf", "b_khz"],
                         extra=[f"LDRO = {'on' if p['ldro'] else 'off'}"])
        + "."))

    # Panel 2: link margin, with the dashed sensitivity line at 0 dB
    fig2, ax = new_axes(FIGSIZE_PANEL)
    ax.plot(t, res.link_margin_db, "-", color=C_BLUE, lw=1.5)
    ax.axhline(0, ls="--", color=C_GRAY, lw=1.0)
    # yline's default label placement: right end, above the line
    ax.text(1, 0, "sensitivity ", color=C_GRAY, fontsize=9, ha="right",
            va="bottom", transform=ax.get_yaxis_transform())
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Link margin (dB)")
    fig2.tight_layout()
    # Not paper figures: short captions in the same style. The link budget
    # values are stated here, as the Fig. 2 caption (like the paper's) omits them.
    show_fig(fig2, c_plot2, WIDTH_PANEL, caption=(
        "Link margin above receiver sensitivity for the same pass, with "
        + caption_values(p, ["p_tx_dbm", "g_t", "g_r"]) + "."))

    # Panel 3: pass geometry — elevation with the Rician K factor it drives
    fig3, ax = new_axes(FIGSIZE_PANEL)
    ax.plot(t, res.elevation_deg, "-", color=C_BLUE, lw=1.5)
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Elevation (deg)", color=C_BLUE)
    ax.tick_params(axis="y", colors=C_BLUE)
    ax.set_ylim(0, 90)
    ax_k = right_axis(ax, C_ORANGE)
    ax_k.plot(t, rician_k(res.elevation_deg), "-", color=C_ORANGE, lw=1.5)
    ax_k.set_ylabel("Rician K factor", color=C_ORANGE)
    fig3.tight_layout()
    show_fig(fig3, c_plot3, WIDTH_PANEL, caption=(
        "Satellite elevation angle and the resulting Rician <i>K</i> factor "
        "over the same pass at " + caption_values(p, ["h_km"]) + "."))

    # Panel 4: Doppler shift and its rate, which drive the static and
    # dynamic Doppler failures
    fig4, ax = new_axes(FIGSIZE_PANEL)
    ax.plot(t, res.doppler_shift_hz / 1e3, "-", color=C_BLUE, lw=1.5)
    ax.set_xlabel("Time (s)\nZenith = 0")
    ax.set_ylabel("Doppler shift (kHz)", color=C_BLUE)
    ax.tick_params(axis="y", colors=C_BLUE)
    ax_r = right_axis(ax, C_ORANGE)
    ax_r.plot(t, res.doppler_rate_hz_s, "-", color=C_ORANGE, lw=1.5)
    ax_r.set_ylabel("Doppler rate (Hz/s)", color=C_ORANGE)
    fig4.tight_layout()
    show_fig(fig4, c_plot4, WIDTH_PANEL, caption=(
        "Doppler shift and Doppler rate over the same pass at "
        + caption_values(p, ["f_c_mhz", "h_km"]) + "."))

# --------------------------------------------------------------- Tab 2
with tab_sweep:
    N_SWEEP = 15

    # Reset keeps the chosen sweep parameter, but restores the sweep range,
    # the shared inputs and the scenario list, which is rebuilt from the
    # figure's defaults once "scen_for" is gone
    reset_button("sweep", on_reset=lambda: st.session_state.pop("scen_for", None))
    tk = tab_key("sweep")
    c_sel, c_min, c_max = st.columns([2, 1, 1])
    sweep_key = c_sel.selectbox(
        "Parameter to sweep", [k for k in PARAM_LABELS if k != "ldro"],
        format_func=PARAM_LABELS.get, key="sweep_param")

    # Sweep grid: min/max inputs for the continuous parameters, the full
    # discrete grid otherwise.
    # Default ranges are those swept in figures 3 to 5 of the paper
    if sweep_key == "f_c_mhz":
        lo = c_min.number_input("Min", 100.0, 3000.0, 433.0, key=f"{tk}_lo_f")
        hi = c_max.number_input("Max", 100.0, 3000.0, 2400.0, key=f"{tk}_hi_f")
        sweep_vals = list(np.linspace(lo, hi, N_SWEEP))
    elif sweep_key == "h_km":
        lo = c_min.number_input("Min", 300, 2500, 300, key=f"{tk}_lo_h")
        hi = c_max.number_input("Max", 300, 2500, 2000, key=f"{tk}_hi_h")
        sweep_vals = list(np.linspace(lo, hi, N_SWEEP))
    elif sweep_key == "p_l":
        lo = c_min.number_input("Min", 1, 255, 10, key=f"{tk}_lo_p")
        hi = c_max.number_input("Max", 1, 255, 200, key=f"{tk}_hi_p")
        sweep_vals = sorted(set(
            int(v) for v in np.linspace(lo, hi, N_SWEEP).round()))
    elif sweep_key == "sf":
        sweep_vals = SF_VALUES
    else:  # b_khz
        sweep_vals = BW_KHZ

    # Mission and link budget parameters are shared by all scenarios
    p = param_inputs(tk, exclude=(sweep_key,), lora=False)

    # Scenario list, one line each, varying the LoRa parameters. It resets
    # to the matching paper figure's scenarios whenever the swept parameter
    # changes. Ids are never reused, so each scenario's widget state stays
    # with it when another one is removed.
    ss = st.session_state
    if ss.get("scen_for") != sweep_key:
        ss.scen_next = ss.get("scen_next", 0)
        ss.scen = []
        for s in DEFAULT_SCENARIOS[sweep_key]:
            ss.scen.append({**s, "id": ss.scen_next})
            ss.scen_next += 1
        ss.scen_for = sweep_key

    def add_scenario():
        ss.scen.append({**ss.scen[-1], "id": ss.scen_next})
        ss.scen_next += 1

    def remove_scenario(sid):
        ss.scen = [s for s in ss.scen if s["id"] != sid]

    lora_fields = [k for k in ("sf", "b_khz") if k != sweep_key]
    c_scen, c_plot = st.columns(2, gap="large")
    with c_scen:
        for i, s in enumerate(ss.scen):
            first = i == 0
            vis = "visible" if first else "collapsed"
            cols = st.columns([2] * len(lora_fields) + [1, 0.8],
                              vertical_alignment="bottom")
            for col, k in zip(cols, lora_fields):
                options = SF_VALUES if k == "sf" else BW_KHZ
                s[k] = col.selectbox(
                    WIDGET_LABELS[k], options, index=options.index(s[k]),
                    key=f"sc{s['id']}_{k}", label_visibility=vis)
            c_ldro, c_rm = cols[-2:]
            if first:
                c_ldro.markdown(
                    f'<p style="font-size:14px; margin-bottom:0.25rem">'
                    f'{PARAM_LABELS["ldro"]}</p>',
                    unsafe_allow_html=True)
            s["ldro"] = c_ldro.toggle(
                PARAM_LABELS["ldro"], value=s["ldro"],
                key=f"sc{s['id']}_ldro", label_visibility="collapsed")
            if not first:
                c_rm.button("✕", key=f"sc{s['id']}_rm", help="Remove scenario",
                            on_click=remove_scenario, args=(s["id"],))
        st.button("+", help="Add scenario", on_click=add_scenario)

    curves = []
    with st.spinner("Sweeping..."):
        for s in ss.scen:
            sp = {k: s[k] for k in ("sf", "b_khz", "ldro") if k != sweep_key}
            curves.append([run_pass(**p, **sp, **{sweep_key: v}).pdr * 100
                           for v in sweep_vals])

    # Styled as in sweep_pdr_vs_*.m: one color per (SF, B) combination, and
    # a dashed line for LDRO on when the same combination also appears with
    # LDRO off (Figs. 6 and 7), solid otherwise (Figs. 3 to 5).
    def lora_key(s):
        return tuple(s[k] for k in lora_fields)

    groups = list(dict.fromkeys(lora_key(s) for s in ss.scen))
    fig, ax = new_axes()
    for s, pdr in zip(ss.scen, curves):
        color = SWEEP_PALETTE[groups.index(lora_key(s)) % len(SWEEP_PALETTE)]
        has_off_twin = s["ldro"] and any(
            not o["ldro"] and lora_key(o) == lora_key(s) for o in ss.scen)
        label = [f"SF={s['sf']}"] if "sf" in lora_fields else []
        label += [f"B={s['b_khz']:g} kHz"] if "b_khz" in lora_fields else []
        label += ["LDRO on" if s["ldro"] else "LDRO off"]
        ax.plot(sweep_vals, pdr, "--" if has_off_twin else "-", marker="o",
                color=color, mfc=color, lw=1.6, ms=5, label=", ".join(label))
    if sweep_key == "b_khz":
        ax.set_xscale("log")
        # Ticks on the bandwidth values themselves, as in sweep_pdr_vs_bw.m
        ax.set_xticks(sweep_vals, [f"{b:g}" for b in sweep_vals])
        ax.minorticks_off()
    elif sweep_key == "sf":
        ax.set_xticks(sweep_vals)
    ax.set_xlabel(AXIS_LABELS[sweep_key])
    ax.set_ylabel("PDR (%)")
    ax.set_xlim(min(sweep_vals), max(sweep_vals))
    ax.set_ylim(0, 100)
    ax.legend(loc=LEGEND_LOC[sweep_key])
    fig.tight_layout()

    # Caption as in Figs. 3 to 7. Scenarios are counted as the paper does:
    # per distinct bandwidth (Fig. 6) or SF (Fig. 7) when LDRO pairs share
    # a color, per scenario otherwise.
    def count(n, noun):
        return f"{n} {noun}{'s' if n != 1 else ''}"

    if sweep_key == "sf":
        subject = "spreading factor and LDRO settings"
        scen = count(len({s["b_khz"] for s in ss.scen}), "bandwidth scenario")
    elif sweep_key == "b_khz":
        subject = "bandwidth and LDRO settings"
        scen = count(len({s["sf"] for s in ss.scen}), "spreading factor scenario")
    else:
        subject = {"f_c_mhz": "carrier frequency",
                   "h_km": "satellite orbital altitude",
                   "p_l": "application payload size"}[sweep_key]
        scen = count(len(ss.scen), "modulation parameter scenario")
    at = {"f_c_mhz": ["p_l", "h_km"], "h_km": ["f_c_mhz", "p_l"],
          "p_l": ["f_c_mhz", "h_km"]}.get(sweep_key, ["f_c_mhz", "h_km", "p_l"])
    show_fig(fig, c_plot, caption=(
        f"Impact of {subject} on PDR for {scen} at {caption_values(p, at)}."))

# --------------------------------------------------------------- Tab 3
with tab_ds:
    reset_button("ds")
    p = param_inputs(tab_key("ds"), lora=False)

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

    fig, ax = new_axes(FIGSIZE_DS)
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
    # MATLAB draws dotted minor grid lines between the decades of this log
    # axis (MinorGridLineStyle ':', MinorGridAlpha 0.25)
    ax.grid(True, which="minor", axis="x", linestyle=":", alpha=0.25)
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
              bbox_to_anchor=(1.02, 0.5))
    fig.tight_layout()
    show_fig(fig, width=WIDTH_LEGEND, caption=(
        "Bi-objective design space of LoRa modulation parameters at "
        + caption_values(p, ["f_c_mhz", "h_km", "p_l"]) + "."))
