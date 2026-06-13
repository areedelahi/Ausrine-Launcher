// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'launcher.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LaunchEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is LaunchEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'LaunchEvent()';
  }
}

/// @nodoc
class $LaunchEventCopyWith<$Res> {
  $LaunchEventCopyWith(LaunchEvent _, $Res Function(LaunchEvent) __);
}

/// Adds pattern-matching-related methods to [LaunchEvent].
extension LaunchEventPatterns on LaunchEvent {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(LaunchEvent_Started value)? started,
    TResult Function(LaunchEvent_Exited value)? exited,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started() when started != null:
        return started(_that);
      case LaunchEvent_Exited() when exited != null:
        return exited(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(LaunchEvent_Started value) started,
    required TResult Function(LaunchEvent_Exited value) exited,
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started():
        return started(_that);
      case LaunchEvent_Exited():
        return exited(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(LaunchEvent_Started value)? started,
    TResult? Function(LaunchEvent_Exited value)? exited,
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started() when started != null:
        return started(_that);
      case LaunchEvent_Exited() when exited != null:
        return exited(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int pid)? started,
    TResult Function(int code)? exited,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started() when started != null:
        return started(_that.pid);
      case LaunchEvent_Exited() when exited != null:
        return exited(_that.code);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int pid) started,
    required TResult Function(int code) exited,
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started():
        return started(_that.pid);
      case LaunchEvent_Exited():
        return exited(_that.code);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int pid)? started,
    TResult? Function(int code)? exited,
  }) {
    final _that = this;
    switch (_that) {
      case LaunchEvent_Started() when started != null:
        return started(_that.pid);
      case LaunchEvent_Exited() when exited != null:
        return exited(_that.code);
      case _:
        return null;
    }
  }
}

/// @nodoc

class LaunchEvent_Started extends LaunchEvent {
  const LaunchEvent_Started({required this.pid}) : super._();

  final int pid;

  /// Create a copy of LaunchEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LaunchEvent_StartedCopyWith<LaunchEvent_Started> get copyWith =>
      _$LaunchEvent_StartedCopyWithImpl<LaunchEvent_Started>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LaunchEvent_Started &&
            (identical(other.pid, pid) || other.pid == pid));
  }

  @override
  int get hashCode => Object.hash(runtimeType, pid);

  @override
  String toString() {
    return 'LaunchEvent.started(pid: $pid)';
  }
}

/// @nodoc
abstract mixin class $LaunchEvent_StartedCopyWith<$Res>
    implements $LaunchEventCopyWith<$Res> {
  factory $LaunchEvent_StartedCopyWith(
          LaunchEvent_Started value, $Res Function(LaunchEvent_Started) _then) =
      _$LaunchEvent_StartedCopyWithImpl;
  @useResult
  $Res call({int pid});
}

/// @nodoc
class _$LaunchEvent_StartedCopyWithImpl<$Res>
    implements $LaunchEvent_StartedCopyWith<$Res> {
  _$LaunchEvent_StartedCopyWithImpl(this._self, this._then);

  final LaunchEvent_Started _self;
  final $Res Function(LaunchEvent_Started) _then;

  /// Create a copy of LaunchEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? pid = null,
  }) {
    return _then(LaunchEvent_Started(
      pid: null == pid
          ? _self.pid
          : pid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class LaunchEvent_Exited extends LaunchEvent {
  const LaunchEvent_Exited({required this.code}) : super._();

  final int code;

  /// Create a copy of LaunchEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LaunchEvent_ExitedCopyWith<LaunchEvent_Exited> get copyWith =>
      _$LaunchEvent_ExitedCopyWithImpl<LaunchEvent_Exited>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LaunchEvent_Exited &&
            (identical(other.code, code) || other.code == code));
  }

  @override
  int get hashCode => Object.hash(runtimeType, code);

  @override
  String toString() {
    return 'LaunchEvent.exited(code: $code)';
  }
}

/// @nodoc
abstract mixin class $LaunchEvent_ExitedCopyWith<$Res>
    implements $LaunchEventCopyWith<$Res> {
  factory $LaunchEvent_ExitedCopyWith(
          LaunchEvent_Exited value, $Res Function(LaunchEvent_Exited) _then) =
      _$LaunchEvent_ExitedCopyWithImpl;
  @useResult
  $Res call({int code});
}

/// @nodoc
class _$LaunchEvent_ExitedCopyWithImpl<$Res>
    implements $LaunchEvent_ExitedCopyWith<$Res> {
  _$LaunchEvent_ExitedCopyWithImpl(this._self, this._then);

  final LaunchEvent_Exited _self;
  final $Res Function(LaunchEvent_Exited) _then;

  /// Create a copy of LaunchEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? code = null,
  }) {
    return _then(LaunchEvent_Exited(
      code: null == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
