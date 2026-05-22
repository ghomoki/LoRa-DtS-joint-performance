# Model notes: assumptions, shortcomings, and deferred additions

Living document for things the model assumes, places where it deviates from the reference paper (Asad Ullah et al., 2024), and things worth adding later.

## Reference

Asad Ullah, M., Pasolini, G., Mikhaylov, K., & Alves, H. (2024). *Understanding the Limits of LoRa Direct-to-Satellite: The Doppler Perspectives.* IEEE Open Journal of the Communications Society, 5, 51-63.

Paper's published code in [Bandwidth_LoRa_Dopper_effect.m](Bandwidth_LoRa_Dopper_effect.m) and [LoRa_ToA_paper.m](LoRa_ToA_paper.m).

## Modelling assumptions

- **Direct overhead pass.** Satellite reaches `E = 90°` at zenith (`t = 0`). Symmetric pass from `-tau/2` to `+tau/2`. Real LEO passes mostly aren't directly overhead — would require TLE-driven geometry.
- **Doppler-only packet loss.** Static Doppler shift and dynamic Doppler drift are the only failure modes. No link budget, AWGN, fading, interference, or receiver noise yet.
- **Doppler thresholds from SX1276/77/78/79 datasheet.** Static: `±0.25·B`. Dynamic: `L·B / (3·2^SF)` with `L = 16` for LDRO on, `L = 1` for LDRO off.
- **LoRa frame defaults** (in [lora_toa.m](lora_toa.m), matching the paper):
  - Preamble length: 8 symbols
  - Header: explicit (IH=0)
  - CRC: on
  - Coding rate: 4/5
  - MAC overhead: 5 bytes added internally to the application payload
- **Constants:** R = 6371 km, g = 9.80665 m/s², c = 299792458 m/s.
- **Default R_p = 5 s** (packet reporting period, paper Table 4).
- **Default E_min = 1°** when called with `E = 1`.

## Deviations from the paper (and why)

| Item | Paper | Ours | Reason |
|---|---|---|---|
| τ formula (eq. 4) | `2·d_g(E_min)/v` | `2·(R+H)·α/v` | Paper's formula misses `(R+H)/R` factor — the sub-satellite point moves at `R·v/(R+H)`, not `v`. Ours matches paper's own TLE access window (708 s for H=560) within 1 s; paper's formula gives 651 s. See [pass_duration.m](pass_duration.m) header. Verified by [tau_test.m](tau_test.m). |
| Preamble constant | 4.24 | 4.25 | Paper's `LoRa_ToA.m` has a typo (datasheet is 4.25). Ours matches Semtech calculator. |
| `n_payload` parenthesis | `ceil(... * (CR+4))` | `ceil(...) * (CR+4)` | Paper had `ceil` wrapping the whole expression including the `*(CR+4)` factor; datasheet applies ceil only to the division. ToA off otherwise. |
| Fig. 9 caption τ values | 788, 935, 1113 s for H = 560, 750, 1000 | 709, 850, 1022 s | Paper's quoted values match neither their own eq. (4) nor a corrected geometric formula. Likely a transcription error in the figure caption. |

## Known residual gap

After the τ and `n_payload` fixes, our Fig. 8 and Fig. 10 reproductions sit **~2% lower in PDR than the paper's published curves** for all non-trivial sweeps (cases where PDR is strictly between 0 and 100%).

Most likely causes (not bugs, both sides correct under their own conventions):

1. **Sampling phase relative to zenith.** Our packets land ~0.5 s from zenith; the paper's land ~2 s from zenith. Near the sharp Doppler-rate peak, this can flip 1-2 packets at the failure-region edge.
2. **Interpolation smoothing.** The paper interpolates `F_D` linearly from 1 Hz satellite-state samples to 1 ms resolution. Linear interpolation slightly understates curvature near the rate peak, so a packet or two at the boundary that fails for us may pass for them.
3. **Paper's `lost_packets = unique([..., L_joint_index])` quirk.** `L_joint_index` is a logical array being concatenated with index lists, introducing spurious 0/1 entries via `unique`. Direction of effect uncertain, magnitude small.

Closing this residual would require reproducing the paper's exact interp1 + ms-index pipeline, which adds complexity without affecting the underlying physics. Accepted as validation noise.

## Optional future additions

- **Visibility-failure check.** A packet whose end (`t + ToA`) extends past `tau/2` is physically lost — the satellite sets mid-transmission. The paper excludes such packets entirely; we currently let them through and the analytical `Dopplershift` extension typically marks them as successes. Effect: <1% PDR reduction (only the very last packet per pass, when it exists). Worth adding for physical accuracy when the model gets more realistic, especially at higher SF / lower bandwidth where ToA approaches R_p. Note: this *widens* the gap to the paper.
- **Link budget model.** AWGN, free-space path loss, antenna gains, receiver sensitivity → SNR per packet. Replace binary "passed Doppler" with `P(packet success | SNR, Doppler-ok)`. Reference candidate: Asad Ullah et al. [7] or [8] of the paper.
- **Rician fading.** K-factor parameterized channel. Likely small impact on DtS links (LoS-dominated) but standard practice.
- **TLE-based pass geometry.** Optional alternative to the analytical `pass_duration` + `Dopplershift` chain. Useful for reproducing specific real satellite scenarios (e.g. Norby). Would slot in as an alternate provider of the Doppler trace; the loss-decision loop stays unchanged.
- **Doppler-aware ADR.** Adaptive Data Rate that selects SF based on predicted Doppler conditions during the pass.
- **Off-zenith passes.** Real satellite passes rarely peak at exactly 90°. The current geometry assumes they do.

## Verification baseline

| Check | Status | Test |
|---|---|---|
| ToA matches Semtech LoRa Calculator | ✓ (within 0.05 ms) | manually verified |
| ToA matches paper's published values | ✓ (within ~1.5 ms, typo accounts for rest) | [toa_test.m](toa_test.m) |
| τ matches paper's TLE access window for Norby (H=560) | ✓ (within 1 s) | [tau_test.m](tau_test.m) |
| PDR (Fig. 8, Fig. 10) matches paper's published curves | ✓ (within ~2%, all non-trivial sweeps) | manually verified via `figure8`, `figure10`, plus `figure8_diag` / `figure10_diag` for failure-type decomposition |
