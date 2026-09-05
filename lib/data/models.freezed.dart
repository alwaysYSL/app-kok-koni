// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Club {

 String get id; String get name; String get sport; String get village; bool get active;
/// Create a copy of Club
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClubCopyWith<Club> get copyWith => _$ClubCopyWithImpl<Club>(this as Club, _$identity);

  /// Serializes this Club to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Club&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.village, village) || other.village == village)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sport,village,active);

@override
String toString() {
  return 'Club(id: $id, name: $name, sport: $sport, village: $village, active: $active)';
}


}

/// @nodoc
abstract mixin class $ClubCopyWith<$Res>  {
  factory $ClubCopyWith(Club value, $Res Function(Club) _then) = _$ClubCopyWithImpl;
@useResult
$Res call({
 String id, String name, String sport, String village, bool active
});




}
/// @nodoc
class _$ClubCopyWithImpl<$Res>
    implements $ClubCopyWith<$Res> {
  _$ClubCopyWithImpl(this._self, this._then);

  final Club _self;
  final $Res Function(Club) _then;

/// Create a copy of Club
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sport = null,Object? village = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as String,village: null == village ? _self.village : village // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Club].
extension ClubPatterns on Club {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Club value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Club value)  $default,){
final _that = this;
switch (_that) {
case _Club():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Club value)?  $default,){
final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String sport,  String village,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String sport,  String village,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Club():
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String sport,  String village,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Club implements Club {
  const _Club({required this.id, required this.name, required this.sport, required this.village, this.active = true});
  factory _Club.fromJson(Map<String, dynamic> json) => _$ClubFromJson(json);

@override final  String id;
@override final  String name;
@override final  String sport;
@override final  String village;
@override@JsonKey() final  bool active;

/// Create a copy of Club
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClubCopyWith<_Club> get copyWith => __$ClubCopyWithImpl<_Club>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClubToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Club&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.village, village) || other.village == village)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sport,village,active);

@override
String toString() {
  return 'Club(id: $id, name: $name, sport: $sport, village: $village, active: $active)';
}


}

