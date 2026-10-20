# Notes

Further explanation and clarification on details not included in the paper. Reference numbers follow the paper.

## Model

The LoRa packet engine has additional parameters that have a minor impact on the packet length. The default values were used for the header (explicit) and CRC (on). For the preamble, 8 symbols were selected, as in Ref. 8.

The data bytes in a LoRa packet are payload length + 5 additional to account for MAC overhead, as in Ref. 8.

The effect of CR is not studied, because there was no reference found for LoRa coding gain. Without that, a higher CR would just lower data rates.

The dynamic Doppler limit is tested over the packet's reception, (F\_D(t) - F\_D(t+ToA))/ToA. It does not follow the instantaneous rate as in eq. (10). This follows Ref. 8.

For the Rician K factor, Ref. 10 only had measurements for 20°–80°. Beyond this range, at high elevations, K was extrapolated with splines. At low elevations, the spline extrapolation would have led to higher K values, implying getting closer to LoS propagation. Therefore, it was held constant at K(20°) instead.

Currently, packets which start before but finish after the satellite passes below minimum elevation are still counted. This is different from Ref. 8.

The effect of fading is applied once per packet, and the channel is considered constant over the ToA. Considering coherence time better would improve model accuracy.

Ref. 7 states that the use of LDRO is mandated for LoRa parameter combinations with symbol times beyond 16 ms. Fig. 8 therefore includes only the LDRO-on point for these combinations. The LDRO-off points are included in Figs. 6–7 to show the trends of changing each parameter.

Ref. 9's DtS link budget model also includes log-normal shadowing with σ = 0.1 dB. It is omitted here due to its minimal impact, for the sake of a simpler model with an analytical probability distribution, and because the original paper considered that effect mainly for terrestrial transmissions in an alternate scenario.

## Deviations from references

Ref. 8's eq. (4) seems to be missing a (R+h)/R factor, which causes discrepancies with their own TLE visibility time window. This paper's method adds this factor and accurately reproduces the TLE window within 1 s.

Ref. 8's LoRa packet engine implementation in the linked GitHub repository seems to have a wrong value: 4.24 (4.25 in Ref. 7 and this paper) and applies the `ceil` incorrectly (this paper follows Ref. 7).

Ref. 10's eq. (28) cubic fit formula significantly deviates from the experimental measurement points, likely due to rounding the first coefficient 0.00015 to 0.0002. This paper uses spline interpolation and extrapolation instead.

## Validation

The code of Refs. 8 and 9 was used for validation, but none of it is reused in this repository.

This paper's Doppler model can reproduce the results of Ref. 8 within a margin of a few percentage points of PDR, always slightly lower. These are in `matlab/scripts/supplementary/figure8.m` and `figure10.m`.

Possible causes for the residual: Ref. 8 interpolates the Doppler shift from 1-second samples, while this paper computes it exactly at any time. Furthermore, the packet timings differ in the two papers.

ToA differences between this paper's packet engine model and Semtech's online calculator are in the microsecond range, much smaller than symbol times. Furthermore, `matlab/tests/toa_test.m` compares to Ref. 8 and agrees within 2 ms.

The pass duration is checked against Ref. 8 in `matlab/tests/tau_test.m`.

The analytical probability distribution is tested against Monte Carlo methods and known limits in `matlab/tests/link_success_prob_test.m`.

The Python port of the model for the web app reproduces the original MATLAB version. `python/tests/`

The web app's library-free functions for reduced load times accurately reproduce SciPy. `webapp/tests/`
