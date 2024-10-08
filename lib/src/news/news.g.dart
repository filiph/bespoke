// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$slowCounterHash() => r'5035bfda528fa7731dfea269fbc9f444a7237b2b';

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
String _$fetchNewsHash() => r'94bc0ed33d92efe29c0e9ea4bba7930b007f1aec';

/// See also [fetchNews].
@ProviderFor(fetchNews)
final fetchNewsProvider = AutoDisposeFutureProvider<List<NewsItem>>.internal(
  fetchNews,
  name: r'fetchNewsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$fetchNewsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FetchNewsRef = AutoDisposeFutureProviderRef<List<NewsItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
