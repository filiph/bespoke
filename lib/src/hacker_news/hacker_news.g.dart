// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hacker_news.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fetchHackerNewsHash() => r'453f09a9b4be4a97ceb70afdb85f541d615fc2e4';

/// See also [fetchHackerNews].
@ProviderFor(fetchHackerNews)
final fetchHackerNewsProvider = AutoDisposeFutureProvider<List<Story>>.internal(
  fetchHackerNews,
  name: r'fetchHackerNewsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fetchHackerNewsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FetchHackerNewsRef = AutoDisposeFutureProviderRef<List<Story>>;
String _$slowCounterHash() => r'8c038f9641ec7fb7a3a7dd4383d23f68133fe861';

/// See also [slowCounter].
@ProviderFor(slowCounter)
final slowCounterProvider = AutoDisposeStreamProvider<int>.internal(
  slowCounter,
  name: r'slowCounterProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$slowCounterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SlowCounterRef = AutoDisposeStreamProviderRef<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
