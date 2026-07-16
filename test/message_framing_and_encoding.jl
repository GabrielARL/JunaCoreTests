#!/usr/bin/env julia
#
# Message framing and LDPC encoding - payload bits, inner pilots, and systematic codeword mapping.
#
# Paper claims protected (papers/main.tex):
#   ssec:packet-tanner-example (lines 523-524)  Outer pilots are OFDM pilots;
#                                               inner pilots are known LDPC
#                                               message positions.
#   packet Tanner example (lines 670-679)        The reference frame uses k=340
#                                               message bits, 170 inner pilots,
#                                               and n=1360 coded bits.
#   eq:goodput (1934-1939)                      Payload accounting excludes
#                                               inner-pilot bits; only unknown
#                                               payload bits count.
#
# If this fails: payload bits may be placed into the wrong LDPC message slots,
# known inner pilots may be missing, or decoded metrics may be read back through
# the wrong systematic permutation.
#
# Run alone:  julia --project=. test/message_framing_and_encoding.jl
# Via runner: julia --project=. test/runtests.jl framing

using Test
using JunaCore

const MessageFramingJuna = JunaCore.Juna

function payload_pattern(n::Integer)
    Bool[isodd(count_ones(i)) for i in 1:n]
end

function non_inner_positions(m, code)
    isp = MessageFramingJuna._inner_pilot_spacing(m)
    [p for p in 1:code.k if !(isp >= 1 && (p - 1) % isp == 0)]
end

function assert_default_inner_pilot_layout(m, code, payload, message)
    data_positions = non_inner_positions(m, code)
    inner_positions = setdiff(1:code.k, data_positions)

    @test code.k == 340
    @test MessageFramingJuna._inner_pilot_spacing(m) == 2
    @test length(inner_positions) == 170
    @test length(data_positions) == 170
    @test inner_positions[1:6] == [1, 3, 5, 7, 9, 11]
    @test data_positions[1:6] == [2, 4, 6, 8, 10, 12]

    for p in inner_positions
        @test message[p] == MessageFramingJuna._inner_bit(p)
    end
    for (i, p) in enumerate(data_positions)
        expected = i <= length(payload) ? payload[i] : false
        @test message[p] == expected
    end
end

function metrics_for_message(code, message)
    mparity = code.n - code.k
    metrics = fill(-99.0, code.n)
    for p in 1:code.k
        metrics[code.invperm[mparity + p]] = message[p] ? 7.0 : -7.0
    end
    metrics
end

function expected_inner_positions(k::Integer, spacing::Integer)
    spacing == 0 ? Int[] : collect(1:Int(spacing):Int(k))
end

function assert_general_framing_case(m, code, payload)
    spacing = MessageFramingJuna._inner_pilot_spacing(m)
    inner_positions = expected_inner_positions(code.k, spacing)
    inner_set = Set(inner_positions)
    data_positions = [p for p in 1:code.k if p ∉ inner_set]
    capacity = length(data_positions)
    message = MessageFramingJuna._build_message(m, code, payload)

    @test length(message) == code.k
    @test length(inner_positions) == (spacing == 0 ? 0 : cld(code.k, spacing))
    @test capacity == code.k - length(inner_positions)
    @test MessageFramingJuna._n_inner(m, code.k) == length(inner_positions)
    @test all(p -> message[p] == MessageFramingJuna._inner_bit(p), inner_positions)
    @test message[data_positions[1:length(payload)]] == payload
    @test all(!, message[data_positions[length(payload)+1:end]])

    recovered = MessageFramingJuna._payload_from_metrics(
        m, code, metrics_for_message(code, message))
    @test recovered == vcat(payload, falses(capacity - length(payload)))
end

