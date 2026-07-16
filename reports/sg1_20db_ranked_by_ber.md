# SG-1 at 20 dB: Lowest BER

Mean payload bit-error rate ascending. All 180 measured receiver cells are shown. [Return to the main matrix](../README.md).

| rank | JunaCore commit | Pilot Ratio | code rate | N | receiver | PSR | BER | decode (ms/block) | effective rate (bit/s) |
|---:|---|---:|---:|---:|---|---:|---:|---:|---:|
| 1 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 2048 | JUNA-Lite | 0.56981981982 | 0.0160448058678 | 31.5286800946 | 598.200523104 |
| 2 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 512 | Standard OFDM | 0.668587896254 | 0.0241869081927 | 1.73845940173 | 679.616390584 |
| 3 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 1024 | Standard OFDM | 0.551645856981 | 0.0257215826172 | 3.65071149262 | 569.471665214 |
| 4 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 1024 | JUNA-Lite | 0.598183881952 | 0.0363426301281 | 11.3703454098 | 617.513513514 |
| 5 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 2048 | JUNA-Lite | 0.222972972973 | 0.0424809424809 | 45.4346857185 | 403.940714908 |
| 6 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 2048 | JUNA-Lite | 0.274774774775 | 0.0441945441945 | 38.0330783761 | 365.042720139 |
| 7 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 2048 | Standard OFDM | 0.141891891892 | 0.0575221238938 | 8.53248277703 | 148.95902354 |
| 8 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 512 | Standard OFDM | 0.284149855908 | 0.0615067929189 | 1.98253822651 | 361.046207498 |
| 9 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 1024 | Standard OFDM | 0.141884222474 | 0.0634841968953 | 4.35391727128 | 185.701830863 |
| 10 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 1024 | Standard OFDM | 0.10896708286 | 0.0698362919363 | 5.1156747639 | 194.845684394 |
| 11 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 2048 | Partial FFT+FEC | 0.00225225225225 | 0.075659730527 | 8.64934518018 | 2.36442894507 |
| 12 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 2048 | JUNA-Wz | 0.130630630631 | 0.0760782906801 | 189.496256752 | 137.136878814 |
| 13 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 2048 | JUNA-WCz | 0.130630630631 | 0.0760982221159 | 34.2423499279 | 137.136878814 |
| 14 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 1024 | JUNA-Lite | 0.247446083995 | 0.0766734344775 | 15.5964123825 | 323.863993025 |
| 15 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 512 | JUNA-Lite | 0.491066282421 | 0.0766982297242 | 4.96029025476 | 499.16652136 |
| 16 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 1024 | Standard OFDM | 0.00908059023837 | 0.0845881088465 | 3.66702290919 | 18.9154315606 |
| 17 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 1024 | JUNA-WCz | 0.372304199773 | 0.0904815955894 | 14.4369056788 | 384.334786399 |
| 18 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 1024 | JUNA-Wz | 0.372304199773 | 0.0906842873358 | 58.8616133598 | 384.334786399 |
| 19 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 1024 | Standard OFDM | 0.0011350737798 | 0.0948905692955 | 4.25676250965 | 2.97122929381 |
| 20 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 512 | Standard OFDM | 0.0478386167147 | 0.0962536023055 | 1.69286098444 | 97.2554489974 |
| 21 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 512 | Standard OFDM | 0.0409221902017 | 0.0987271853987 | 2.34626425821 | 71.3095030514 |
| 22 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 2048 | Partial FFT+FEC | 0.00225225225225 | 0.101036351036 | 10.6770128446 | 2.99215344377 |
| 23 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 2048 | JUNA-Lite | 0 | 0.106663079008 | 32.874736268 | 0 |
| 24 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 2048 | JUNA-Wz | 0.0518018018018 | 0.114187614188 | 224.285807198 | 68.8195292066 |
| 25 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 2048 | JUNA-WCz | 0.0518018018018 | 0.114219114219 | 39.9254458874 | 68.8195292066 |
| 26 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 1024 | Partial FFT+FEC | 0.0136208853575 | 0.117054483541 | 3.85022152554 | 14.0610287707 |
| 27 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 1024 | Standard OFDM | 0 | 0.117173766737 | 3.46496474801 | 0 |
| 28 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 1024 | Standard OFDM | 0 | 0.117959909662 | 5.01319470261 | 0 |
| 29 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 512 | JUNA-Wz | 0.423631123919 | 0.119308357349 | 25.018374653 | 430.619006103 |
| 30 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 512 | JUNA-WCz | 0.423631123919 | 0.119431864965 | 6.8669969879 | 430.619006103 |
| 31 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 512 | Standard OFDM | 0.00345821325648 | 0.119950596953 | 1.95641182363 | 8.78814298169 |
| 32 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 2048 | JUNA-Lite | 0 | 0.120975870976 | 35.2524621914 | 0 |
| 33 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 1024 | JUNA-Lite | 0.00340522133939 | 0.121784376161 | 13.283612311 | 7.09328683522 |
| 34 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 2048 | Standard OFDM | 0.0157657657658 | 0.121794871795 | 9.95719039865 | 20.9450741064 |
| 35 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 512 | Standard OFDM | 0 | 0.125627830383 | 1.58793651988 | 0 |
| 36 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 2048 | Partial FFT+FEC | 0 | 0.126026468947 | 8.24903677928 | 0 |
| 37 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 2048 | Partial FFT+FEC | 0 | 0.126345576346 | 11.6799717883 | 0 |
| 38 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 2048 | Standard OFDM | 0 | 0.126793829227 | 8.29427780631 | 0 |
| 39 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 2048 | Standard OFDM | 0.0112612612613 | 0.128320628321 | 11.6884121419 | 20.4010462075 |
| 40 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 2048 | JUNA-Lite | 0 | 0.128470778471 | 44.7588035428 | 0 |
| 41 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 1024 | Standard OFDM | 0 | 0.131660593026 | 4.44279315096 | 0 |
| 42 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 512 | Standard OFDM | 0 | 0.133361947391 | 1.90099302651 | 0 |
| 43 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 1024 | JUNA-Lite | 0 | 0.137008201308 | 15.350963353 | 0 |
| 44 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 512 | Standard OFDM | 0.00115273775216 | 0.139301152738 | 2.30830432968 | 4.01743679163 |
| 45 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 1024 | JUNA-Lite | 0.0771850170261 | 0.140093848368 | 18.4440650749 | 138.015693112 |
| 46 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 2048 | JUNA-Lite | 0 | 0.140544518028 | 28.0422760135 | 0 |
| 47 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 1024 | Partial FFT+FEC | 0 | 0.141663234659 | 3.71460455051 | 0 |
| 48 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 2048 | Partial FFT+FEC | 0 | 0.142112392112 | 9.62386980405 | 0 |
| 49 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 2048 | JUNA-Wz | 0.0157657657658 | 0.143797643798 | 296.414843464 | 28.5614646905 |
| 50 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 2048 | JUNA-WCz | 0.0157657657658 | 0.143901593902 | 46.9833614572 | 28.5614646905 |
| 51 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 1024 | Standard OFDM | 0 | 0.145968147723 | 4.64501121339 | 0 |
| 52 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 2048 | Standard OFDM | 0 | 0.146057771058 | 9.59071287387 | 0 |
| 53 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 2048 | Standard OFDM | 0 | 0.151124634568 | 7.77261734459 | 0 |
| 54 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 2048 | Partial FFT+FEC | 0 | 0.151214128035 | 7.8494367973 | 0 |
| 55 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 1024 | Partial FFT+FEC | 0.0011350737798 | 0.153522725456 | 4.29219175028 | 1.4856146469 |
| 56 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 1024 | JUNA-Lite | 0 | 0.155098289353 | 12.1214251691 | 0 |
| 57 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 512 | JUNA-Lite | 0.176368876081 | 0.155718402635 | 6.57374456196 | 224.097646033 |
| 58 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 2048 | JUNA-Lite | 0 | 0.157492571105 | 34.5522495698 | 0 |
| 59 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 2048 | JUNA-Wz | 0 | 0.158664195169 | 186.755306279 | 0 |
| 60 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 2048 | JUNA-WCz | 0 | 0.158684126604 | 33.4942459437 | 0 |
| 61 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 2048 | Standard OFDM | 0 | 0.160102510888 | 8.84336635586 | 0 |
| 62 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 1024 | JUNA-Wz | 0.0624290578888 | 0.161516202779 | 91.0795886016 | 81.7088055798 |
| 63 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 2048 | Partial FFT+FEC | 0 | 0.161711711712 | 11.2508608108 | 0 |
| 64 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 1024 | JUNA-WCz | 0.0624290578888 | 0.16213969401 | 17.5114609591 | 81.7088055798 |
| 65 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 2048 | Standard OFDM | 0 | 0.162832062832 | 11.4380836982 | 0 |
| 66 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 2048 | JUNA-Lite | 0 | 0.165979440979 | 37.9736256239 | 0 |
| 67 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 1024 | Partial FFT+FEC | 0 | 0.166830733378 | 3.45190476163 | 0 |
| 68 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 1024 | Partial FFT+FEC | 0 | 0.167879010727 | 4.21591608059 | 0 |
| 69 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 512 | Standard OFDM | 0 | 0.169272334294 | 2.22064766052 | 0 |
| 70 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 2048 | Partial FFT+FEC | 0 | 0.170263195132 | 9.07331175 | 0 |
| 71 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/16 | 512 | Partial FFT+FEC | 0.0161383285303 | 0.174722107863 | 1.82880592911 | 16.4045335658 |
| 72 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 2048 | JUNA-Wz | 0 | 0.175494550495 | 214.997232606 | 0 |
| 73 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 1024 | JUNA-Wz | 0.00227014755959 | 0.17553463984 | 81.0448815539 | 4.72885789015 |
| 74 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 1024 | JUNA-WCz | 0.00227014755959 | 0.175635088847 | 15.1682793984 | 4.72885789015 |
| 75 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 2048 | JUNA-WCz | 0 | 0.175715050715 | 39.3906109955 | 0 |
| 76 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 512 | JUNA-Lite | 0.0230547550432 | 0.183377933306 | 5.84912738847 | 46.8700959024 |
| 77 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 2048 | Partial FFT+FEC | 0 | 0.183417070917 | 10.734010759 | 0 |
| 78 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 2048 | Standard OFDM | 0 | 0.183616308616 | 11.3193504977 | 0 |
| 79 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 2048 | JUNA-Wz | 0 | 0.185350913828 | 179.138077365 | 0 |
| 80 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 1024 | JUNA-Lite | 0 | 0.185373930749 | 18.383222286 | 0 |
| 81 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 2048 | JUNA-WCz | 0 | 0.185390688702 | 31.7878598739 | 0 |
| 82 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 1024 | JUNA-Lite | 0 | 0.192146085987 | 13.7960386254 | 0 |
| 83 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 2048 | JUNA-Wz | 0 | 0.192192192192 | 272.179762836 | 0 |
| 84 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 2048 | JUNA-WCz | 0 | 0.192452067452 | 44.6841553108 | 0 |
| 85 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 1024 | JUNA-Wz | 0 | 0.196583587792 | 94.2601616039 | 0 |
| 86 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 1024 | JUNA-WCz | 0 | 0.196655529088 | 17.0887732191 | 0 |
| 87 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 512 | Partial FFT+FEC | 0.000576368876081 | 0.200298476739 | 1.73960880865 | 1.17175239756 |
| 88 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 1024 | JUNA-Wz | 0 | 0.202083312406 | 75.4222296583 | 0 |
| 89 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 1024 | JUNA-WCz | 0 | 0.202299277772 | 14.4493180976 | 0 |
| 90 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 2048 | JUNA-Wz | 0 | 0.203634262535 | 223.089778856 | 0 |
| 91 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 2048 | JUNA-WCz | 0 | 0.203897614892 | 36.1486608468 | 0 |
| 92 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 512 | JUNA-Lite | 0 | 0.204960889255 | 5.33238830259 | 0 |
| 93 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 1024 | Partial FFT+FEC | 0 | 0.205870521935 | 4.07979682974 | 0 |
| 94 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 512 | JUNA-WCz | 0.136023054755 | 0.214409221902 | 7.91278824899 | 172.83347864 |
| 95 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 512 | JUNA-Wz | 0.136023054755 | 0.214475092631 | 37.1935827326 | 172.83347864 |
| 96 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 2048 | JUNA-WCz | 0 | 0.215817740818 | 42.0400529324 | 0 |
| 97 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 2048 | JUNA-Wz | 0 | 0.216034303534 | 248.213261923 | 0 |
| 98 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 512 | JUNA-Lite | 0.00115273775216 | 0.216887608069 | 6.58686029568 | 2.9293809939 |
| 99 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 512 | Partial FFT+FEC | 0 | 0.220497118156 | 1.54629284207 | 0 |
| 100 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 1024 | JUNA-Lite | 0 | 0.222594404203 | 17.3210905255 | 0 |
| 101 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 1024 | Partial FFT+FEC | 0 | 0.226769018337 | 5.14977789217 | 0 |
| 102 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 512 | JUNA-WCz | 0.0224783861671 | 0.22810827501 | 7.02775182882 | 45.6983435048 |
| 103 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/8 | 512 | JUNA-Wz | 0.0224783861671 | 0.228128859613 | 35.1309097159 | 45.6983435048 |
| 104 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/16 | 512 | Partial FFT+FEC | 0.000576368876081 | 0.230514615068 | 2.04832303055 | 0.732345248474 |
| 105 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 1024 | Partial FFT+FEC | 0 | 0.230613056859 | 5.06877958683 | 0 |
| 106 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 1024 | JUNA-WCz | 0 | 0.23429515901 | 16.1201823859 | 0 |
| 107 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 1024 | JUNA-Wz | 0 | 0.23431108987 | 89.108244025 | 0 |
| 108 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 1024 | JUNA-WCz | 0.0476730987514 | 0.239348444247 | 20.2656346016 | 85.2449869224 |
| 109 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 1024 | JUNA-Wz | 0.0476730987514 | 0.239512269328 | 112.128428781 | 85.2449869224 |
| 110 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 1024 | Standard OFDM | 0 | 0.245446550052 | 3.00929303632 | 0 |
| 111 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 512 | Partial FFT+FEC | 0 | 0.247114038699 | 1.95074430432 | 0 |
| 112 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 1024 | Partial FFT+FEC | 0 | 0.248031173573 | 4.67259820204 | 0 |
| 113 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 512 | JUNA-Wz | 0 | 0.248461300947 | 32.5775824438 | 0 |
| 114 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/4 | 512 | JUNA-WCz | 0 | 0.248646562371 | 6.7358915683 | 0 |
| 115 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 512 | JUNA-Lite | 0 | 0.249334723159 | 6.31047896196 | 0 |
| 116 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 512 | Standard OFDM | 0 | 0.25124794154 | 1.53397530375 | 0 |
| 117 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 512 | Standard OFDM | 0 | 0.252253357042 | 1.63513260346 | 0 |
| 118 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 1024 | JUNA-Wz | 0 | 0.256082006155 | 115.619811023 | 0 |
| 119 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 1024 | JUNA-WCz | 0 | 0.256210725862 | 20.0799456686 | 0 |
| 120 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 1024 | Standard OFDM | 0 | 0.260103152319 | 3.45892251305 | 0 |
| 121 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 512 | Partial FFT+FEC | 0 | 0.264663682629 | 1.85289879769 | 0 |
| 122 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 2048 | Standard OFDM | 0 | 0.26807270847 | 6.79754399099 | 0 |
| 123 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 512 | JUNA-WCz | 0.00115273775216 | 0.271395636064 | 7.82739341441 | 2.9293809939 |
| 124 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/8 | 512 | JUNA-Wz | 0.00115273775216 | 0.271395636064 | 40.4684551297 | 2.9293809939 |
| 125 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 2048 | JUNA-Lite | 0 | 0.27281586222 | 23.8382183423 | 0 |
| 126 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 1024 | JUNA-WCz | 0 | 0.273505973765 | 19.6805780068 | 0 |
| 127 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 1024 | JUNA-Wz | 0 | 0.273666873398 | 107.377773028 | 0 |
| 128 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 1024 | Standard OFDM | 0 | 0.273714934328 | 4.12734065607 | 0 |
| 129 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 2048 | Standard OFDM | 0 | 0.276107259092 | 7.70503167568 | 0 |
| 130 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 2048 | Partial FFT+FEC | 0 | 0.280562018973 | 6.89640870946 | 0 |
| 131 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 512 | Standard OFDM | 0 | 0.283533066357 | 1.94623738617 | 0 |
| 132 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 2048 | JUNA-Lite | 0 | 0.288797305159 | 26.6752269257 | 0 |
| 133 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 512 | JUNA-WCz | 0 | 0.290518527602 | 7.50988570778 | 0 |
| 134 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/4 | 512 | JUNA-Wz | 0 | 0.290649334723 | 38.9930397481 | 0 |
| 135 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 2048 | JUNA-Lite | 0 | 0.29080890628 | 35.0041702027 | 0 |
| 136 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 1024 | JUNA-Lite | 0 | 0.292508262485 | 10.3932389115 | 0 |
| 137 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 2048 | Standard OFDM | 0 | 0.292684580801 | 9.95943080856 | 0 |
| 138 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 2048 | JUNA-WCz | 0 | 0.293573374699 | 28.596241205 | 0 |
| 139 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 2048 | JUNA-Wz | 0 | 0.293720044548 | 154.855450529 | 0 |
| 140 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 2048 | Partial FFT+FEC | 0 | 0.294687357515 | 7.7455379527 | 0 |
| 141 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 2048 | Partial FFT+FEC | 0 | 0.299477408222 | 9.98844338288 | 0 |
| 142 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 1024 | Partial FFT+FEC | 0 | 0.301165392528 | 3.05803157435 | 0 |
| 143 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 2048 | JUNA-WCz | 0 | 0.308894627612 | 31.1517261194 | 0 |
| 144 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 2048 | JUNA-Wz | 0 | 0.308904454192 | 171.934312399 | 0 |
| 145 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 2048 | JUNA-WCz | 0 | 0.312679271199 | 39.3469556419 | 0 |
| 146 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 2048 | JUNA-Wz | 0 | 0.312803354283 | 224.758824982 | 0 |
| 147 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 1024 | JUNA-Lite | 0 | 0.313049365753 | 11.5641196947 | 0 |
| 148 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 1024 | JUNA-Wz | 0 | 0.315011789232 | 66.159341857 | 0 |
| 149 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 1024 | JUNA-WCz | 0 | 0.315137073314 | 13.0236758842 | 0 |
| 150 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 512 | JUNA-Lite | 0.0109510086455 | 0.315297790586 | 8.1181322755 | 19.0828247602 |
| 151 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 512 | JUNA-Lite | 0 | 0.319658295595 | 4.80404575159 | 0 |
| 152 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 1024 | Partial FFT+FEC | 0 | 0.320341716948 | 3.42625905675 | 0 |
| 153 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 512 | Partial FFT+FEC | 0 | 0.328851893783 | 1.43443579942 | 0 |
| 154 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 1024 | JUNA-Wz | 0 | 0.333140171655 | 75.5884382679 | 0 |
| 155 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 1024 | JUNA-WCz | 0 | 0.333172033375 | 14.9593427151 | 0 |
| 156 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 1024 | JUNA-Lite | 0 | 0.33416601294 | 13.9932235653 | 0 |
| 157 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 512 | JUNA-WCz | 0 | 0.339687114039 | 6.30439457464 | 0 |
| 158 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.75 | 1/2 | 512 | JUNA-Wz | 0 | 0.339777171676 | 28.9113224836 | 0 |
| 159 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 512 | JUNA-Lite | 0 | 0.343546508063 | 5.19333686455 | 0 |
| 160 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 1024 | Partial FFT+FEC | 0 | 0.346203346203 | 4.11883381044 | 0 |
| 161 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 512 | JUNA-Lite | 0.000576368876081 | 0.350570365034 | 7.85544896023 | 2.00871839582 |
| 162 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 512 | Partial FFT+FEC | 0 | 0.35150530382 | 1.55191283977 | 0 |
| 163 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 512 | JUNA-Lite | 0 | 0.354427833814 | 7.42422103689 | 0 |
| 164 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 1024 | JUNA-WCz | 0 | 0.357752758434 | 16.4386491237 | 0 |
| 165 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 1024 | JUNA-Wz | 0 | 0.357781975262 | 93.9357924915 | 0 |
| 166 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 512 | JUNA-WCz | 0 | 0.363553865964 | 6.65746846167 | 0 |
| 167 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.50 | 1/2 | 512 | JUNA-Wz | 0 | 0.363623357247 | 32.6701658928 | 0 |
| 168 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 512 | Partial FFT+FEC | 0 | 0.371721902017 | 2.30139979654 | 0 |
| 169 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 512 | JUNA-WCz | 0.0109510086455 | 0.378506243996 | 9.37670191066 | 19.0828247602 |
| 170 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/16 | 512 | JUNA-Wz | 0.0109510086455 | 0.378542267051 | 50.1300484634 | 19.0828247602 |
| 171 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 512 | Partial FFT+FEC | 0 | 0.381766330451 | 2.24740596196 | 0 |
| 172 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 512 | Partial FFT+FEC | 0 | 0.383132204611 | 2.16388865821 | 0 |
| 173 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 512 | JUNA-WCz | 0 | 0.395986431316 | 8.78091495159 | 0 |
| 174 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/4 | 512 | JUNA-Wz | 0 | 0.396082492795 | 46.9013126444 | 0 |
| 175 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 512 | JUNA-WCz | 0.000576368876081 | 0.396541786744 | 9.05199706571 | 2.00871839582 |
| 176 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/8 | 512 | JUNA-Wz | 0.000576368876081 | 0.396571805956 | 47.6431040219 | 2.00871839582 |
| 177 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 512 | JUNA-Lite | 0 | 0.416210187507 | 6.52844265648 | 0 |
| 178 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 512 | Partial FFT+FEC | 0 | 0.429248100603 | 1.85929185937 | 0 |
| 179 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 512 | JUNA-Wz | 0 | 0.435020771735 | 40.2954399781 | 0 |
| 180 | [`0a2d927`](https://github.com/GabrielARL/JunaCore.jl/commit/0a2d9275775853c709f84102c02f23f6907891a3) | 0.25 | 1/2 | 512 | JUNA-WCz | 0 | 0.435077660092 | 7.54362479769 | 0 |
