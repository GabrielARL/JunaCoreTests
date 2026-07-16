# JunaCoreTests

Independent behavioral, interface, receiver, and measured-channel verification
for [JunaCore.jl](https://github.com/GabrielARL/JunaCore.jl).

```bash
julia --project=. -e 'using Pkg; Pkg.develop(path="../JunaCore.jl"); Pkg.instantiate()'
julia --project=. test/runtests.jl
JUNA_INTERFACE_ROUNDTRIP=1 julia --project=. test/interface_contract.jl
```

Without a sibling checkout, first run
`Pkg.add(url="https://github.com/GabrielARL/JunaCore.jl")`. Override source
inspection with `JUNA_CORE_ROOT=/path/to/JunaCore.jl`.

The browser UI is maintained in
[JunaCoreExplorer](https://github.com/GabrielARL/JunaCoreExplorer).

<!-- juna:receiver-matrix:begin -->
## Commit-by-rate receiver performance

This main comparison fixes SG-1, 20 dB, seed 1, and uses one independently coded packet and one OFDM block per case. Each commit therefore records 20 measured cases. Each receiver cell is **PSR / BER / mean decode time per block**. With one block, PSR is necessarily binary; BER carries the finer error information. Click a cell to reveal the geometry, sample rates, payload size, and bit errors.

| JunaCore commit | code rate | N | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---|---:|---:|---:|---:|---:|---:|---:|
| [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 1/16 | 1024 | <details class="cell-details"><summary>0.000 / 0.024 / 3.61 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/16<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.61 ms/block<br>bit errors: 1/42</sub></details> | <details class="cell-details"><summary>0.000 / 0.119 / 3.94 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/16<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.94 ms/block<br>bit errors: 5/42</sub></details> | <details class="cell-details"><summary>0.000 / 0.119 / 10.61 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/16<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 10.61 ms/block<br>bit errors: 5/42</sub></details> | <details class="cell-details"><summary>0.000 / 0.143 / 85.52 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/16<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 85.52 ms/block<br>bit errors: 6/42</sub></details> | <details class="cell-details"><summary>0.000 / 0.143 / 15.96 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/16<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 15.96 ms/block<br>bit errors: 6/42</sub></details> |
| [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 1/8 | 1024 | <details class="cell-details"><summary>0.000 / 0.141 / 4.01 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/8<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 4.01 ms/block<br>bit errors: 12/85</sub></details> | <details class="cell-details"><summary>0.000 / 0.165 / 4.62 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/8<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 4.62 ms/block<br>bit errors: 14/85</sub></details> | <details class="cell-details"><summary>0.000 / 0.118 / 15.13 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/8<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 15.13 ms/block<br>bit errors: 10/85</sub></details> | <details class="cell-details"><summary>0.000 / 0.247 / 86.89 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/8<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 86.89 ms/block<br>bit errors: 21/85</sub></details> | <details class="cell-details"><summary>0.000 / 0.247 / 15.00 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/8<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 15.00 ms/block<br>bit errors: 21/85</sub></details> |
| [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 1/4 | 1024 | <details class="cell-details"><summary>0.000 / 0.118 / 3.10 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/4<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.10 ms/block<br>bit errors: 20/170</sub></details> | <details class="cell-details"><summary>0.000 / 0.159 / 3.60 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/4<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.60 ms/block<br>bit errors: 27/170</sub></details> | <details class="cell-details"><summary>0.000 / 0.088 / 12.23 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/4<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 12.23 ms/block<br>bit errors: 15/170</sub></details> | <details class="cell-details"><summary>0.000 / 0.194 / 74.34 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/4<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 74.34 ms/block<br>bit errors: 33/170</sub></details> | <details class="cell-details"><summary>0.000 / 0.194 / 13.35 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/4<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 13.35 ms/block<br>bit errors: 33/170</sub></details> |
| [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 1/2 | 1024 | <details class="cell-details"><summary>0.000 / 0.179 / 3.18 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/2<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.18 ms/block<br>bit errors: 61/340</sub></details> | <details class="cell-details"><summary>0.000 / 0.274 / 3.22 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/2<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 3.22 ms/block<br>bit errors: 93/340</sub></details> | <details class="cell-details"><summary>0.000 / 0.291 / 10.17 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/2<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 10.17 ms/block<br>bit errors: 99/340</sub></details> | <details class="cell-details"><summary>0.000 / 0.297 / 63.67 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/2<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 63.67 ms/block<br>bit errors: 101/340</sub></details> | <details class="cell-details"><summary>0.000 / 0.297 / 12.66 ms</summary><sub>channel: SG-1 (red1)<br>SNR: 20 dB<br>code rate: 1/2<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 1<br>seed: 1<br>mean decode: 12.66 ms/block<br>bit errors: 101/340</sub></details> |

## Measured-channel performance

The headline result is **JUNA Frame-wide LDPC** with Rpchan-compatible framing, pilots, code construction, preamble acquisition, and one LDPC codeword spanning each OFDM frame. Each row uses the channel's declared sample rate and its paper configuration at 20 dB.

### JUNA Frame-wide LDPC vs paper target (20 dB, full capture)

| site | channel | accepted | PSR | BER | rate (bit/s) | mean decode/frame | paper target PSR | paper target rate | ΔPSR |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SG-1 | `red1` | 360/360 | **1.000** | 0 | 5539 | 0.665 s | 1.000 | 5540 | +0.000 |
| SG-2 | `red2` | 193/350 | **0.551** | 0.070 | 2969 | 0.732 s | 0.571 | 3078 | -0.020 |
| SG-3 | `red3` | 103/149 | **0.691** | 0.038 | 1585 | 0.830 s | 0.570 | 1308 | +0.121 |
| NA-1 | `blue1` | 140/220 | **0.636** | 0.039 | 1750 | 0.646 s | 1.000 | 2751 | -0.364 |
| NA-2 | `blue2` | 13/166 | **0.078** | 0.166 | 91 | 0.188 s | 0.681 | 793 | -0.603 |
| NA-3 | `blue3` | 0/163 | **0.000** | 0.301 | 0 | 0.192 s | 0.374 | 428 | -0.374 |
| HW-1 | `yellow1` | 95/140 | **0.679** | 0.002 | 1062 | 3.034 s | 1.000 | 1565 | -0.321 |
| HW-2 | `yellow2` | 0/270 | **0.000** | 0.212 | 0 | 0.771 s | 0.963 | 3985 | -0.963 |
| HW-3 | `yellow3` | 0/460 | **0.000** | 0.378 | 0 | 0.249 s | 0.935 | 3303 | -0.935 |
| HW-4 | `yellow4` | 130/140 | **0.929** | 2.6e-04 | 1435 | 3.059 s | 1.000 | 1546 | -0.071 |
| HW-5 | `yellow5` | 0/490 | **0.000** | 0.403 | 0 | 0.232 s | 0.673 | 2254 | -0.673 |
| HW-6 | `yellow6` | 0/480 | **0.000** | 0.303 | 0 | 0.245 s | 0.583 | 2024 | -0.583 |

<details>
<summary><b>Per-symbol receiver diagnostic sweep (different experiment)</b></summary>

These values are **not directly comparable** with the frame-wide table. This diagnostic does not include JUNA Frame-wide LDPC: it sends ten independently coded packets per point through a shared known-waveform replay, uses oracle alignment, and the modem rate equals the capture rate instead of Rpchan's half-rate modem configuration. A packet succeeds only when every payload bit is correct, so the measured BER values naturally produce PSR 0/10 throughout this small diagnostic.

### All per-symbol SNR configurations

<details>
<summary><b>SG-1</b> (<code>red1</code>) — N=1024, CP=16</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.276 | 0.000 / 0.304 | 0.000 / 0.305 | 0.000 / 0.324 | 0.000 / 0.322 |
| 5 dB | 0.000 / 0.182 | 0.000 / 0.239 | 0.000 / 0.234 | 0.000 / 0.268 | 0.000 / 0.266 |
| 10 dB | 0.000 / 0.152 | 0.000 / 0.208 | 0.000 / 0.185 | 0.000 / 0.242 | 0.000 / 0.241 |
| 15 dB | 0.000 / 0.139 | 0.000 / 0.179 | 0.000 / 0.162 | 0.000 / 0.215 | 0.000 / 0.214 |
| 20 dB | 0.000 / 0.116 | 0.000 / 0.179 | 0.000 / 0.154 | 0.000 / 0.211 | 0.000 / 0.215 |
| 25 dB | 0.000 / 0.109 | 0.000 / 0.162 | 0.000 / 0.158 | 0.000 / 0.199 | 0.000 / 0.195 |
| 30 dB | 0.000 / 0.118 | 0.000 / 0.156 | 0.000 / 0.145 | 0.000 / 0.194 | 0.000 / 0.194 |

</details>

<details>
<summary><b>SG-2</b> (<code>red2</code>) — N=1024, CP=64</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.275 | 0.000 / 0.316 | 0.000 / 0.312 | 0.000 / 0.339 | 0.000 / 0.339 |
| 5 dB | 0.000 / 0.196 | 0.000 / 0.258 | 0.000 / 0.253 | 0.000 / 0.285 | 0.000 / 0.285 |
| 10 dB | 0.000 / 0.167 | 0.000 / 0.214 | 0.000 / 0.178 | 0.000 / 0.245 | 0.000 / 0.246 |
| 15 dB | 0.000 / 0.138 | 0.000 / 0.201 | 0.000 / 0.186 | 0.000 / 0.228 | 0.000 / 0.228 |
| 20 dB | 0.000 / 0.121 | 0.000 / 0.191 | 0.000 / 0.166 | 0.000 / 0.228 | 0.000 / 0.227 |
| 25 dB | 0.000 / 0.118 | 0.000 / 0.182 | 0.000 / 0.158 | 0.000 / 0.224 | 0.000 / 0.223 |
| 30 dB | 0.000 / 0.129 | 0.000 / 0.194 | 0.000 / 0.174 | 0.000 / 0.216 | 0.000 / 0.216 |

</details>

<details>
<summary><b>SG-3</b> (<code>red3</code>) — N=1024, CP=64</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.261 | 0.000 / 0.329 | 0.000 / 0.321 | 0.000 / 0.366 | 0.000 / 0.365 |
| 5 dB | 0.000 / 0.192 | 0.000 / 0.279 | 0.000 / 0.261 | 0.000 / 0.310 | 0.000 / 0.308 |
| 10 dB | 0.000 / 0.151 | 0.000 / 0.250 | 0.000 / 0.232 | 0.000 / 0.276 | 0.000 / 0.281 |
| 15 dB | 0.000 / 0.122 | 0.000 / 0.234 | 0.000 / 0.205 | 0.000 / 0.256 | 0.000 / 0.257 |
| 20 dB | 0.000 / 0.139 | 0.000 / 0.221 | 0.000 / 0.213 | 0.000 / 0.262 | 0.000 / 0.263 |
| 25 dB | 0.000 / 0.127 | 0.000 / 0.203 | 0.000 / 0.180 | 0.000 / 0.234 | 0.000 / 0.236 |
| 30 dB | 0.000 / 0.120 | 0.000 / 0.200 | 0.000 / 0.182 | 0.000 / 0.221 | 0.000 / 0.221 |

</details>

<details>
<summary><b>NA-1</b> (<code>blue1</code>) — N=1024, CP=0</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.242 | 0.000 / 0.310 | 0.000 / 0.306 | 0.000 / 0.342 | 0.000 / 0.341 |
| 5 dB | 0.000 / 0.169 | 0.000 / 0.261 | 0.000 / 0.236 | 0.000 / 0.286 | 0.000 / 0.284 |
| 10 dB | 0.000 / 0.124 | 0.000 / 0.211 | 0.000 / 0.198 | 0.000 / 0.253 | 0.000 / 0.252 |
| 15 dB | 0.000 / 0.112 | 0.000 / 0.201 | 0.000 / 0.179 | 0.000 / 0.225 | 0.000 / 0.224 |
| 20 dB | 0.000 / 0.102 | 0.000 / 0.192 | 0.000 / 0.157 | 0.000 / 0.221 | 0.000 / 0.221 |
| 25 dB | 0.000 / 0.102 | 0.000 / 0.189 | 0.000 / 0.160 | 0.000 / 0.201 | 0.000 / 0.203 |
| 30 dB | 0.000 / 0.099 | 0.000 / 0.187 | 0.000 / 0.160 | 0.000 / 0.214 | 0.000 / 0.216 |

</details>

<details>
<summary><b>NA-2</b> (<code>blue2</code>) — N=512, CP=0</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.518 | 0.000 / 0.376 | 0.000 / 0.366 | 0.000 / 0.402 | 0.000 / 0.401 |
| 5 dB | 0.000 / 0.520 | 0.000 / 0.365 | 0.000 / 0.365 | 0.000 / 0.388 | 0.000 / 0.387 |
| 10 dB | 0.000 / 0.516 | 0.000 / 0.348 | 0.000 / 0.329 | 0.000 / 0.350 | 0.000 / 0.351 |
| 15 dB | 0.000 / 0.496 | 0.000 / 0.333 | 0.000 / 0.309 | 0.000 / 0.355 | 0.000 / 0.357 |
| 20 dB | 0.000 / 0.511 | 0.000 / 0.324 | 0.000 / 0.296 | 0.000 / 0.344 | 0.000 / 0.342 |
| 25 dB | 0.000 / 0.512 | 0.000 / 0.320 | 0.000 / 0.296 | 0.000 / 0.349 | 0.000 / 0.349 |
| 30 dB | 0.000 / 0.500 | 0.000 / 0.318 | 0.000 / 0.293 | 0.000 / 0.340 | 0.000 / 0.342 |

</details>

<details>
<summary><b>NA-3</b> (<code>blue3</code>) — N=512, CP=32</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.506 | 0.000 / 0.435 | 0.000 / 0.432 | 0.000 / 0.439 | 0.000 / 0.436 |
| 5 dB | 0.000 / 0.532 | 0.000 / 0.382 | 0.000 / 0.368 | 0.000 / 0.396 | 0.000 / 0.395 |
| 10 dB | 0.000 / 0.518 | 0.000 / 0.403 | 0.000 / 0.375 | 0.000 / 0.409 | 0.000 / 0.409 |
| 15 dB | 0.000 / 0.517 | 0.000 / 0.398 | 0.000 / 0.390 | 0.000 / 0.420 | 0.000 / 0.419 |
| 20 dB | 0.000 / 0.506 | 0.000 / 0.403 | 0.000 / 0.396 | 0.000 / 0.417 | 0.000 / 0.418 |
| 25 dB | 0.000 / 0.509 | 0.000 / 0.398 | 0.000 / 0.384 | 0.000 / 0.414 | 0.000 / 0.411 |
| 30 dB | 0.000 / 0.526 | 0.000 / 0.407 | 0.000 / 0.392 | 0.000 / 0.409 | 0.000 / 0.414 |

</details>

<details>
<summary><b>HW-1</b> (<code>yellow1</code>) — N=2048, CP=64</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.260 | 0.000 / 0.301 | 0.000 / 0.296 | 0.000 / 0.328 | 0.000 / 0.327 |
| 5 dB | 0.000 / 0.187 | 0.000 / 0.236 | 0.000 / 0.242 | 0.000 / 0.272 | 0.000 / 0.268 |
| 10 dB | 0.000 / 0.175 | 0.000 / 0.206 | 0.000 / 0.201 | 0.000 / 0.236 | 0.000 / 0.236 |
| 15 dB | 0.000 / 0.166 | 0.000 / 0.197 | 0.000 / 0.182 | 0.000 / 0.216 | 0.000 / 0.216 |
| 20 dB | 0.000 / 0.142 | 0.000 / 0.179 | 0.000 / 0.177 | 0.000 / 0.218 | 0.000 / 0.219 |
| 25 dB | 0.000 / 0.141 | 0.000 / 0.172 | 0.000 / 0.174 | 0.000 / 0.208 | 0.000 / 0.208 |
| 30 dB | 0.000 / 0.155 | 0.000 / 0.170 | 0.000 / 0.166 | 0.000 / 0.189 | 0.000 / 0.186 |

</details>

<details>
<summary><b>HW-2</b> (<code>yellow2</code>) — N=1024, CP=16</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.273 | 0.000 / 0.325 | 0.000 / 0.323 | 0.000 / 0.353 | 0.000 / 0.353 |
| 5 dB | 0.000 / 0.229 | 0.000 / 0.270 | 0.000 / 0.285 | 0.000 / 0.305 | 0.000 / 0.302 |
| 10 dB | 0.000 / 0.202 | 0.000 / 0.263 | 0.000 / 0.262 | 0.000 / 0.292 | 0.000 / 0.293 |
| 15 dB | 0.000 / 0.196 | 0.000 / 0.249 | 0.000 / 0.248 | 0.000 / 0.281 | 0.000 / 0.281 |
| 20 dB | 0.000 / 0.196 | 0.000 / 0.242 | 0.000 / 0.236 | 0.000 / 0.284 | 0.000 / 0.282 |
| 25 dB | 0.000 / 0.189 | 0.000 / 0.235 | 0.000 / 0.230 | 0.000 / 0.268 | 0.000 / 0.269 |
| 30 dB | 0.000 / 0.198 | 0.000 / 0.235 | 0.000 / 0.227 | 0.000 / 0.266 | 0.000 / 0.264 |

</details>

<details>
<summary><b>HW-3</b> (<code>yellow3</code>) — N=512, CP=32</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.368 | 0.000 / 0.405 | 0.000 / 0.396 | 0.000 / 0.416 | 0.000 / 0.418 |
| 5 dB | 0.000 / 0.306 | 0.000 / 0.373 | 0.000 / 0.355 | 0.000 / 0.406 | 0.000 / 0.404 |
| 10 dB | 0.000 / 0.301 | 0.000 / 0.371 | 0.000 / 0.371 | 0.000 / 0.393 | 0.000 / 0.392 |
| 15 dB | 0.000 / 0.273 | 0.000 / 0.359 | 0.000 / 0.351 | 0.000 / 0.380 | 0.000 / 0.379 |
| 20 dB | 0.000 / 0.286 | 0.000 / 0.367 | 0.000 / 0.366 | 0.000 / 0.377 | 0.000 / 0.378 |
| 25 dB | 0.000 / 0.282 | 0.000 / 0.364 | 0.000 / 0.368 | 0.000 / 0.369 | 0.000 / 0.369 |
| 30 dB | 0.000 / 0.274 | 0.000 / 0.367 | 0.000 / 0.351 | 0.000 / 0.384 | 0.000 / 0.382 |

</details>

<details>
<summary><b>HW-4</b> (<code>yellow4</code>) — N=2048, CP=64</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.256 | 0.000 / 0.343 | 0.000 / 0.338 | 0.000 / 0.362 | 0.000 / 0.363 |
| 5 dB | 0.000 / 0.187 | 0.000 / 0.295 | 0.000 / 0.291 | 0.000 / 0.311 | 0.000 / 0.315 |
| 10 dB | 0.000 / 0.144 | 0.000 / 0.245 | 0.000 / 0.219 | 0.000 / 0.265 | 0.000 / 0.264 |
| 15 dB | 0.000 / 0.113 | 0.000 / 0.236 | 0.000 / 0.206 | 0.000 / 0.259 | 0.000 / 0.259 |
| 20 dB | 0.000 / 0.105 | 0.000 / 0.224 | 0.000 / 0.195 | 0.000 / 0.254 | 0.000 / 0.253 |
| 25 dB | 0.000 / 0.091 | 0.000 / 0.211 | 0.000 / 0.184 | 0.000 / 0.234 | 0.000 / 0.235 |
| 30 dB | 0.000 / 0.092 | 0.000 / 0.204 | 0.000 / 0.185 | 0.000 / 0.224 | 0.000 / 0.224 |

</details>

<details>
<summary><b>HW-5</b> (<code>yellow5</code>) — N=512, CP=0</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.385 | 0.000 / 0.416 | 0.000 / 0.415 | 0.000 / 0.425 | 0.000 / 0.423 |
| 5 dB | 0.000 / 0.362 | 0.000 / 0.393 | 0.000 / 0.392 | 0.000 / 0.414 | 0.000 / 0.414 |
| 10 dB | 0.000 / 0.347 | 0.000 / 0.396 | 0.000 / 0.404 | 0.000 / 0.400 | 0.000 / 0.401 |
| 15 dB | 0.000 / 0.349 | 0.000 / 0.384 | 0.000 / 0.387 | 0.000 / 0.401 | 0.000 / 0.399 |
| 20 dB | 0.000 / 0.344 | 0.000 / 0.375 | 0.000 / 0.388 | 0.000 / 0.397 | 0.000 / 0.396 |
| 25 dB | 0.000 / 0.344 | 0.000 / 0.372 | 0.000 / 0.366 | 0.000 / 0.378 | 0.000 / 0.378 |
| 30 dB | 0.000 / 0.338 | 0.000 / 0.373 | 0.000 / 0.382 | 0.000 / 0.382 | 0.000 / 0.386 |

</details>

<details>
<summary><b>HW-6</b> (<code>yellow6</code>) — N=512, CP=16</summary>

| SNR | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---:|---:|---:|---:|---:|---:|
| 0 dB | 0.000 / 0.318 | 0.000 / 0.392 | 0.000 / 0.398 | 0.000 / 0.398 | 0.000 / 0.396 |
| 5 dB | 0.000 / 0.269 | 0.000 / 0.371 | 0.000 / 0.342 | 0.000 / 0.401 | 0.000 / 0.400 |
| 10 dB | 0.000 / 0.243 | 0.000 / 0.356 | 0.000 / 0.329 | 0.000 / 0.371 | 0.000 / 0.371 |
| 15 dB | 0.000 / 0.226 | 0.000 / 0.347 | 0.000 / 0.329 | 0.000 / 0.358 | 0.000 / 0.357 |
| 20 dB | 0.000 / 0.224 | 0.000 / 0.340 | 0.000 / 0.312 | 0.000 / 0.350 | 0.000 / 0.352 |
| 25 dB | 0.000 / 0.221 | 0.000 / 0.326 | 0.000 / 0.310 | 0.000 / 0.331 | 0.000 / 0.331 |
| 30 dB | 0.000 / 0.215 | 0.000 / 0.334 | 0.000 / 0.324 | 0.000 / 0.346 | 0.000 / 0.345 |

</details>

</details>

PSR = packet-success rate. BER = payload bit-error rate. Sources: [`reports/paper_frame_wide_all_channels_stateful_full_20db.csv`](reports/paper_frame_wide_all_channels_stateful_full_20db.csv) and [`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv). Commit history: [`reports/sg1_20db_commit_history.csv`](reports/sg1_20db_commit_history.csv).
<!-- juna:receiver-matrix:end -->
