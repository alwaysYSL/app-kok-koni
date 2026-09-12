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
mixin _$ClubDocument {

 String get id; String get name; String get status; String? get fileUrl; DateTime? get uploadedAt; DateTime? get verifiedAt;
/// Create a copy of ClubDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClubDocumentCopyWith<ClubDocument> get copyWith => _$ClubDocumentCopyWithImpl<ClubDocument>(this as ClubDocument, _$identity);

  /// Serializes this ClubDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClubDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,fileUrl,uploadedAt,verifiedAt);

@override
String toString() {
  return 'ClubDocument(id: $id, name: $name, status: $status, fileUrl: $fileUrl, uploadedAt: $uploadedAt, verifiedAt: $verifiedAt)';
}


}

/// @nodoc
abstract mixin class $ClubDocumentCopyWith<$Res>  {
  factory $ClubDocumentCopyWith(ClubDocument value, $Res Function(ClubDocument) _then) = _$ClubDocumentCopyWithImpl;
@useResult
$Res call({
 String id, String name, String status, String? fileUrl, DateTime? uploadedAt, DateTime? verifiedAt
});




}
/// @nodoc
class _$ClubDocumentCopyWithImpl<$Res>
    implements $ClubDocumentCopyWith<$Res> {
  _$ClubDocumentCopyWithImpl(this._self, this._then);

  final ClubDocument _self;
  final $Res Function(ClubDocument) _then;

/// Create a copy of ClubDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? status = null,Object? fileUrl = freezed,Object? uploadedAt = freezed,Object? verifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fileUrl: freezed == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String?,uploadedAt: freezed == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClubDocument].
extension ClubDocumentPatterns on ClubDocument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClubDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClubDocument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClubDocument value)  $default,){
final _that = this;
switch (_that) {
case _ClubDocument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClubDocument value)?  $default,){
final _that = this;
switch (_that) {
case _ClubDocument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String? fileUrl,  DateTime? uploadedAt,  DateTime? verifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClubDocument() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.fileUrl,_that.uploadedAt,_that.verifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String? fileUrl,  DateTime? uploadedAt,  DateTime? verifiedAt)  $default,) {final _that = this;
switch (_that) {
case _ClubDocument():
return $default(_that.id,_that.name,_that.status,_that.fileUrl,_that.uploadedAt,_that.verifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String status,  String? fileUrl,  DateTime? uploadedAt,  DateTime? verifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _ClubDocument() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.fileUrl,_that.uploadedAt,_that.verifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClubDocument implements ClubDocument {
  const _ClubDocument({required this.id, required this.name, required this.status, this.fileUrl, this.uploadedAt, this.verifiedAt});
  factory _ClubDocument.fromJson(Map<String, dynamic> json) => _$ClubDocumentFromJson(json);

@override final  String id;
@override final  String name;
@override final  String status;
@override final  String? fileUrl;
@override final  DateTime? uploadedAt;
@override final  DateTime? verifiedAt;

/// Create a copy of ClubDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClubDocumentCopyWith<_ClubDocument> get copyWith => __$ClubDocumentCopyWithImpl<_ClubDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClubDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClubDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,fileUrl,uploadedAt,verifiedAt);

@override
String toString() {
  return 'ClubDocument(id: $id, name: $name, status: $status, fileUrl: $fileUrl, uploadedAt: $uploadedAt, verifiedAt: $verifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ClubDocumentCopyWith<$Res> implements $ClubDocumentCopyWith<$Res> {
  factory _$ClubDocumentCopyWith(_ClubDocument value, $Res Function(_ClubDocument) _then) = __$ClubDocumentCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String status, String? fileUrl, DateTime? uploadedAt, DateTime? verifiedAt
});




}
/// @nodoc
class __$ClubDocumentCopyWithImpl<$Res>
    implements _$ClubDocumentCopyWith<$Res> {
  __$ClubDocumentCopyWithImpl(this._self, this._then);

  final _ClubDocument _self;
  final $Res Function(_ClubDocument) _then;

/// Create a copy of ClubDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? fileUrl = freezed,Object? uploadedAt = freezed,Object? verifiedAt = freezed,}) {
  return _then(_ClubDocument(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fileUrl: freezed == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String?,uploadedAt: freezed == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$Club {

 String get id; String get name; String get sport; String get village; bool get active; String? get logoUrl; String? get brandPrimaryHex; String? get brandSecondaryHex; int? get foundedYear; String? get registrationNumber; String? get phone; String? get email; String? get address; List<ClubDocument> get documents;
/// Create a copy of Club
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClubCopyWith<Club> get copyWith => _$ClubCopyWithImpl<Club>(this as Club, _$identity);

  /// Serializes this Club to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Club&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.village, village) || other.village == village)&&(identical(other.active, active) || other.active == active)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.brandPrimaryHex, brandPrimaryHex) || other.brandPrimaryHex == brandPrimaryHex)&&(identical(other.brandSecondaryHex, brandSecondaryHex) || other.brandSecondaryHex == brandSecondaryHex)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&const DeepCollectionEquality().equals(other.documents, documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sport,village,active,logoUrl,brandPrimaryHex,brandSecondaryHex,foundedYear,registrationNumber,phone,email,address,const DeepCollectionEquality().hash(documents));

@override
String toString() {
  return 'Club(id: $id, name: $name, sport: $sport, village: $village, active: $active, logoUrl: $logoUrl, brandPrimaryHex: $brandPrimaryHex, brandSecondaryHex: $brandSecondaryHex, foundedYear: $foundedYear, registrationNumber: $registrationNumber, phone: $phone, email: $email, address: $address, documents: $documents)';
}


}

/// @nodoc
abstract mixin class $ClubCopyWith<$Res>  {
  factory $ClubCopyWith(Club value, $Res Function(Club) _then) = _$ClubCopyWithImpl;
@useResult
$Res call({
 String id, String name, String sport, String village, bool active, String? logoUrl, String? brandPrimaryHex, String? brandSecondaryHex, int? foundedYear, String? registrationNumber, String? phone, String? email, String? address, List<ClubDocument> documents
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sport = null,Object? village = null,Object? active = null,Object? logoUrl = freezed,Object? brandPrimaryHex = freezed,Object? brandSecondaryHex = freezed,Object? foundedYear = freezed,Object? registrationNumber = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? documents = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as String,village: null == village ? _self.village : village // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,brandPrimaryHex: freezed == brandPrimaryHex ? _self.brandPrimaryHex : brandPrimaryHex // ignore: cast_nullable_to_non_nullable
as String?,brandSecondaryHex: freezed == brandSecondaryHex ? _self.brandSecondaryHex : brandSecondaryHex // ignore: cast_nullable_to_non_nullable
as String?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,registrationNumber: freezed == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<ClubDocument>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String sport,  String village,  bool active,  String? logoUrl,  String? brandPrimaryHex,  String? brandSecondaryHex,  int? foundedYear,  String? registrationNumber,  String? phone,  String? email,  String? address,  List<ClubDocument> documents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active,_that.logoUrl,_that.brandPrimaryHex,_that.brandSecondaryHex,_that.foundedYear,_that.registrationNumber,_that.phone,_that.email,_that.address,_that.documents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String sport,  String village,  bool active,  String? logoUrl,  String? brandPrimaryHex,  String? brandSecondaryHex,  int? foundedYear,  String? registrationNumber,  String? phone,  String? email,  String? address,  List<ClubDocument> documents)  $default,) {final _that = this;
switch (_that) {
case _Club():
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active,_that.logoUrl,_that.brandPrimaryHex,_that.brandSecondaryHex,_that.foundedYear,_that.registrationNumber,_that.phone,_that.email,_that.address,_that.documents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String sport,  String village,  bool active,  String? logoUrl,  String? brandPrimaryHex,  String? brandSecondaryHex,  int? foundedYear,  String? registrationNumber,  String? phone,  String? email,  String? address,  List<ClubDocument> documents)?  $default,) {final _that = this;
switch (_that) {
case _Club() when $default != null:
return $default(_that.id,_that.name,_that.sport,_that.village,_that.active,_that.logoUrl,_that.brandPrimaryHex,_that.brandSecondaryHex,_that.foundedYear,_that.registrationNumber,_that.phone,_that.email,_that.address,_that.documents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Club implements Club {
  const _Club({required this.id, required this.name, required this.sport, required this.village, this.active = true, this.logoUrl, this.brandPrimaryHex, this.brandSecondaryHex, this.foundedYear, this.registrationNumber, this.phone, this.email, this.address, final  List<ClubDocument> documents = const <ClubDocument>[]}): _documents = documents;
  factory _Club.fromJson(Map<String, dynamic> json) => _$ClubFromJson(json);

@override final  String id;
@override final  String name;
@override final  String sport;
@override final  String village;
@override@JsonKey() final  bool active;
@override final  String? logoUrl;
@override final  String? brandPrimaryHex;
@override final  String? brandSecondaryHex;
@override final  int? foundedYear;
@override final  String? registrationNumber;
@override final  String? phone;
@override final  String? email;
@override final  String? address;
 final  List<ClubDocument> _documents;
@override@JsonKey() List<ClubDocument> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Club&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.village, village) || other.village == village)&&(identical(other.active, active) || other.active == active)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.brandPrimaryHex, brandPrimaryHex) || other.brandPrimaryHex == brandPrimaryHex)&&(identical(other.brandSecondaryHex, brandSecondaryHex) || other.brandSecondaryHex == brandSecondaryHex)&&(identical(other.foundedYear, foundedYear) || other.foundedYear == foundedYear)&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&const DeepCollectionEquality().equals(other._documents, _documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sport,village,active,logoUrl,brandPrimaryHex,brandSecondaryHex,foundedYear,registrationNumber,phone,email,address,const DeepCollectionEquality().hash(_documents));

@override
String toString() {
  return 'Club(id: $id, name: $name, sport: $sport, village: $village, active: $active, logoUrl: $logoUrl, brandPrimaryHex: $brandPrimaryHex, brandSecondaryHex: $brandSecondaryHex, foundedYear: $foundedYear, registrationNumber: $registrationNumber, phone: $phone, email: $email, address: $address, documents: $documents)';
}


}

/// @nodoc
abstract mixin class _$ClubCopyWith<$Res> implements $ClubCopyWith<$Res> {
  factory _$ClubCopyWith(_Club value, $Res Function(_Club) _then) = __$ClubCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String sport, String village, bool active, String? logoUrl, String? brandPrimaryHex, String? brandSecondaryHex, int? foundedYear, String? registrationNumber, String? phone, String? email, String? address, List<ClubDocument> documents
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sport = null,Object? village = null,Object? active = null,Object? logoUrl = freezed,Object? brandPrimaryHex = freezed,Object? brandSecondaryHex = freezed,Object? foundedYear = freezed,Object? registrationNumber = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? documents = null,}) {
  return _then(_Club(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as String,village: null == village ? _self.village : village // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,brandPrimaryHex: freezed == brandPrimaryHex ? _self.brandPrimaryHex : brandPrimaryHex // ignore: cast_nullable_to_non_nullable
as String?,brandSecondaryHex: freezed == brandSecondaryHex ? _self.brandSecondaryHex : brandSecondaryHex // ignore: cast_nullable_to_non_nullable
as String?,foundedYear: freezed == foundedYear ? _self.foundedYear : foundedYear // ignore: cast_nullable_to_non_nullable
as int?,registrationNumber: freezed == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<ClubDocument>,
  ));
}


}


/// @nodoc
mixin _$SportPerson {

 String get id; String get name; String get clubId; String get role; String get group; bool get verified; bool get expiredLicense; List<String> get missingDocuments; String? get photoUrl; String? get gender; int? get age; String? get nik; String? get birthPlace; DateTime? get birthDate; String? get address; List<Milestone> get milestones; List<String> get requiredDocuments; List<String> get completedDocuments;
/// Create a copy of SportPerson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SportPersonCopyWith<SportPerson> get copyWith => _$SportPersonCopyWithImpl<SportPerson>(this as SportPerson, _$identity);

  /// Serializes this SportPerson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SportPerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clubId, clubId) || other.clubId == clubId)&&(identical(other.role, role) || other.role == role)&&(identical(other.group, group) || other.group == group)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.expiredLicense, expiredLicense) || other.expiredLicense == expiredLicense)&&const DeepCollectionEquality().equals(other.missingDocuments, missingDocuments)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.age, age) || other.age == age)&&(identical(other.nik, nik) || other.nik == nik)&&(identical(other.birthPlace, birthPlace) || other.birthPlace == birthPlace)&&(identical(other.birthDate, birthDate) || other.birthDate == birthDate)&&(identical(other.address, address) || other.address == address)&&const DeepCollectionEquality().equals(other.milestones, milestones)&&const DeepCollectionEquality().equals(other.requiredDocuments, requiredDocuments)&&const DeepCollectionEquality().equals(other.completedDocuments, completedDocuments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clubId,role,group,verified,expiredLicense,const DeepCollectionEquality().hash(missingDocuments),photoUrl,gender,age,nik,birthPlace,birthDate,address,const DeepCollectionEquality().hash(milestones),const DeepCollectionEquality().hash(requiredDocuments),const DeepCollectionEquality().hash(completedDocuments));

@override
String toString() {
  return 'SportPerson(id: $id, name: $name, clubId: $clubId, role: $role, group: $group, verified: $verified, expiredLicense: $expiredLicense, missingDocuments: $missingDocuments, photoUrl: $photoUrl, gender: $gender, age: $age, nik: $nik, birthPlace: $birthPlace, birthDate: $birthDate, address: $address, milestones: $milestones, requiredDocuments: $requiredDocuments, completedDocuments: $completedDocuments)';
}


}

/// @nodoc
abstract mixin class $SportPersonCopyWith<$Res>  {
  factory $SportPersonCopyWith(SportPerson value, $Res Function(SportPerson) _then) = _$SportPersonCopyWithImpl;
@useResult
$Res call({
 String id, String name, String clubId, String role, String group, bool verified, bool expiredLicense, List<String> missingDocuments, String? photoUrl, String? gender, int? age, String? nik, String? birthPlace, DateTime? birthDate, String? address, List<Milestone> milestones, List<String> requiredDocuments, List<String> completedDocuments
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? clubId = null,Object? role = null,Object? group = null,Object? verified = null,Object? expiredLicense = null,Object? missingDocuments = null,Object? photoUrl = freezed,Object? gender = freezed,Object? age = freezed,Object? nik = freezed,Object? birthPlace = freezed,Object? birthDate = freezed,Object? address = freezed,Object? milestones = null,Object? requiredDocuments = null,Object? completedDocuments = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clubId: null == clubId ? _self.clubId : clubId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,expiredLicense: null == expiredLicense ? _self.expiredLicense : expiredLicense // ignore: cast_nullable_to_non_nullable
as bool,missingDocuments: null == missingDocuments ? _self.missingDocuments : missingDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,nik: freezed == nik ? _self.nik : nik // ignore: cast_nullable_to_non_nullable
as String?,birthPlace: freezed == birthPlace ? _self.birthPlace : birthPlace // ignore: cast_nullable_to_non_nullable
as String?,birthDate: freezed == birthDate ? _self.birthDate : birthDate // ignore: cast_nullable_to_non_nullable
as DateTime?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,milestones: null == milestones ? _self.milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<Milestone>,requiredDocuments: null == requiredDocuments ? _self.requiredDocuments : requiredDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,completedDocuments: null == completedDocuments ? _self.completedDocuments : completedDocuments // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments,  String? photoUrl,  String? gender,  int? age,  String? nik,  String? birthPlace,  DateTime? birthDate,  String? address,  List<Milestone> milestones,  List<String> requiredDocuments,  List<String> completedDocuments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments,_that.photoUrl,_that.gender,_that.age,_that.nik,_that.birthPlace,_that.birthDate,_that.address,_that.milestones,_that.requiredDocuments,_that.completedDocuments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments,  String? photoUrl,  String? gender,  int? age,  String? nik,  String? birthPlace,  DateTime? birthDate,  String? address,  List<Milestone> milestones,  List<String> requiredDocuments,  List<String> completedDocuments)  $default,) {final _that = this;
switch (_that) {
case _SportPerson():
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments,_that.photoUrl,_that.gender,_that.age,_that.nik,_that.birthPlace,_that.birthDate,_that.address,_that.milestones,_that.requiredDocuments,_that.completedDocuments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String clubId,  String role,  String group,  bool verified,  bool expiredLicense,  List<String> missingDocuments,  String? photoUrl,  String? gender,  int? age,  String? nik,  String? birthPlace,  DateTime? birthDate,  String? address,  List<Milestone> milestones,  List<String> requiredDocuments,  List<String> completedDocuments)?  $default,) {final _that = this;
switch (_that) {
case _SportPerson() when $default != null:
return $default(_that.id,_that.name,_that.clubId,_that.role,_that.group,_that.verified,_that.expiredLicense,_that.missingDocuments,_that.photoUrl,_that.gender,_that.age,_that.nik,_that.birthPlace,_that.birthDate,_that.address,_that.milestones,_that.requiredDocuments,_that.completedDocuments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SportPerson implements SportPerson {
  const _SportPerson({required this.id, required this.name, required this.clubId, required this.role, required this.group, this.verified = true, this.expiredLicense = false, final  List<String> missingDocuments = const <String>[], this.photoUrl, this.gender, this.age, this.nik, this.birthPlace, this.birthDate, this.address, final  List<Milestone> milestones = const <Milestone>[], final  List<String> requiredDocuments = const <String>[], final  List<String> completedDocuments = const <String>[]}): _missingDocuments = missingDocuments,_milestones = milestones,_requiredDocuments = requiredDocuments,_completedDocuments = completedDocuments;
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

@override final  String? photoUrl;
@override final  String? gender;
@override final  int? age;
@override final  String? nik;
@override final  String? birthPlace;
@override final  DateTime? birthDate;
@override final  String? address;
 final  List<Milestone> _milestones;
@override@JsonKey() List<Milestone> get milestones {
  if (_milestones is EqualUnmodifiableListView) return _milestones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_milestones);
}

 final  List<String> _requiredDocuments;
@override@JsonKey() List<String> get requiredDocuments {
  if (_requiredDocuments is EqualUnmodifiableListView) return _requiredDocuments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requiredDocuments);
}

 final  List<String> _completedDocuments;
@override@JsonKey() List<String> get completedDocuments {
  if (_completedDocuments is EqualUnmodifiableListView) return _completedDocuments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_completedDocuments);
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SportPerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clubId, clubId) || other.clubId == clubId)&&(identical(other.role, role) || other.role == role)&&(identical(other.group, group) || other.group == group)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.expiredLicense, expiredLicense) || other.expiredLicense == expiredLicense)&&const DeepCollectionEquality().equals(other._missingDocuments, _missingDocuments)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.age, age) || other.age == age)&&(identical(other.nik, nik) || other.nik == nik)&&(identical(other.birthPlace, birthPlace) || other.birthPlace == birthPlace)&&(identical(other.birthDate, birthDate) || other.birthDate == birthDate)&&(identical(other.address, address) || other.address == address)&&const DeepCollectionEquality().equals(other._milestones, _milestones)&&const DeepCollectionEquality().equals(other._requiredDocuments, _requiredDocuments)&&const DeepCollectionEquality().equals(other._completedDocuments, _completedDocuments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clubId,role,group,verified,expiredLicense,const DeepCollectionEquality().hash(_missingDocuments),photoUrl,gender,age,nik,birthPlace,birthDate,address,const DeepCollectionEquality().hash(_milestones),const DeepCollectionEquality().hash(_requiredDocuments),const DeepCollectionEquality().hash(_completedDocuments));

@override
String toString() {
  return 'SportPerson(id: $id, name: $name, clubId: $clubId, role: $role, group: $group, verified: $verified, expiredLicense: $expiredLicense, missingDocuments: $missingDocuments, photoUrl: $photoUrl, gender: $gender, age: $age, nik: $nik, birthPlace: $birthPlace, birthDate: $birthDate, address: $address, milestones: $milestones, requiredDocuments: $requiredDocuments, completedDocuments: $completedDocuments)';
}


}

