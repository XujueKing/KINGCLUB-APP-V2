// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_runtime.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mockRuntime)
final mockRuntimeProvider = MockRuntimeProvider._();

final class MockRuntimeProvider
    extends $FunctionalProvider<MockRuntime, MockRuntime, MockRuntime>
    with $Provider<MockRuntime> {
  MockRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mockRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mockRuntimeHash();

  @$internal
  @override
  $ProviderElement<MockRuntime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MockRuntime create(Ref ref) {
    return mockRuntime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MockRuntime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MockRuntime>(value),
    );
  }
}

String _$mockRuntimeHash() => r'a344e43a4db9bf8868480774bf6cc6c33d54e251';

@ProviderFor(bootstrapOutcome)
final bootstrapOutcomeProvider = BootstrapOutcomeProvider._();

final class BootstrapOutcomeProvider
    extends
        $FunctionalProvider<
          AsyncValue<BootstrapOutcome>,
          BootstrapOutcome,
          FutureOr<BootstrapOutcome>
        >
    with $FutureModifier<BootstrapOutcome>, $FutureProvider<BootstrapOutcome> {
  BootstrapOutcomeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapOutcomeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapOutcomeHash();

  @$internal
  @override
  $FutureProviderElement<BootstrapOutcome> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BootstrapOutcome> create(Ref ref) {
    return bootstrapOutcome(ref);
  }
}

String _$bootstrapOutcomeHash() => r'b3ab105c2aab14770ed4cbaaab3333f07e6a8675';
