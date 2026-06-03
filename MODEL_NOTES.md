# Model notes

List of model assumptions, deviations from the reference papers, and things worth adding later.

## References

[1]: Asad Ullah, M., Pasolini, G., Mikhaylov, K., & Alves, H. (2024). *Understanding the Limits of LoRa Direct-to-Satellite: The Doppler Perspectives.* IEEE Open Journal of the Communications Society, 5, 51-63.

[2]: Kim, J., Yang, C.-Y., & Jang, J. S. (2006). *Performance Analysis of Low-Earth-Orbit (LEO) Mobile-Satellite System Using Moment-Based Approximation of Degradation Factors.* IEEE Transactions on Vehicular Technology, 55(3), 876-886.

[3]: Asad Ullah, M., Mikhaylov, K., & Alves, H. (2022). *Enabling mMTC in Remote Areas: LoRaWAN and LEO Satellite Integration for Offshore Wind Farm Monitoring.* IEEE Transactions on Industrial Informatics, 18(6), 3744-3753.

Reference [1]'s published code is in [Bandwidth_LoRa_Dopper_effect.m](Bandwidth_LoRa_Dopper_effect.m) and [LoRa_ToA_paper.m](LoRa_ToA_paper.m). Reference [3]'s `Probability_SNR.m` Monte-Carlo SNR-success implementation is in [Probability_SNR.m](Probability_SNR.m).

## Modelling assumptions

- **Direct overhead pass.** Satellite reaches `E = 90°` at zenith (`t = 0`). Symmetric pass from `-tau/2` to `+tau/2`.
- **Packet success is the product of two independent gates.** Per packet: `P_success = (1 - L_static)·(1 - L_dynamic)·P_link`, where `L_static`/`L_dynamic` are binary Doppler-failure indicators ([1] eq. 12, 13) and `P_link` is the link-budget success probability accounting for fading and shadowing. PDR is the mean of `P_success` over all packets in the pass.
- **Doppler thresholds from SX1276/77/78/79 datasheet.** Static: `±0.25·B`. Dynamic: `L·B / (3·2^SF)` with `L = 16` for LDRO on, `L = 1` for LDRO off. The dynamic threshold is on the *integrated drift* `ΔF_E = F_D[t_start] − F_D[t_end]` in Hz, not on the instantaneous Doppler rate. Equivalently, expressed as a rate threshold: `|dF_D/dt| ≥ F_dynamic / ToA → fail`. The two forms agree when the Doppler rate is constant over the packet; we use the exact integrated drift, which is correct even when the rate is changing. The rate-threshold form is the right intuition for understanding LDRO's value at high carrier frequencies — LDRO multiplies the tolerable rate by 16×.
- **Link budget: Friis free-space path loss.** `PL(d) = (4π·d·F_C/c)²` (linear). Path loss exponent fixed at η = 2; matches [3]'s direct-architecture assumption and is appropriate for DtS links where the satellite altitude makes the link essentially obstruction-free. If terrestrial / NLOS scenarios ever need supporting, generalize to log-distance path loss with `d_0` reference and configurable η.
- **Receiver sensitivity / SNR thresholds from Semtech SX127x datasheet.** `D_SNR_dB(SF) = -2.5·(SF - 4)` for SF 5-12, giving [-2.5, -5, -7.5, -10, -12.5, -15, -17.5, -20] dB. Overridable via `opts.D_SNR_dB`.
- **Noise floor:** `σ_w² = -174 dBm + NF + 10·log10(B)`. Receiver noise figure `NF = 6 dB` per [1] Section IV-D.
- **Rician fading, Monte Carlo evaluation.** Per packet, `N_MC = 10⁵` samples of `|h|²` (Rician, elevation-dependent K from [rician_K.m](rician_K.m)) and `X_g` (log-normal shadowing, σ = 0.1 dB per [3] Table II) are drawn; `P_link` is the fraction of samples whose instantaneous SNR exceeds `D_SNR`. Implemented in [link_success_prob.m](link_success_prob.m). Closed-form alternative (Marcum Q + Gauss-Hermite) noted under *Optional future additions*.
- **Channel timescale: block fading at the packet level.** Each packet sees a single independent draw of `(|h|², X_g)` for the Monte Carlo. This implicitly assumes the channel is constant over the packet duration ("block fading"). For LoRa DtS at 915 MHz with v ≈ 7 km/s, the Doppler-induced multipath coherence time is ~50 µs — *shorter* than a LoRa symbol (T_s ≈ 8 ms at SF=10, B=125 kHz). In reality each symbol therefore averages over many independent multipath realizations, so the symbol SNR is closer to its mean than the block-fading model predicts. Net effect: our `P_link` curve has more spread than physically correct, biasing PDR estimates **conservative** at borderline link margins (margin within a few dB of 0). At high or low margin the bias is negligible because `P_link` saturates anyway. Shadowing IS appropriately treated as block-faded — terrain/obstruction coherence is seconds to minutes, much longer than a packet. The conservative bias is the safe direction for a design tool; a fast-fading variant of the link model is noted as an optional future refinement.
- **Default antenna gains and transmit power:** `G_t = G_r = 3 dBi`, `P_tx = 22 dBm` (EU 868 MHz LoRaWAN max). Override via opts.
- **LoRa frame defaults** (in [lora_toa.m](lora_toa.m), matching the paper):
  - Preamble length: 8 symbols
  - Header: explicit
  - CRC: on
  - Coding rate: 4/5
  - MAC overhead: 5 bytes added internally to the application payload
