# Shared descriptors for cross-cutting public-boundary tests.
#
# Stage-specific suites should keep their purpose-built fixtures. Tests that
# claim to cover every public receiver must iterate this catalog so a new mode
# cannot silently join only some of the interface harness.

const PUBLIC_RECEIVER_DESCRIPTORS = (
    (name = "Standard OFDM", key = :standard, mode = :standard,
     profile = :standard, factory = JunaCore.Juna.StandardModulation,
     supports_bpsk = true, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "Partial-FFT", key = :pfft, mode = :pfft,
     profile = :pfft, factory = JunaCore.Juna.PartialFFTModulation,
     supports_bpsk = true, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "JUNA-Lite", key = :lite, mode = :lite,
     profile = :lite, factory = JunaCore.Juna.LiteModulation,
     supports_bpsk = true, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "JUNA-Wz", key = :full, mode = :full,
     profile = :full, factory = JunaCore.Juna.FullModulation,
     supports_bpsk = false, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "JUNA-WCz", key = :coupled, mode = :coupled,
     profile = :coupled, factory = JunaCore.Juna.CoupledModulation,
     supports_bpsk = false, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "JUNA Frame-wide LDPC", key = :frame_wide_ldpc,
     mode = :frame_wide_ldpc, profile = :frame_wide_ldpc,
     factory = JunaCore.Juna.FrameWideLDPCModulation,
     supports_bpsk = true, supports_lfm = true, supports_shifted_band = true,
     supports_synthetic_uwa = true),
    (name = "JUNA-FrameRLS", key = :frame_rls, mode = :frame_rls,
     profile = :frame_wide_ldpc, factory = JunaCore.JunaFrameRLS.Modulation,
     supports_bpsk = true, supports_lfm = false, supports_shifted_band = false,
     supports_synthetic_uwa = false),
)

public_receiver_descriptors() = PUBLIC_RECEIVER_DESCRIPTORS
public_receiver(descriptor; kwargs...) = descriptor.factory(; kwargs...)

function assert_public_receiver_catalog()
    runtime_modes = JunaCore.Juna._PUBLIC_RECEIVER_MODES
    descriptor_modes = Tuple(descriptor.mode for descriptor in
                                public_receiver_descriptors())

    @test length(unique(descriptor_modes)) == length(descriptor_modes)
    @test descriptor_modes == runtime_modes
    for descriptor in public_receiver_descriptors()
        receiver = public_receiver(descriptor)
        @test receiver.mode === descriptor.mode
        @test JunaCore.Juna.receiver_profile(receiver) === descriptor.profile
        @test (Int(receiver.bpc) == 1 && descriptor.supports_bpsk) ||
              Int(receiver.bpc) == 2
    end
end