/// @nodoc
abstract mixin class _$SportPersonCopyWith<$Res> implements $SportPersonCopyWith<$Res> {
  factory _$SportPersonCopyWith(_SportPerson value, $Res Function(_SportPerson) _then) = __$SportPersonCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String clubId, String role, String group, bool verified, bool expiredLicense, List<String> missingDocuments, String? photoUrl, String? gender, int? age, String? nik, String? birthPlace, DateTime? birthDate, String? address, List<Milestone> milestones, List<String> requiredDocuments, List<String> completedDocuments
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? clubId = null,Object? role = null,Object? group = null,Object? verified = null,Object? expiredLicense = null,Object? missingDocuments = null,Object? photoUrl = freezed,Object? gender = freezed,Object? age = freezed,Object? nik = freezed,Object? birthPlace = freezed,Object? birthDate = freezed,Object? address = freezed,Object? milestones = null,Object? requiredDocuments = null,Object? completedDocuments = null,}) {
  return _then(_SportPerson(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clubId: null == clubId ? _self.clubId : clubId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,expiredLicense: null == expiredLicense ? _self.expiredLicense : expiredLicense // ignore: cast_nullable_to_non_nullable
as bool,missingDocuments: null == missingDocuments ? _self._missingDocuments : missingDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,nik: freezed == nik ? _self.nik : nik // ignore: cast_nullable_to_non_nullable
as String?,birthPlace: freezed == birthPlace ? _self.birthPlace : birthPlace // ignore: cast_nullable_to_non_nullable
as String?,birthDate: freezed == birthDate ? _self.birthDate : birthDate // ignore: cast_nullable_to_non_nullable
as DateTime?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,milestones: null == milestones ? _self._milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<Milestone>,requiredDocuments: null == requiredDocuments ? _self._requiredDocuments : requiredDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,completedDocuments: null == completedDocuments ? _self._completedDocuments : completedDocuments // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Milestone {

 String get year; String get title; String? get description;
/// Create a copy of Milestone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MilestoneCopyWith<Milestone> get copyWith => _$MilestoneCopyWithImpl<Milestone>(this as Milestone, _$identity);

  /// Serializes this Milestone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Milestone&&(identical(other.year, year) || other.year == year)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,year,title,description);

@override
String toString() {
  return 'Milestone(year: $year, title: $title, description: $description)';
}


}

/// @nodoc
abstract mixin class $MilestoneCopyWith<$Res>  {
  factory $MilestoneCopyWith(Milestone value, $Res Function(Milestone) _then) = _$MilestoneCopyWithImpl;
@useResult
$Res call({
 String year, String title, String? description
});




}
/// @nodoc
class _$MilestoneCopyWithImpl<$Res>
    implements $MilestoneCopyWith<$Res> {
  _$MilestoneCopyWithImpl(this._self, this._then);

  final Milestone _self;
  final $Res Function(Milestone) _then;

/// Create a copy of Milestone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? title = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Milestone].
extension MilestonePatterns on Milestone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Milestone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Milestone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Milestone value)  $default,){
final _that = this;
switch (_that) {
case _Milestone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Milestone value)?  $default,){
final _that = this;
switch (_that) {
case _Milestone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String year,  String title,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Milestone() when $default != null:
return $default(_that.year,_that.title,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String year,  String title,  String? description)  $default,) {final _that = this;
switch (_that) {
case _Milestone():
return $default(_that.year,_that.title,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String year,  String title,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _Milestone() when $default != null:
return $default(_that.year,_that.title,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Milestone implements Milestone {
  const _Milestone({required this.year, required this.title, this.description});
  factory _Milestone.fromJson(Map<String, dynamic> json) => _$MilestoneFromJson(json);

@override final  String year;
@override final  String title;
@override final  String? description;

/// Create a copy of Milestone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MilestoneCopyWith<_Milestone> get copyWith => __$MilestoneCopyWithImpl<_Milestone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MilestoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Milestone&&(identical(other.year, year) || other.year == year)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,year,title,description);

@override
String toString() {
  return 'Milestone(year: $year, title: $title, description: $description)';
}


}

/// @nodoc
abstract mixin class _$MilestoneCopyWith<$Res> implements $MilestoneCopyWith<$Res> {
  factory _$MilestoneCopyWith(_Milestone value, $Res Function(_Milestone) _then) = __$MilestoneCopyWithImpl;
@override @useResult
$Res call({
 String year, String title, String? description
});




}
/// @nodoc
class __$MilestoneCopyWithImpl<$Res>
    implements _$MilestoneCopyWith<$Res> {
  __$MilestoneCopyWithImpl(this._self, this._then);

  final _Milestone _self;
  final $Res Function(_Milestone) _then;

/// Create a copy of Milestone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? title = null,Object? description = freezed,}) {
  return _then(_Milestone(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CommitteeMember {

 String get id; String get name; String get position; String get division; String get period; String? get phone; String? get email; String? get photoUrl;
/// Create a copy of CommitteeMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitteeMemberCopyWith<CommitteeMember> get copyWith => _$CommitteeMemberCopyWithImpl<CommitteeMember>(this as CommitteeMember, _$identity);

  /// Serializes this CommitteeMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitteeMember&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.division, division) || other.division == division)&&(identical(other.period, period) || other.period == period)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,position,division,period,phone,email,photoUrl);

@override
String toString() {
  return 'CommitteeMember(id: $id, name: $name, position: $position, division: $division, period: $period, phone: $phone, email: $email, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class $CommitteeMemberCopyWith<$Res>  {
  factory $CommitteeMemberCopyWith(CommitteeMember value, $Res Function(CommitteeMember) _then) = _$CommitteeMemberCopyWithImpl;
@useResult
$Res call({
 String id, String name, String position, String division, String period, String? phone, String? email, String? photoUrl
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? position = null,Object? division = null,Object? period = null,Object? phone = freezed,Object? email = freezed,Object? photoUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,division: null == division ? _self.division : division // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String position,  String division,  String period,  String? phone,  String? email,  String? photoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that.id,_that.name,_that.position,_that.division,_that.period,_that.phone,_that.email,_that.photoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String position,  String division,  String period,  String? phone,  String? email,  String? photoUrl)  $default,) {final _that = this;
switch (_that) {
case _CommitteeMember():
return $default(_that.id,_that.name,_that.position,_that.division,_that.period,_that.phone,_that.email,_that.photoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String position,  String division,  String period,  String? phone,  String? email,  String? photoUrl)?  $default,) {final _that = this;
switch (_that) {
case _CommitteeMember() when $default != null:
return $default(_that.id,_that.name,_that.position,_that.division,_that.period,_that.phone,_that.email,_that.photoUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommitteeMember implements CommitteeMember {
  const _CommitteeMember({required this.id, required this.name, required this.position, required this.division, this.period = '2025–2029', this.phone, this.email, this.photoUrl});
  factory _CommitteeMember.fromJson(Map<String, dynamic> json) => _$CommitteeMemberFromJson(json);

@override final  String id;
@override final  String name;
@override final  String position;
@override final  String division;
@override@JsonKey() final  String period;
@override final  String? phone;
@override final  String? email;
@override final  String? photoUrl;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitteeMember&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.division, division) || other.division == division)&&(identical(other.period, period) || other.period == period)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,position,division,period,phone,email,photoUrl);

@override
String toString() {
  return 'CommitteeMember(id: $id, name: $name, position: $position, division: $division, period: $period, phone: $phone, email: $email, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class _$CommitteeMemberCopyWith<$Res> implements $CommitteeMemberCopyWith<$Res> {
  factory _$CommitteeMemberCopyWith(_CommitteeMember value, $Res Function(_CommitteeMember) _then) = __$CommitteeMemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String position, String division, String period, String? phone, String? email, String? photoUrl
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? position = null,Object? division = null,Object? period = null,Object? phone = freezed,Object? email = freezed,Object? photoUrl = freezed,}) {
  return _then(_CommitteeMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,division: null == division ? _self.division : division // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$HelpdeskContact {

 String? get whatsapp; String? get phone; String? get email; String? get address; String? get operationalHours;
/// Create a copy of HelpdeskContact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HelpdeskContactCopyWith<HelpdeskContact> get copyWith => _$HelpdeskContactCopyWithImpl<HelpdeskContact>(this as HelpdeskContact, _$identity);

  /// Serializes this HelpdeskContact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HelpdeskContact&&(identical(other.whatsapp, whatsapp) || other.whatsapp == whatsapp)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&(identical(other.operationalHours, operationalHours) || other.operationalHours == operationalHours));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,whatsapp,phone,email,address,operationalHours);

@override
String toString() {
  return 'HelpdeskContact(whatsapp: $whatsapp, phone: $phone, email: $email, address: $address, operationalHours: $operationalHours)';
}


}

/// @nodoc
abstract mixin class $HelpdeskContactCopyWith<$Res>  {
  factory $HelpdeskContactCopyWith(HelpdeskContact value, $Res Function(HelpdeskContact) _then) = _$HelpdeskContactCopyWithImpl;
@useResult
$Res call({
 String? whatsapp, String? phone, String? email, String? address, String? operationalHours
});




}
/// @nodoc
class _$HelpdeskContactCopyWithImpl<$Res>
    implements $HelpdeskContactCopyWith<$Res> {
  _$HelpdeskContactCopyWithImpl(this._self, this._then);

  final HelpdeskContact _self;
  final $Res Function(HelpdeskContact) _then;

/// Create a copy of HelpdeskContact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? whatsapp = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? operationalHours = freezed,}) {
  return _then(_self.copyWith(
whatsapp: freezed == whatsapp ? _self.whatsapp : whatsapp // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,operationalHours: freezed == operationalHours ? _self.operationalHours : operationalHours // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HelpdeskContact].
extension HelpdeskContactPatterns on HelpdeskContact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HelpdeskContact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HelpdeskContact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HelpdeskContact value)  $default,){
final _that = this;
switch (_that) {
case _HelpdeskContact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HelpdeskContact value)?  $default,){
final _that = this;
switch (_that) {
case _HelpdeskContact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? whatsapp,  String? phone,  String? email,  String? address,  String? operationalHours)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HelpdeskContact() when $default != null:
return $default(_that.whatsapp,_that.phone,_that.email,_that.address,_that.operationalHours);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? whatsapp,  String? phone,  String? email,  String? address,  String? operationalHours)  $default,) {final _that = this;
switch (_that) {
case _HelpdeskContact():
return $default(_that.whatsapp,_that.phone,_that.email,_that.address,_that.operationalHours);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? whatsapp,  String? phone,  String? email,  String? address,  String? operationalHours)?  $default,) {final _that = this;
switch (_that) {
case _HelpdeskContact() when $default != null:
return $default(_that.whatsapp,_that.phone,_that.email,_that.address,_that.operationalHours);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HelpdeskContact implements HelpdeskContact {
  const _HelpdeskContact({this.whatsapp, this.phone, this.email, this.address, this.operationalHours});
  factory _HelpdeskContact.fromJson(Map<String, dynamic> json) => _$HelpdeskContactFromJson(json);

@override final  String? whatsapp;
@override final  String? phone;
@override final  String? email;
@override final  String? address;
@override final  String? operationalHours;

/// Create a copy of HelpdeskContact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HelpdeskContactCopyWith<_HelpdeskContact> get copyWith => __$HelpdeskContactCopyWithImpl<_HelpdeskContact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HelpdeskContactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HelpdeskContact&&(identical(other.whatsapp, whatsapp) || other.whatsapp == whatsapp)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&(identical(other.operationalHours, operationalHours) || other.operationalHours == operationalHours));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,whatsapp,phone,email,address,operationalHours);

@override
String toString() {
  return 'HelpdeskContact(whatsapp: $whatsapp, phone: $phone, email: $email, address: $address, operationalHours: $operationalHours)';
}


}

/// @nodoc
abstract mixin class _$HelpdeskContactCopyWith<$Res> implements $HelpdeskContactCopyWith<$Res> {
  factory _$HelpdeskContactCopyWith(_HelpdeskContact value, $Res Function(_HelpdeskContact) _then) = __$HelpdeskContactCopyWithImpl;
@override @useResult
$Res call({
 String? whatsapp, String? phone, String? email, String? address, String? operationalHours
});




}
/// @nodoc
class __$HelpdeskContactCopyWithImpl<$Res>
    implements _$HelpdeskContactCopyWith<$Res> {
  __$HelpdeskContactCopyWithImpl(this._self, this._then);

  final _HelpdeskContact _self;
  final $Res Function(_HelpdeskContact) _then;

/// Create a copy of HelpdeskContact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? whatsapp = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? operationalHours = freezed,}) {
  return _then(_HelpdeskContact(
whatsapp: freezed == whatsapp ? _self.whatsapp : whatsapp // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,operationalHours: freezed == operationalHours ? _self.operationalHours : operationalHours // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$KokSnapshot {

 AccessScope get scope; List<Club> get clubs; List<SportPerson> get people; List<CommitteeMember> get committee; DateTime get loadedAt; HelpdeskContact? get helpdesk;
/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KokSnapshotCopyWith<KokSnapshot> get copyWith => _$KokSnapshotCopyWithImpl<KokSnapshot>(this as KokSnapshot, _$identity);

  /// Serializes this KokSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KokSnapshot&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other.clubs, clubs)&&const DeepCollectionEquality().equals(other.people, people)&&const DeepCollectionEquality().equals(other.committee, committee)&&(identical(other.loadedAt, loadedAt) || other.loadedAt == loadedAt)&&(identical(other.helpdesk, helpdesk) || other.helpdesk == helpdesk));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(clubs),const DeepCollectionEquality().hash(people),const DeepCollectionEquality().hash(committee),loadedAt,helpdesk);

@override
String toString() {
  return 'KokSnapshot(scope: $scope, clubs: $clubs, people: $people, committee: $committee, loadedAt: $loadedAt, helpdesk: $helpdesk)';
}


}

/// @nodoc
abstract mixin class $KokSnapshotCopyWith<$Res>  {
  factory $KokSnapshotCopyWith(KokSnapshot value, $Res Function(KokSnapshot) _then) = _$KokSnapshotCopyWithImpl;
@useResult
$Res call({
 AccessScope scope, List<Club> clubs, List<SportPerson> people, List<CommitteeMember> committee, DateTime loadedAt, HelpdeskContact? helpdesk
});


$HelpdeskContactCopyWith<$Res>? get helpdesk;

}
/// @nodoc
class _$KokSnapshotCopyWithImpl<$Res>
    implements $KokSnapshotCopyWith<$Res> {
  _$KokSnapshotCopyWithImpl(this._self, this._then);

  final KokSnapshot _self;
  final $Res Function(KokSnapshot) _then;

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scope = null,Object? clubs = null,Object? people = null,Object? committee = null,Object? loadedAt = null,Object? helpdesk = freezed,}) {
  return _then(_self.copyWith(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as AccessScope,clubs: null == clubs ? _self.clubs : clubs // ignore: cast_nullable_to_non_nullable
as List<Club>,people: null == people ? _self.people : people // ignore: cast_nullable_to_non_nullable
as List<SportPerson>,committee: null == committee ? _self.committee : committee // ignore: cast_nullable_to_non_nullable
as List<CommitteeMember>,loadedAt: null == loadedAt ? _self.loadedAt : loadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,helpdesk: freezed == helpdesk ? _self.helpdesk : helpdesk // ignore: cast_nullable_to_non_nullable
as HelpdeskContact?,
  ));
}
/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HelpdeskContactCopyWith<$Res>? get helpdesk {
    if (_self.helpdesk == null) {
    return null;
  }

  return $HelpdeskContactCopyWith<$Res>(_self.helpdesk!, (value) {
    return _then(_self.copyWith(helpdesk: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AccessScope scope,  List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt,  HelpdeskContact? helpdesk)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that.scope,_that.clubs,_that.people,_that.committee,_that.loadedAt,_that.helpdesk);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AccessScope scope,  List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt,  HelpdeskContact? helpdesk)  $default,) {final _that = this;
switch (_that) {
case _KokSnapshot():
return $default(_that.scope,_that.clubs,_that.people,_that.committee,_that.loadedAt,_that.helpdesk);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AccessScope scope,  List<Club> clubs,  List<SportPerson> people,  List<CommitteeMember> committee,  DateTime loadedAt,  HelpdeskContact? helpdesk)?  $default,) {final _that = this;
switch (_that) {
case _KokSnapshot() when $default != null:
return $default(_that.scope,_that.clubs,_that.people,_that.committee,_that.loadedAt,_that.helpdesk);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KokSnapshot implements KokSnapshot {
  const _KokSnapshot({required this.scope, required final  List<Club> clubs, required final  List<SportPerson> people, required final  List<CommitteeMember> committee, required this.loadedAt, this.helpdesk}): _clubs = clubs,_people = people,_committee = committee;
  factory _KokSnapshot.fromJson(Map<String, dynamic> json) => _$KokSnapshotFromJson(json);

@override final  AccessScope scope;
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
@override final  HelpdeskContact? helpdesk;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KokSnapshot&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other._clubs, _clubs)&&const DeepCollectionEquality().equals(other._people, _people)&&const DeepCollectionEquality().equals(other._committee, _committee)&&(identical(other.loadedAt, loadedAt) || other.loadedAt == loadedAt)&&(identical(other.helpdesk, helpdesk) || other.helpdesk == helpdesk));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(_clubs),const DeepCollectionEquality().hash(_people),const DeepCollectionEquality().hash(_committee),loadedAt,helpdesk);

@override
String toString() {
  return 'KokSnapshot(scope: $scope, clubs: $clubs, people: $people, committee: $committee, loadedAt: $loadedAt, helpdesk: $helpdesk)';
}


}

/// @nodoc
abstract mixin class _$KokSnapshotCopyWith<$Res> implements $KokSnapshotCopyWith<$Res> {
  factory _$KokSnapshotCopyWith(_KokSnapshot value, $Res Function(_KokSnapshot) _then) = __$KokSnapshotCopyWithImpl;
@override @useResult
$Res call({
 AccessScope scope, List<Club> clubs, List<SportPerson> people, List<CommitteeMember> committee, DateTime loadedAt, HelpdeskContact? helpdesk
});


@override $HelpdeskContactCopyWith<$Res>? get helpdesk;

}
/// @nodoc
class __$KokSnapshotCopyWithImpl<$Res>
    implements _$KokSnapshotCopyWith<$Res> {
  __$KokSnapshotCopyWithImpl(this._self, this._then);

  final _KokSnapshot _self;
  final $Res Function(_KokSnapshot) _then;

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? clubs = null,Object? people = null,Object? committee = null,Object? loadedAt = null,Object? helpdesk = freezed,}) {
  return _then(_KokSnapshot(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as AccessScope,clubs: null == clubs ? _self._clubs : clubs // ignore: cast_nullable_to_non_nullable
as List<Club>,people: null == people ? _self._people : people // ignore: cast_nullable_to_non_nullable
as List<SportPerson>,committee: null == committee ? _self._committee : committee // ignore: cast_nullable_to_non_nullable
as List<CommitteeMember>,loadedAt: null == loadedAt ? _self.loadedAt : loadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,helpdesk: freezed == helpdesk ? _self.helpdesk : helpdesk // ignore: cast_nullable_to_non_nullable
as HelpdeskContact?,
  ));
}

/// Create a copy of KokSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HelpdeskContactCopyWith<$Res>? get helpdesk {
    if (_self.helpdesk == null) {
    return null;
  }

  return $HelpdeskContactCopyWith<$Res>(_self.helpdesk!, (value) {
    return _then(_self.copyWith(helpdesk: value));
  });
}
}

// dart format on