/// @nodoc
abstract mixin class _$ClubCopyWith<$Res> implements $ClubCopyWith<$Res> {
  factory _$ClubCopyWith(_Club value, $Res Function(_Club) _then) = __$ClubCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String sport, String village, bool active
});




}
/// @nodoc
class __$ClubCopyWithImpl<$Res>
    implements _$ClubCopyWith<$Res> {
  __$ClubCopyWithImpl(this._self, this._then);

  final _Club _self;
  final $Res Function(_Club) _then;

/// Create a copy of Club
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sport = null,Object? village = null,Object? active = null,}) {
  return _then(_Club(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as String,village: null == village ? _self.village : village // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SportPerson {

 String get id; String get name; String get clubId; String get role; String get group; bool get verified; bool get expiredLicense; List<String> get missingDocuments;
/// Create a copy of SportPerson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SportPersonCopyWith<SportPerson> get copyWith => _$SportPersonCopyWithImpl<SportPerson>(this as SportPerson, _$identity);

  /// Serializes this SportPerson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SportPerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clubId, clubId) || other.clubId == clubId)&&(identical(other.role, role) || other.role == role)&&(identical(other.group, group) || other.group == group)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.expiredLicense, expiredLicense) || other.expiredLicense == expiredLicense)&&const DeepCollectionEquality().equals(other.missingDocuments, missingDocuments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clubId,role,group,verified,expiredLicense,const DeepCollectionEquality().hash(missingDocuments));

@override
String toString() {
  return 'SportPerson(id: $id, name: $name, clubId: $clubId, role: $role, group: $group, verified: $verified, expiredLicense: $expiredLicense, missingDocuments: $missingDocuments)';
}


}

/// @nodoc
abstract mixin class $SportPersonCopyWith<$Res>  {
  factory $SportPersonCopyWith(SportPerson value, $Res Function(SportPerson) _then) = _$SportPersonCopyWithImpl;
@useResult
$Res call({
 String id, String name, String clubId, String role, String group, bool verified, bool expiredLicense, List<String> missingDocuments
});




}
/// @nodoc
class _$SportPersonCopyWithImpl<$Res>
    implements $SportPersonCopyWith<$Res> {
  _$SportPersonCopyWithImpl(this._self, this._then);

  final SportPerson _self;
  final $Res Function(SportPerson) _then;

/// Create a copy of SportPerson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? clubId = null,Object? role = null,Object? group = null,Object? verified = null,Object? expiredLicense = null,Object? missingDocuments = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clubId: null == clubId ? _self.clubId : clubId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,expiredLicense: null == expiredLicense ? _self.expiredLicense : expiredLicense // ignore: cast_nullable_to_non_nullable
as bool,missingDocuments: null == missingDocuments ? _self.missingDocuments : missingDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SportPerson].
extension SportPersonPatterns on SportPerson {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SportPerson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SportPerson value)  $default,){
final _that = this;
switch (_that) {
case _SportPerson():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SportPerson value)?  $default,){
final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments)  $default,) {final _that = this;
switch (_that) {
case _SportPerson():
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments)?  $default,) {final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SportPerson implements SportPerson {
  const _SportPerson({required this.id, required this.name, required this.clubId, required this.role, required this.group, this.verified = true, this.expiredLicense = false, final  List<String> missingDocuments = const <String>[]}): _missingDocuments = missingDocuments;
  factory _SportPerson.fromJson(Map<String, dynamic> json) => _$SportPersonFromJson(json);

@override final  String id;
@override final  String name;
@override final  String clubId;
@override final  String role;
@override final  String group;
@override@JsonKey() final  bool verified;
@override@JsonKey() final  bool expiredLicense;
 final  List<String> _missingDocuments;
@override@JsonKey() List<String> get missingDocuments {
  if (_missingDocuments is EqualUnmodifiableListView) return _missingDocuments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_missingDocuments);
}


/// Create a copy of SportPerson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SportPersonCopyWith<_SportPerson> get copyWith => __$SportPersonCopyWithImpl<_SportPerson>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SportPersonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SportPerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clubId, clubId) || other.clubId == clubId)&&(identical(other.role, role) || other.role == role)&&(identical(other.group, group) || other.group == group)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.expiredLicense, expiredLicense) || other.expiredLicense == expiredLicense)&&const DeepCollectionEquality().equals(other._missingDocuments, _missingDocuments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clubId,role,group,verified,expiredLicense,const DeepCollectionEquality().hash(_missingDocuments));

@override
String toString() {
  return 'SportPerson(id: $id, name: $name, clubId: $clubId, role: $role, group: $group, verified: $verified, expiredLicense: $expiredLicense, missingDocuments: $missingDocuments)';
}


}

