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
## Five-receiver comparison

Headline values are **PSR / BER at 20 dB**. Hover over a cell for its configuration, sample rates, packet count, seed, decode time, and bit errors. Expand a site below the table to compare every SNR configuration.

| site | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |
|---|---:|---:|---:|---:|---:|
| SG-1 | <abbr title="profile=standard; N=1024; CP=16; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=198/1700">0.000 / 0.116</abbr> | <abbr title="profile=pfft; N=1024; CP=16; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=305/1700">0.000 / 0.179</abbr> | <abbr title="profile=lite; N=1024; CP=16; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0104 s; bit errors=262/1700">0.000 / 0.154</abbr> | <abbr title="profile=full; N=1024; CP=16; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0690 s; bit errors=358/1700">0.000 / 0.211</abbr> | <abbr title="profile=coupled; N=1024; CP=16; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0124 s; bit errors=366/1700">0.000 / 0.215</abbr> |
| SG-2 | <abbr title="profile=standard; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0034 s; bit errors=205/1700">0.000 / 0.121</abbr> | <abbr title="profile=pfft; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=325/1700">0.000 / 0.191</abbr> | <abbr title="profile=lite; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0113 s; bit errors=283/1700">0.000 / 0.166</abbr> | <abbr title="profile=full; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0670 s; bit errors=388/1700">0.000 / 0.228</abbr> | <abbr title="profile=coupled; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0130 s; bit errors=386/1700">0.000 / 0.227</abbr> |
| SG-3 | <abbr title="profile=standard; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=236/1700">0.000 / 0.139</abbr> | <abbr title="profile=pfft; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0032 s; bit errors=376/1700">0.000 / 0.221</abbr> | <abbr title="profile=lite; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0111 s; bit errors=362/1700">0.000 / 0.213</abbr> | <abbr title="profile=full; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0664 s; bit errors=446/1700">0.000 / 0.262</abbr> | <abbr title="profile=coupled; N=1024; CP=64; modem rate=19200 samples/s; capture rate=19200 samples/s; packets=10; seed=1; mean decode=0.0125 s; bit errors=447/1700">0.000 / 0.263</abbr> |
| NA-1 | <abbr title="profile=standard; N=1024; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=174/1700">0.000 / 0.102</abbr> | <abbr title="profile=pfft; N=1024; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0032 s; bit errors=326/1700">0.000 / 0.192</abbr> | <abbr title="profile=lite; N=1024; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0115 s; bit errors=267/1700">0.000 / 0.157</abbr> | <abbr title="profile=full; N=1024; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0665 s; bit errors=375/1700">0.000 / 0.221</abbr> | <abbr title="profile=coupled; N=1024; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0146 s; bit errors=375/1700">0.000 / 0.221</abbr> |
| NA-2 | <abbr title="profile=standard; N=512; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=869/1700">0.000 / 0.511</abbr> | <abbr title="profile=pfft; N=512; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=550/1700">0.000 / 0.324</abbr> | <abbr title="profile=lite; N=512; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0112 s; bit errors=503/1700">0.000 / 0.296</abbr> | <abbr title="profile=full; N=512; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0672 s; bit errors=584/1700">0.000 / 0.344</abbr> | <abbr title="profile=coupled; N=512; CP=0; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0123 s; bit errors=582/1700">0.000 / 0.342</abbr> |
| NA-3 | <abbr title="profile=standard; N=512; CP=32; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0029 s; bit errors=861/1700">0.000 / 0.506</abbr> | <abbr title="profile=pfft; N=512; CP=32; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0029 s; bit errors=685/1700">0.000 / 0.403</abbr> | <abbr title="profile=lite; N=512; CP=32; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0095 s; bit errors=673/1700">0.000 / 0.396</abbr> | <abbr title="profile=full; N=512; CP=32; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0666 s; bit errors=709/1700">0.000 / 0.417</abbr> | <abbr title="profile=coupled; N=512; CP=32; modem rate=9765.625 samples/s; capture rate=9765.625 samples/s; packets=10; seed=1; mean decode=0.0123 s; bit errors=710/1700">0.000 / 0.418</abbr> |
| HW-1 | <abbr title="profile=standard; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=241/1700">0.000 / 0.142</abbr> | <abbr title="profile=pfft; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=304/1700">0.000 / 0.179</abbr> | <abbr title="profile=lite; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0115 s; bit errors=301/1700">0.000 / 0.177</abbr> | <abbr title="profile=full; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0690 s; bit errors=371/1700">0.000 / 0.218</abbr> | <abbr title="profile=coupled; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0124 s; bit errors=373/1700">0.000 / 0.219</abbr> |
| HW-2 | <abbr title="profile=standard; N=1024; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0036 s; bit errors=333/1700">0.000 / 0.196</abbr> | <abbr title="profile=pfft; N=1024; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0034 s; bit errors=411/1700">0.000 / 0.242</abbr> | <abbr title="profile=lite; N=1024; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0104 s; bit errors=402/1700">0.000 / 0.236</abbr> | <abbr title="profile=full; N=1024; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0699 s; bit errors=482/1700">0.000 / 0.284</abbr> | <abbr title="profile=coupled; N=1024; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0167 s; bit errors=480/1700">0.000 / 0.282</abbr> |
| HW-3 | <abbr title="profile=standard; N=512; CP=32; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0031 s; bit errors=487/1700">0.000 / 0.286</abbr> | <abbr title="profile=pfft; N=512; CP=32; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0030 s; bit errors=624/1700">0.000 / 0.367</abbr> | <abbr title="profile=lite; N=512; CP=32; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0098 s; bit errors=622/1700">0.000 / 0.366</abbr> | <abbr title="profile=full; N=512; CP=32; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0682 s; bit errors=641/1700">0.000 / 0.377</abbr> | <abbr title="profile=coupled; N=512; CP=32; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0128 s; bit errors=642/1700">0.000 / 0.378</abbr> |
| HW-4 | <abbr title="profile=standard; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0034 s; bit errors=178/1700">0.000 / 0.105</abbr> | <abbr title="profile=pfft; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=381/1700">0.000 / 0.224</abbr> | <abbr title="profile=lite; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0105 s; bit errors=331/1700">0.000 / 0.195</abbr> | <abbr title="profile=full; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0707 s; bit errors=432/1700">0.000 / 0.254</abbr> | <abbr title="profile=coupled; N=2048; CP=64; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0155 s; bit errors=430/1700">0.000 / 0.253</abbr> |
| HW-5 | <abbr title="profile=standard; N=512; CP=0; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0031 s; bit errors=584/1700">0.000 / 0.344</abbr> | <abbr title="profile=pfft; N=512; CP=0; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0031 s; bit errors=637/1700">0.000 / 0.375</abbr> | <abbr title="profile=lite; N=512; CP=0; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0108 s; bit errors=659/1700">0.000 / 0.388</abbr> | <abbr title="profile=full; N=512; CP=0; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0713 s; bit errors=675/1700">0.000 / 0.397</abbr> | <abbr title="profile=coupled; N=512; CP=0; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0130 s; bit errors=673/1700">0.000 / 0.396</abbr> |
| HW-6 | <abbr title="profile=standard; N=512; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=380/1700">0.000 / 0.224</abbr> | <abbr title="profile=pfft; N=512; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0033 s; bit errors=578/1700">0.000 / 0.340</abbr> | <abbr title="profile=lite; N=512; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0127 s; bit errors=531/1700">0.000 / 0.312</abbr> | <abbr title="profile=full; N=512; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0739 s; bit errors=595/1700">0.000 / 0.350</abbr> | <abbr title="profile=coupled; N=512; CP=16; modem rate=12500 samples/s; capture rate=12500 samples/s; packets=10; seed=1; mean decode=0.0127 s; bit errors=598/1700">0.000 / 0.352</abbr> |

### All configurations

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

PSR = packet-success rate. BER = payload bit-error rate. Source: [`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv).
<!-- juna:receiver-matrix:end -->
