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

### Five per-symbol receivers at 20 dB

Each cell is **PSR / BER**. Click a cell to reveal its configuration, sample rates, packet count, seed, decode time, and bit errors.

| site | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---|---:|---:|---:|---:|---:|
| SG-1 | <details class="cell-details"><summary>0.000 / 0.116</summary><sub>profile: standard<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 198/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.179</summary><sub>profile: pfft<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 305/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.154</summary><sub>profile: lite<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0104 s<br>bit errors: 262/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.211</summary><sub>profile: full<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0690 s<br>bit errors: 358/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.215</summary><sub>profile: coupled<br>N: 1024<br>CP: 16<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0124 s<br>bit errors: 366/1700</sub></details> |
| SG-2 | <details class="cell-details"><summary>0.000 / 0.121</summary><sub>profile: standard<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0034 s<br>bit errors: 205/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.191</summary><sub>profile: pfft<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 325/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.166</summary><sub>profile: lite<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0113 s<br>bit errors: 283/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.228</summary><sub>profile: full<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0670 s<br>bit errors: 388/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.227</summary><sub>profile: coupled<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0130 s<br>bit errors: 386/1700</sub></details> |
| SG-3 | <details class="cell-details"><summary>0.000 / 0.139</summary><sub>profile: standard<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 236/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.221</summary><sub>profile: pfft<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0032 s<br>bit errors: 376/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.213</summary><sub>profile: lite<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0111 s<br>bit errors: 362/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.262</summary><sub>profile: full<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0664 s<br>bit errors: 446/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.263</summary><sub>profile: coupled<br>N: 1024<br>CP: 64<br>modem rate: 19200 samples/s<br>capture rate: 19200 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0125 s<br>bit errors: 447/1700</sub></details> |
| NA-1 | <details class="cell-details"><summary>0.000 / 0.102</summary><sub>profile: standard<br>N: 1024<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 174/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.192</summary><sub>profile: pfft<br>N: 1024<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0032 s<br>bit errors: 326/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.157</summary><sub>profile: lite<br>N: 1024<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0115 s<br>bit errors: 267/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.221</summary><sub>profile: full<br>N: 1024<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0665 s<br>bit errors: 375/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.221</summary><sub>profile: coupled<br>N: 1024<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0146 s<br>bit errors: 375/1700</sub></details> |
| NA-2 | <details class="cell-details"><summary>0.000 / 0.511</summary><sub>profile: standard<br>N: 512<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 869/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.324</summary><sub>profile: pfft<br>N: 512<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 550/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.296</summary><sub>profile: lite<br>N: 512<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0112 s<br>bit errors: 503/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.344</summary><sub>profile: full<br>N: 512<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0672 s<br>bit errors: 584/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.342</summary><sub>profile: coupled<br>N: 512<br>CP: 0<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0123 s<br>bit errors: 582/1700</sub></details> |
| NA-3 | <details class="cell-details"><summary>0.000 / 0.506</summary><sub>profile: standard<br>N: 512<br>CP: 32<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0029 s<br>bit errors: 861/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.403</summary><sub>profile: pfft<br>N: 512<br>CP: 32<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0029 s<br>bit errors: 685/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.396</summary><sub>profile: lite<br>N: 512<br>CP: 32<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0095 s<br>bit errors: 673/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.417</summary><sub>profile: full<br>N: 512<br>CP: 32<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0666 s<br>bit errors: 709/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.418</summary><sub>profile: coupled<br>N: 512<br>CP: 32<br>modem rate: 9765.625 samples/s<br>capture rate: 9765.625 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0123 s<br>bit errors: 710/1700</sub></details> |
| HW-1 | <details class="cell-details"><summary>0.000 / 0.142</summary><sub>profile: standard<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 241/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.179</summary><sub>profile: pfft<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 304/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.177</summary><sub>profile: lite<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0115 s<br>bit errors: 301/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.218</summary><sub>profile: full<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0690 s<br>bit errors: 371/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.219</summary><sub>profile: coupled<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0124 s<br>bit errors: 373/1700</sub></details> |
| HW-2 | <details class="cell-details"><summary>0.000 / 0.196</summary><sub>profile: standard<br>N: 1024<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0036 s<br>bit errors: 333/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.242</summary><sub>profile: pfft<br>N: 1024<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0034 s<br>bit errors: 411/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.236</summary><sub>profile: lite<br>N: 1024<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0104 s<br>bit errors: 402/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.284</summary><sub>profile: full<br>N: 1024<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0699 s<br>bit errors: 482/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.282</summary><sub>profile: coupled<br>N: 1024<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0167 s<br>bit errors: 480/1700</sub></details> |
| HW-3 | <details class="cell-details"><summary>0.000 / 0.286</summary><sub>profile: standard<br>N: 512<br>CP: 32<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0031 s<br>bit errors: 487/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.367</summary><sub>profile: pfft<br>N: 512<br>CP: 32<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0030 s<br>bit errors: 624/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.366</summary><sub>profile: lite<br>N: 512<br>CP: 32<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0098 s<br>bit errors: 622/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.377</summary><sub>profile: full<br>N: 512<br>CP: 32<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0682 s<br>bit errors: 641/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.378</summary><sub>profile: coupled<br>N: 512<br>CP: 32<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0128 s<br>bit errors: 642/1700</sub></details> |
| HW-4 | <details class="cell-details"><summary>0.000 / 0.105</summary><sub>profile: standard<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0034 s<br>bit errors: 178/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.224</summary><sub>profile: pfft<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 381/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.195</summary><sub>profile: lite<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0105 s<br>bit errors: 331/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.254</summary><sub>profile: full<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0707 s<br>bit errors: 432/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.253</summary><sub>profile: coupled<br>N: 2048<br>CP: 64<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0155 s<br>bit errors: 430/1700</sub></details> |
| HW-5 | <details class="cell-details"><summary>0.000 / 0.344</summary><sub>profile: standard<br>N: 512<br>CP: 0<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0031 s<br>bit errors: 584/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.375</summary><sub>profile: pfft<br>N: 512<br>CP: 0<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0031 s<br>bit errors: 637/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.388</summary><sub>profile: lite<br>N: 512<br>CP: 0<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0108 s<br>bit errors: 659/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.397</summary><sub>profile: full<br>N: 512<br>CP: 0<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0713 s<br>bit errors: 675/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.396</summary><sub>profile: coupled<br>N: 512<br>CP: 0<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0130 s<br>bit errors: 673/1700</sub></details> |
| HW-6 | <details class="cell-details"><summary>0.000 / 0.224</summary><sub>profile: standard<br>N: 512<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 380/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.340</summary><sub>profile: pfft<br>N: 512<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0033 s<br>bit errors: 578/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.312</summary><sub>profile: lite<br>N: 512<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0127 s<br>bit errors: 531/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.350</summary><sub>profile: full<br>N: 512<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0739 s<br>bit errors: 595/1700</sub></details> | <details class="cell-details"><summary>0.000 / 0.352</summary><sub>profile: coupled<br>N: 512<br>CP: 16<br>modem rate: 12500 samples/s<br>capture rate: 12500 samples/s<br>packets: 10<br>seed: 1<br>mean decode: 0.0127 s<br>bit errors: 598/1700</sub></details> |

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

PSR = packet-success rate. BER = payload bit-error rate. Sources: [`reports/paper_frame_wide_all_channels_stateful_full_20db.csv`](reports/paper_frame_wide_all_channels_stateful_full_20db.csv) and [`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv).
<!-- juna:receiver-matrix:end -->
