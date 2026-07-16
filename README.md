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
