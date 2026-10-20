# Trading Range for Throughput: Joint Channel Modeling and Design Space Exploration for LoRa Direct-to-Satellite Links

This repository contains the source code and an interactive companion web app for the paper by Gergely Homoki and Hyochoong Bang for The 17th Asia-Pacific International Symposium on Aerospace Technology (APISAT 2026), to be published on J-STAGE. (DOI link and citation to be provided after publication.)

The companion web app, allowing for LoRa DtS link analysis with parameters different from those used in the paper, is available at [https://ghomoki.github.io/LoRa-DtS-joint-performance/](https://ghomoki.github.io/LoRa-DtS-joint-performance/).

## Model

A LEO satellite in a circular orbit passes directly over a ground station. A LoRa communication link using Semtech's SX1276 chip is established between the two. The reception of packets along the pass is modelled, subject to time-varying channel effects.

Three failure modes may prevent receiving a packet:

* The carrier frequency Doppler shift may exceed the SX1276 chip's limits.
* The carrier frequency's rate of change due to Doppler may exceed the SX1276 chip's limits.
* The link budget may not close, subject to probabilistic, elevation-dependent Rician fading.

Packet reception is evaluated on two figures of merit:

* PDR: packet delivery ratio, percentage of packets successfully received over the pass, subject to the three failure modes.
* DR: data rate, in bits per second, a function of the LoRa parameters.

Details and equations are provided in the paper. Additional disclaimers are included in [NOTES.md](NOTES.md).

## Parameters

These can be separated into two groups:

* The mission parameters are generally pre-determined during satellite design.

  * carrier frequency, in MHz
  * altitude, in km
  * payload length, in bytes
  * Tx power, in dBm
  * Tx, Rx antenna gains, in dBi
* The LoRa parameters can be freely selected among those offered by the LoRa chip.

  * SF, spreading factor
  * B, bandwidth, in kHz
  * LDRO, low data rate optimization

## Analysis

The web app shows 3 tabs:

1. Analysis of a single satellite pass, with one set of mission and LoRa parameters. Reproduces Fig. 2 in the paper with additional information.
2. One mission or LoRa parameter is swept, and its effect on PDR is plotted for one or more sets of parameters. Reproduces Figs. 3–7.
3. For a given mission with a set of mission parameters, all LoRa parameter combinations are simulated to find the Pareto front of the two figures of merit. Reproduces Fig. 8.

The default parameter values are those used in the paper, but they may be changed for any user-specified mission or LoRa parameters.

## Code

* `matlab/`: the model, scripts generating the paper's figures, and extra development figures and tests. Requires the Statistics and Machine Learning Toolbox.
* `python/`: Python port of the model, used by the web app.
* `webapp/`: the Streamlit web app.

## Acknowledgment

This research was supported by the Space-K BIG Project Program funded by the Korea AeroSpace Administration (KASA) (Grant No. RS-2025-16063273).

## License

[MIT](LICENSE)