- **Constants:** R = 6371 km, g = 9.80665 m/s², c = 299792458 m/s.
- **Default R_p = 5 s** (packet reporting period, following [1] Table 4).
- **Default E_min = 1°** when called with `E = 1`.
- **Rician K-factor: elevation-dependent.** Cubic spline through Kim [2] Table II measured K values at E ∈ {20°, 30°, 40°, 60°, 80°} (3.07, 3.24, 3.60, 5.63, 17.06). Implemented in [rician_K.m](rician_K.m), validated by [tests/rician_K_test.m](tests/rician_K_test.m). Behaviour outside the data range:
  - **Above 80°**: cubic spline extrapolates upward (29.4 at 90°), reflecting expected K growth toward zenith.
  - **Below 20°**: clamped to K(20°) = 3.07 (flat floor). The unclamped spline curves *upward* below 20° (K(10°) = 3.44, K(1°) = 4.52) due to its curvature at the data point — extrapolation artifact, not signal. Flooring suppresses this. The floor overestimates K at low elevations relative to the physical truth (LOS power → 0 at the horizon), but this overestimate is masked in practice by static Doppler dominating packet failures at low elevations; the link budget rarely decides those packets' fate. Method comparison performed in [scripts/k_fit_comparison.m](scripts/k_fit_comparison.m).

## Deviations from references

| Item | Paper | Ours | Reason |
|---|---|---|---|
| τ formula ([1] eq. 4) | `2·d_g(E_min)/v` | `2·(R+H)·α/v` | Paper's formula misses `(R+H)/R` factor — the sub-satellite point moves at `R·v/(R+H)`, not `v`. Ours matches paper's own TLE access window (708 s for H=560) within 1 s; paper's formula gives 651 s. See [pass_duration.m](pass_duration.m) header. Verified by [tests/tau_test.m](tests/tau_test.m). |
| Preamble constant | 4.24 | 4.25 | Paper's `LoRa_ToA.m` has a typo (datasheet is 4.25). Ours matches Semtech calculator. |
| `n_payload` parenthesis | `ceil(... * (CR+4))` | `ceil(...) * (CR+4)` | Paper had `ceil` wrapping the whole expression including the `*(CR+4)` factor; datasheet applies ceil only to the division. ToA off otherwise. |
| Fig. 9 caption τ values | 788, 935, 1113 s for H = 560, 750, 1000 | 709, 850, 1022 s | Paper's quoted values match neither their own eq. (4) nor a corrected geometric formula. Likely a transcription error in the figure caption. |
| Kim [2] eq. (28) cubic fit | `K = 0.0002·E³ - 0.0157·E² + 0.5430·E - 2.7618` | Direct cubic spline through Kim's Table II measured points | The published cubic fit substantially disagrees with the paper's own Table II measurements at high elevations: eq. (28) gives K(80°) = 42.60 while Table II measures K(80°) = 17.06. The proper least-squares cubic on the table data (computed via `polyfit` in [scripts/k_fit_comparison.m](scripts/k_fit_comparison.m)) yields `K ≈ 0.0001505·E³ - 0.01573·E² + 0.543·E - 2.762`, identical to eq. (28) except the leading coefficient — printed as 0.0002 but should be ~0.00015. The difference looks tiny but is amplified ~33% by the E³ term, producing the 25-unit discrepancy at E=80°. Appears to be a typographical rounding error in the published formula. We bypass the formula entirely and interpolate the measured points directly. The [3] paper (a downstream citer of [2]) implicitly catches this by using linear interpolation of the table values rather than the published formula, but doesn't say so in print. |

## Known residual gap

After the τ and `n_payload` fixes, our Fig. 8 and Fig. 10 reproductions still sit **~2% lower in PDR than [1]'s published curves** for all non-0%/100% PDR sweeps.

Possible causes:
 
