#!/usr/bin/env julia
#
# LDPC code construction/cache - helper binaries, matrix shape, Tanner graph, and GF(2) parity.
#
# Paper claims protected (papers/main.tex):
#   packet Tanner example (lines 670-679)  The reference frame uses an LDPC code
#                                         with k=340 message bits and n=1360 coded
#                                         bits at rate 0.25.
#   decoder feedback (sec:solver line 843) BP and JUNA refinements are only
#                                         meaningful if the parity-check graph is
#                                         the same graph used by the encoder.
#   config string (1966-1971)              The package-side construction pins
#                                         ldpc_npc=3 and method "evencol"; the
#                                         paper string names dc4, a known
#                                         parameterization difference documented
#                                         in test/README.md.
#
# If this fails: the later framing, BP, and JUNA tests are testing on an invalid
# code graph, stale LDPC cache, or non-vendored helper tools.
#
# Run alone:  julia --project=. test/ldpc_code_construction.jl
# Via runner: julia --project=. test/runtests.jl ldpc

using Test
using JunaCore

const LDPCConstructionJuna = JunaCore.Juna
const LDPCConstructionLDPC = JunaCore.LDPC
const LDPCConstructionRoot = normpath(joinpath(@__DIR__, ".."))

gf2_syndrome(H::AbstractMatrix{Bool}, codeword::AbstractVector{Bool}) =
    mod.(Int.(H) * Int.(codeword), 2)

function assert_tanner_graph_matches_matrix(code)
    @test length(code.check_vars) == size(code.H, 1)
    @test length(code.var_edges) == size(code.H, 2)
    @test all(!isempty, code.check_vars)
    @test all(!isempty, code.var_edges)

    for row in axes(code.H, 1)
        expected = findall(@view code.H[row, :])
        @test code.check_vars[row] == expected
        for (local_index, var) in enumerate(expected)
            @test (row, local_index) in code.var_edges[var]
        end
    end

    for var in eachindex(code.var_edges)
        for (row, local_index) in code.var_edges[var]
            @test 1 <= row <= size(code.H, 1)
            @test 1 <= local_index <= length(code.check_vars[row])
            @test code.check_vars[row][local_index] == var
            @test code.H[row, var]
        end
    end
end

function assert_codewords_satisfy_parity(code)
    messages = (
        falses(code.k),
        trues(code.k),
        Bool[isodd(i) for i in 1:code.k],
        Bool[isodd(count_ones(i)) for i in 1:code.k],
    )

    for bits in messages
        codeword = LDPCConstructionJuna._encode(code, bits)
        @test codeword isa Vector{Bool}
        @test length(codeword) == code.n
        @test all(gf2_syndrome(code.H, codeword) .== 0)
    end
end

@testset verbose = true "JUNA LDPC code construction/cache" begin
    @testset "vendored helper tools are resolved from tools/ldpc" begin
        for tool in ("make-ldpc", "make-gen", "print-pchk")
            expected = joinpath(LDPCConstructionRoot, "tools", "ldpc", tool)
            resolved = normpath(LDPCConstructionLDPC._tool(tool))
            @test resolved == expected
            @test isfile(resolved)
            @test filesize(resolved) > 0
        end
    end

    @testset "low-level LDPC parsers reject/parse known files" begin
        mktempdir() do dir
            htxt = joinpath(dir, "toy.H")
            write(htxt, """
                  0: 0 2
                  1: 1
                  ignored line
                  """)
            H = LDPCConstructionLDPC.read_H(htxt, 2, 3)
            @test H isa BitMatrix
            @test Matrix{Bool}(H) == Bool[true false true; false true false]

            bad_generator = joinpath(dir, "bad.gen")
            open(bad_generator, "w") do io
                write(io, UInt32(0))
            end
            @test_throws ErrorException LDPCConstructionLDPC.generator(bad_generator)
        end
    end

    @testset "paper-default code dimensions and permutations are sane" begin
        m = LDPCConstructionJuna.LiteModulation()
        code = LDPCConstructionJuna._code(m)

        @test code.k == 340
        @test code.n == 1360
        @test code.npc == 3
        @test code.method == "evencol"
        @test code.H isa Matrix{Bool}
        @test code.gen isa BitMatrix
        @test size(code.H) == (1020, 1360)
        @test size(code.gen) == (1020, 340)

        @test length(code.icols) == code.n
        @test length(code.invperm) == code.n
        @test sort(code.icols) == collect(1:code.n)
        @test sort(code.invperm) == collect(1:code.n)
        @test code.icols[code.invperm] == collect(1:code.n)
        @test code.invperm[code.icols] == collect(1:code.n)

        assert_tanner_graph_matches_matrix(code)
        assert_codewords_satisfy_parity(code)
    end

    @testset "_code cache reuses matching codes and resets BP scratch on spec change" begin
        m = LDPCConstructionJuna.LiteModulation(ldpc_k = 32, ldpc_n = 64, ldpc_npc = 2)
        first = LDPCConstructionJuna._code(m)
        stale_bp = (; sentinel = :stale)
        m.bp_scratch = stale_bp

        @test LDPCConstructionJuna._code(m) === first
        @test m.bp_scratch === stale_bp

        m.ldpc_npc = 3
        second = LDPCConstructionJuna._code(m)
        @test second !== first
        @test second.k == 32
        @test second.n == 64
        @test second.npc == 3
        @test second.method == "evencol"
        @test size(second.H) == (32, 64)
        @test size(second.gen) == (32, 32)
        @test m.bp_scratch === nothing

        assert_tanner_graph_matches_matrix(second)
        assert_codewords_satisfy_parity(second)
    end

    @testset "impossible LDPC specifications fail as modem argument errors" begin
        @test_throws ArgumentError LDPCConstructionJuna._create_code(679, 680, 3, "evencol")
        @test_throws ArgumentError LDPCConstructionJuna._create_code(32, 64, 0, "evencol")

        helper_error = try
            LDPCConstructionJuna._create_code(8, 16, 2, "not-a-method")
            nothing
        catch err
            err
        end
        @test helper_error isa ArgumentError
        @test occursin("failed to construct LDPC", sprint(showerror, helper_error))
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA LDPC code construction/cache checks passed")
end