/// @nodoc
abstract mixin class _$SportPersonCopyWith<$Res> implements $SportPersonCopyWith<$Res> {
  factory _$SportPersonCopyWith(_SportPerson value, $Res Function(_SportPerson) _then) = __$SportPersonCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String clubId, String role, String group, bool verified, bool expiredLicense, List<String> missingDocuments
});




}
/// @nodoc
class __$SportPersonCopyWithImpl<$Res>
    implements _$SportPersonCopyWith<$Res> {
  __$SportPersonCopyWithImpl(this._self, this._then);

  final _SportPerson _self;
  final $Res Function(_SportPerson) _then;

/// Create a copy of SportPerson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? clubId = null,Object? role = null,Object? group = null,Object? verified = null,Object? expiredLicense = null,Object? missingDocuments = null,}) {
  return _then(_SportPerson(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clubId: null == clubId ? _self.clubId : clubId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,expiredLicense: null == expiredLicense ? _self.expiredLicense : expiredLicense // ignore: cast_nullable_to_non_nullable
as bool,missingDocuments: null == missingDocuments ? _self._missingDocuments : missingDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$CommitteeMember {

 String get id; String get name; String get position; String get division; String get period;
/// Create a copy of CommitteeMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitteeMemberCopyWith<CommitteeMember> get copyWith => _$CommitteeMemberCopyWithImpl<CommitteeMember>(this as CommitteeMember, _$identity);

  /// Serializes this CommitteeMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitteeMember&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.division, division) || other.division == division)&&(identical(other.period, period) || other.period == period));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,position,division,period);

@override
String toString() {
  return 'CommitteeMember(id: $id, name: $name, position: $position, division: $division, period: $period)';
}


}

/// @nodoc
abstract mixin class $CommitteeMemberCopyWith<$Res>  {
  factory $CommitteeMemberCopyWith(CommitteeMember value, $Res Function(CommitteeMember) _then) = _$CommitteeMemberCopyWithImpl;
@useResult
$Res call({
 String id, String name, String position, String division, String period
});




}
/// @nodoc
class _$CommitteeMemberCopyWithImpl<$Res>
    implements $CommitteeMemberCopyWith<$Res> {
  _$CommitteeMemberCopyWithImpl(this._self, this._then);

  final CommitteeMember _self;
  final $Res Function(CommitteeMember) _then;

/// Create a copy of CommitteeMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? position = null,Object? division = null,Object? period = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,division: null == division ? _self.division : division // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CommitteeMember].
extension CommitteeMemberPatterns on CommitteeMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitteeMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitteeMember value)  $default,){
final _that = this;
switch (_that) {
case _CommitteeMember():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitteeMember value)?  $default,){
final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String position,  String division,  String period)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that.id,_that.name,_that.position,_that.division,_that.period);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String position,  String division,  String period)  $default,) {final _that = this;
switch (_that) {
case _CommitteeMember():
return $default(_that.id,_that.name,_that.position,_that.division,_that.period);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String position,  String division,  String period)?  $default,) {final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that.id,_that.name,_that.position,_that.division,_that.period);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommitteeMember implements CommitteeMember {
  const _CommitteeMember({required this.id, required this.name, required this.position, required this.division, this.period = '2025–2029'});
  factory _CommitteeMember.fromJson(Map<String, dynamic> json) => _$CommitteeMemberFromJson(json);

@override final  String id;
@override final  String name;
@override final  String position;
@override final  String division;
@override@JsonKey() final  String period;

/// Create a copy of CommitteeMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitteeMemberCopyWith<_CommitteeMember> get copyWith => __$CommitteeMemberCopyWithImpl<_CommitteeMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommitteeMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitteeMember&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.division, division) || other.division == division)&&(identical(other.period, period) || other.period == period));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,position,division,period);

@override
String toString() {
  return 'CommitteeMember(id: $id, name: $name, position: $position, division: $division, period: $period)';
}


}