1. **Sampling phase relative to zenith.** Our packets land ~0.5 s from zenith; the paper's land ~2 s from zenith. Near the sharp Doppler-rate peak, this can flip 1-2 packets at the failure-region edge.
2. **Interpolation smoothing.** The paper interpolates `F_D` linearly from 1 Hz satellite-state samples to 1 ms resolution. Linear interpolation slightly understates curvature near the rate peak, so a packet or two at the boundary that fails for us may pass for them.
3. **Paper's `lost_packets = unique([..., L_joint_index])` quirk.** `L_joint_index` is a logical array being concatenated with index lists, introducing spurious 0/1 entries via `unique`. Direction of effect uncertain, magnitude small.

Closing this residual would require reproducing the paper's exact interp1 + ms-index pipeline, which adds complexity without affecting the underlying physics. Accepted as validation noise.

## Optional future additions

- **Visibility-failure check.** A packet whose end (`t + ToA`) extends past `tau/2` is physically lost — the satellite sets mid-transmission. The paper excludes such packets entirely; we currently let them through and the analytical `Dopplershift` extension typically marks them as successes. Effect: <1% PDR reduction (only the very last packet per pass, when it exists). Worth adding for physical accuracy when the model gets more realistic, especially at higher SF / lower bandwidth where ToA approaches R_p. Note: this *widens* the gap to the paper.
- **Closed-form fading outage via Marcum Q + Gauss-Hermite.** For Rician fading alone, the per-packet success probability is `P_link = Q_1(√(2K), √(2(K+1)·D_SNR/SNR_mean))`, where `Q_1` is the first-order Marcum Q function (MATLAB: `marcumq`, Communications Toolbox). With log-normal shadowing layered on top, this becomes a 1D Gaussian integral solved by 7-point Gauss-Hermite quadrature over the shadowing distribution. Deterministic, exact (to floating-point), and ~10⁵× faster than Monte Carlo at equivalent accuracy. The current implementation uses Monte Carlo instead (easier to explain, easier to validate against [1]'s `Probability_SNR.m`, naturally extends to additional random effects). Worth switching to closed form only if dense parameter sweeps (heatmaps, optimization) make MC's ~0.3% sampling noise at N=10⁵ the limiting factor.
- **Fast-fading multipath model.** Replace the block-fading `P_link = mean(SNR_inst ≥ D_SNR)` with the fast-fading limit where the receiver averages the channel over each symbol's many independent coherence intervals. In the limit, the effective per-packet SNR converges to its mean and `P_link` becomes a sharper threshold around `SNR_mean = D_SNR` (the only remaining randomness is shadowing, which IS block-faded correctly). The current model is conservative relative to this; switching would shift the design-space heatmaps so the "borderline" band narrows. Worth adding once we want to claim physical-fidelity rather than design-tool conservatism.
- **TLE-based pass geometry.** Optional alternative to the analytical `pass_duration` + `Dopplershift` chain. Useful for reproducing specific real satellite scenarios (e.g. Norby). Would slot in as an alternate provider of the Doppler trace; the loss-decision loop stays unchanged.
- **Doppler-aware ADR.** Adaptive Data Rate that selects SF based on predicted Doppler conditions during the pass.
- **Off-zenith passes.** Real satellite passes rarely peak at exactly 90°. The current geometry assumes they do.

## Verification baseline

| Check | Status | Test |
|---|---|---|
| ToA matches Semtech LoRa Calculator | ✓ (within 0.05 ms) | manually verified |
| ToA matches paper's published values | ✓ (within ~1.5 ms, typo accounts for rest) | [tests/toa_test.m](tests/toa_test.m) |
| τ matches paper's TLE access window for Norby (H=560) | ✓ (within 1 s) | [tests/tau_test.m](tests/tau_test.m) |
| PDR (Fig. 8, Fig. 10) matches paper's published curves | ✓ pre-link-budget (within ~2%, all non-trivial sweeps). Now that link budget is in the loop, the curves may diverge further; that's an expected consequence of adding model physics not present in [1] (which is Doppler-only), not a regression. Re-baseline after the link-budget integration lands. | manually verified via [scripts/figure8.m](scripts/figure8.m), [scripts/figure10.m](scripts/figure10.m), plus `*_diag.m` for failure-type decomposition |
| `rician_K(E)` reproduces Kim [2] Table II at the data points and behaves as designed at extrapolation boundaries | ✓ | [tests/rician_K_test.m](tests/rician_K_test.m) |
| `link_success_prob` matches closed-form limits (Rayleigh, deterministic, Rician/Marcum Q) and is reproducible under fixed RNG seed | ✓ (within MC sampling noise) | [tests/link_success_prob_test.m](tests/link_success_prob_test.m) |
| End-to-end PDR is reproducible and stable for two reference scenarios (comfortable + stressed link budgets) | ✓ (locked-in regression values under `rng(0)`, AbsTol 1e-4) | [tests/pdr_test.m](tests/pdr_test.m) |
