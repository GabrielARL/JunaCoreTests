# Shared descriptors for cross-cutting public-boundary tests.
#
# Stage-specific suites should keep their purpose-built fixtures. Tests that
# claim to cover every public receiver must iterate this catalog so a new mode
# cannot silently join only some of the interface harness.

const PUBLIC_RECEIVER_DESCRIPTORS = (
    (name = "Standard OFDM", profile = :standard,
     factory = JunaCore.Juna.StandardModulation, supports_bpsk = true),
    (name = "Partial-FFT", profile = :pfft,
     factory = JunaCore.Juna.PartialFFTModulation, supports_bpsk = true),
    (name = "JUNA-Lite", profile = :lite,
     factory = JunaCore.Juna.LiteModulation, supports_bpsk = true),
    (name = "JUNA-Wz", profile = :full,
     factory = JunaCore.Juna.FullModulation, supports_bpsk = false),
    (name = "JUNA-WCz", profile = :coupled,
     factory = JunaCore.Juna.CoupledModulation, supports_bpsk = false),
    (name = "JUNA Frame-wide LDPC", profile = :frame_wide_ldpc,
     factory = JunaCore.Juna.FrameWideLDPCModulation, supports_bpsk = true),
)

public_receiver_descriptors() = PUBLIC_RECEIVER_DESCRIPTORS
public_receiver(descriptor; kwargs...) = descriptor.factory(; kwargs...)

function assert_public_receiver_catalog()
    runtime_profiles = JunaCore.Juna._RECEIVER_PROFILES
    descriptor_profiles = Tuple(descriptor.profile for descriptor in
                                public_receiver_descriptors())

    @test length(unique(descriptor_profiles)) == length(descriptor_profiles)
    @test descriptor_profiles == runtime_profiles
    for descriptor in public_receiver_descriptors()
        receiver = public_receiver(descriptor)
        @test JunaCore.Juna.receiver_profile(receiver) === descriptor.profile
        @test (Int(receiver.bpc) == 1 && descriptor.supports_bpsk) ||
              Int(receiver.bpc) == 2
    end
end