@testset verbose = true "JUNA message framing and LDPC encoding" begin
    @testset "default ip2 framing inserts 170 deterministic inner pilots" begin
        m = MessageFramingJuna.LiteModulation()
        code = MessageFramingJuna._code(m)
        payload = payload_pattern(170)
        message = MessageFramingJuna._build_message(m, code, payload)

        @test message isa AbstractVector{Bool}
        @test length(message) == 340
        assert_default_inner_pilot_layout(m, code, payload, message)
    end

    @testset "short final-block payload is zero-filled after the provided bits" begin
        m = MessageFramingJuna.LiteModulation()
        code = MessageFramingJuna._code(m)
        payload = Bool[true, false, true, true, false, false, true]
        message = MessageFramingJuna._build_message(m, code, payload)

        assert_default_inner_pilot_layout(m, code, payload, message)
        data_positions = non_inner_positions(m, code)
        @test message[data_positions[1:length(payload)]] == payload
        @test all(!, message[data_positions[length(payload)+1:end]])
    end

    @testset "inner pilots off: every LDPC message position carries payload" begin
        m = MessageFramingJuna.LiteModulation(inner_pilot_ratio = 0.0)
        code = MessageFramingJuna._code(m)
        payload = payload_pattern(340)
        message = MessageFramingJuna._build_message(m, code, payload)

        @test MessageFramingJuna._inner_pilot_spacing(m) == 0
        @test MessageFramingJuna._n_inner(m, code.k) == 0
        @test length(message) == 340
        @test message == payload
    end

    @testset "ip3 inner pilots pin a non-degenerate golden bit sequence" begin
        m = MessageFramingJuna.LiteModulation(inner_pilot_ratio = 1/3)
        code = MessageFramingJuna._code(m)
        payload = payload_pattern(226)
        message = MessageFramingJuna._build_message(m, code, payload)
        inner_positions = [p for p in 1:code.k if (p - 1) % 3 == 0]
        data_positions = setdiff(1:code.k, inner_positions)

        @test MessageFramingJuna._inner_pilot_spacing(m) == 3
        @test MessageFramingJuna._n_inner(m, code.k) == 114
        @test length(data_positions) == 226
        @test message[inner_positions[1:8]] ==
              Bool[false, true, false, true, false, true, false, true]
        @test any(message[inner_positions])
        @test any(!, message[inner_positions])
        @test message[data_positions] == payload
    end

    @testset "general framing matrix covers code sizes, pilot spacings, and payload boundaries" begin
        geometries = (
            (name = "paper k340/n1360", k = 340, n = 1360),
            (name = "compact k170/n680", k = 170, n = 680),
        )
        spacings = (0, 2, 3, 5, 8, 16)

        for geometry in geometries, spacing in spacings
            profile = spacing == 0 ? "off" : "ip$spacing"
            @testset "$(geometry.name) / $profile" begin
                ratio = spacing == 0 ? 0.0 : 1 / spacing
                m = MessageFramingJuna.LiteModulation(
                    ldpc_k = geometry.k, ldpc_n = geometry.n,
                    inner_pilot_ratio = ratio)
                code = MessageFramingJuna._code(m)
                inner_count = spacing == 0 ? 0 : cld(geometry.k, spacing)
                capacity = geometry.k - inner_count

                @test code.k == geometry.k
                @test code.n == geometry.n
                @test MessageFramingJuna._inner_pilot_spacing(m) == spacing
                for nbits in unique((0, 1, capacity ÷ 2, capacity))
                    assert_general_framing_case(m, code, payload_pattern(nbits))
                end
                @test_throws ArgumentError MessageFramingJuna._build_message(
                    m, code, payload_pattern(capacity + 1))

                full_payload = payload_pattern(capacity)
                full_message = MessageFramingJuna._build_message(m, code, full_payload)
                codeword = MessageFramingJuna._encode(code, full_message)
                mparity = code.n - code.k
                systematic_idx = code.invperm[mparity .+ collect(1:code.k)]
                @test codeword[systematic_idx] == full_message
                @test all(check -> iseven(count(v -> codeword[v], code.check_vars[check])),
                          eachindex(code.check_vars))
            end
        end
    end

    @testset "framing rejects too many payload bits for one LDPC message row" begin
        m = MessageFramingJuna.LiteModulation()
        code = MessageFramingJuna._code(m)
        @test_throws ArgumentError MessageFramingJuna._build_message(m, code, payload_pattern(171))
        @test_throws ArgumentError MessageFramingJuna._encode(code, payload_pattern(339))
        @test_throws ArgumentError MessageFramingJuna._encode(code, payload_pattern(341))
    end

    @testset "payload extraction skips inner-pilot message positions through the same permutation" begin
        m = MessageFramingJuna.LiteModulation()
        code = MessageFramingJuna._code(m)
        payload = payload_pattern(170)
        message = MessageFramingJuna._build_message(m, code, payload)
        metrics = metrics_for_message(code, message)

        recovered = MessageFramingJuna._payload_from_metrics(m, code, metrics)
        @test recovered isa Vector{Bool}
        @test recovered == payload

        out = fill(NaN, length(payload))
        pos = MessageFramingJuna._write_payload_metrics!(out, 1, m, code, metrics, length(payload))
        @test pos == length(payload) + 1
        @test all(isfinite, out)
        @test (out .> 0) == payload
    end

    @testset "LDPC encoding preserves framed message bits at systematic positions" begin
        m = MessageFramingJuna.LiteModulation()
        code = MessageFramingJuna._code(m)
        payload = payload_pattern(170)
        message = MessageFramingJuna._build_message(m, code, payload)
        codeword = MessageFramingJuna._encode(code, message)
        mparity = code.n - code.k

        @test codeword isa Vector{Bool}
        @test length(codeword) == 1360
        for p in 1:code.k
            @test codeword[code.invperm[mparity + p]] == message[p]
        end
        @test all(mod.(Int.(code.H) * Int.(codeword), 2) .== 0)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA message framing and LDPC encoding checks passed")
end