/// @nodoc
abstract mixin class _$CommitteeMemberCopyWith<$Res> implements $CommitteeMemberCopyWith<$Res> {
  factory _$CommitteeMemberCopyWith(_CommitteeMember value, $Res Function(_CommitteeMember) _then) = __$CommitteeMemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String position, String division, String period
});




}
/// @nodoc
class __$CommitteeMemberCopyWithImpl<$Res>
    implements _$CommitteeMemberCopyWith<$Res> {
  __$CommitteeMemberCopyWithImpl(this._self, this._then);

  final _CommitteeMember _self;
  final $Res Function(_CommitteeMember) _then;

/// Create a copy of CommitteeMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? position = null,Object? division = null,Object? period = null,}) {
  return _then(_CommitteeMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,division: null == division ? _self.division : division // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$KokSnapshot {

 List<Club> get clubs; List<SportPerson> get people; List<CommitteeMember> get committee; DateTime get loadedAt;
/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KokSnapshotCopyWith<KokSnapshot> get copyWith => _$KokSnapshotCopyWithImpl<KokSnapshot>(this as KokSnapshot, _$identity);

  /// Serializes this KokSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KokSnapshot&&const DeepCollectionEquality().equals(other.clubs, clubs)&&const DeepCollectionEquality().equals(other.people, people)&&const DeepCollectionEquality().equals(other.committee, committee)&&(identical(other.loadedAt, loadedAt) || other.loadedAt == loadedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(clubs),const DeepCollectionEquality().hash(people),const DeepCollectionEquality().hash(committee),loadedAt);

@override
String toString() {
  return 'KokSnapshot(clubs: $clubs, people: $people, committee: $committee, loadedAt: $loadedAt)';
}


}

/// @nodoc
abstract mixin class $KokSnapshotCopyWith<$Res>  {
  factory $KokSnapshotCopyWith(KokSnapshot value, $Res Function(KokSnapshot) _then) = _$KokSnapshotCopyWithImpl;
@useResult
$Res call({
 List<Club> clubs, List<SportPerson> people, List<CommitteeMember> committee, DateTime loadedAt
});




}
/// @nodoc
class _$KokSnapshotCopyWithImpl<$Res>
    implements $KokSnapshotCopyWith<$Res> {
  _$KokSnapshotCopyWithImpl(this._self, this._then);

  final KokSnapshot _self;
  final $Res Function(KokSnapshot) _then;

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clubs = null,Object? people = null,Object? committee = null,Object? loadedAt = null,}) {
  return _then(_self.copyWith(
clubs: null == clubs ? _self.clubs : clubs // ignore: cast_nullable_to_non_nullable
as List<Club>,people: null == people ? _self.people : people // ignore: cast_nullable_to_non_nullable
as List<SportPerson>,committee: null == committee ? _self.committee : committee // ignore: cast_nullable_to_non_nullable
as List<CommitteeMember>,loadedAt: null == loadedAt ? _self.loadedAt : loadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [KokSnapshot].
extension KokSnapshotPatterns on KokSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KokSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KokSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _KokSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KokSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that.clubs,_that.people,_that.committee,_that.loadedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt)  $default,) {final _that = this;
switch (_that) {
case _KokSnapshot():
return $default(_that.clubs,_that.people,_that.committee,_that.loadedAt);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt)?  $default,) {final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that.clubs,_that.people,_that.committee,_that.loadedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KokSnapshot implements KokSnapshot {
  const _KokSnapshot({required final  List<Club> clubs, required final  List<SportPerson> people, required final  List<CommitteeMember> committee, required this.loadedAt}): _clubs = clubs,_people = people,_committee = committee;
  factory _KokSnapshot.fromJson(Map<String, dynamic> json) => _$KokSnapshotFromJson(json);

 final  List<Club> _clubs;
@override List<Club> get clubs {
  if (_clubs is EqualUnmodifiableListView) return _clubs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clubs);
}

 final  List<SportPerson> _people;
@override List<SportPerson> get people {
  if (_people is EqualUnmodifiableListView) return _people;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_people);
}

 final  List<CommitteeMember> _committee;
@override List<CommitteeMember> get committee {
  if (_committee is EqualUnmodifiableListView) return _committee;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_committee);
}

@override final  DateTime loadedAt;

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KokSnapshotCopyWith<_KokSnapshot> get copyWith => __$KokSnapshotCopyWithImpl<_KokSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KokSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KokSnapshot&&const DeepCollectionEquality().equals(other._clubs, _clubs)&&const DeepCollectionEquality().equals(other._people, _people)&&const DeepCollectionEquality().equals(other._committee, _committee)&&(identical(other.loadedAt, loadedAt) || other.loadedAt == loadedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_clubs),const DeepCollectionEquality().hash(_people),const DeepCollectionEquality().hash(_committee),loadedAt);

@override
String toString() {
  return 'KokSnapshot(clubs: $clubs, people: $people, committee: $committee, loadedAt: $loadedAt)';
}


}

/// @nodoc
abstract mixin class _$KokSnapshotCopyWith<$Res> implements $KokSnapshotCopyWith<$Res> {
  factory _$KokSnapshotCopyWith(_KokSnapshot value, $Res Function(_KokSnapshot) _then) = __$KokSnapshotCopyWithImpl;
@override @useResult
$Res call({
 List<Club> clubs, List<SportPerson> people, List<CommitteeMember> committee, DateTime loadedAt
});




}
/// @nodoc
class __$KokSnapshotCopyWithImpl<$Res>
    implements _$KokSnapshotCopyWith<$Res> {
  __$KokSnapshotCopyWithImpl(this._self, this._then);

  final _KokSnapshot _self;
  final $Res Function(_KokSnapshot) _then;

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clubs = null,Object? people = null,Object? committee = null,Object? loadedAt = null,}) {
  return _then(_KokSnapshot(
clubs: null == clubs ? _self._clubs : clubs // ignore: cast_nullable_to_non_nullable
as List<Club>,people: null == people ? _self._people : people // ignore: cast_nullable_to_non_nullable
as List<SportPerson>,committee: null == committee ? _self._committee : committee // ignore: cast_nullable_to_non_nullable
as List<CommitteeMember>,loadedAt: null == loadedAt ? _self.loadedAt : loadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
