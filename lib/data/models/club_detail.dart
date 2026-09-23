import 'package:flutter/foundation.dart';

import 'club.dart';

@immutable
final class ClubPersonnelItem {
  const ClubPersonnelItem({
    this.id,
    required this.name,
    this.role,
    this.phone,
    this.email,
    this.photoUrl,
    this.source,
  });

  final int? id;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubPersonnelItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role &&
          phone == other.phone &&
          email == other.email &&
          photoUrl == other.photoUrl &&
          source == other.source;

  @override
  int get hashCode =>
      Object.hash(id, name, role, phone, email, photoUrl, source);
}

@immutable
final class ClubPersonnelBlock {
  const ClubPersonnelBlock({
    required this.dataAvailable,
    this.reason,
    required this.items,
  });

  final bool dataAvailable;
  final String? reason;
  final List<ClubPersonnelItem> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubPersonnelBlock &&
          runtimeType == other.runtimeType &&
          dataAvailable == other.dataAvailable &&
          reason == other.reason &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(dataAvailable, reason, Object.hashAll(items));
}

@immutable
final class ClubManagementBlock {
  const ClubManagementBlock({
    required this.dataAvailable,
    required this.partial,
    this.source,
    required this.items,
  });

  final bool dataAvailable;
  final bool partial;
  final String? source;
  final List<ClubPersonnelItem> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubManagementBlock &&
          runtimeType == other.runtimeType &&
          dataAvailable == other.dataAvailable &&
          partial == other.partial &&
          source == other.source &&
          listEquals(items, other.items);

  @override
  int get hashCode =>
      Object.hash(dataAvailable, partial, source, Object.hashAll(items));
}

@immutable
final class ClubDetail {
  const ClubDetail({
    required this.id,
    required this.code,
    required this.name,
    this.logoUrl,
    required this.cabor,
    this.headName,
    this.phone,
    this.email,
    this.since,
    this.noSk,
    required this.status,
    required this.statusLabel,
    required this.secretariat,
    required this.totalAthleteInClub,
    this.training,
    this.fileSkUrl,
    required this.officials,
    required this.coaches,
    required this.management,
  });

  final int id;
  final String code;
  final String name;
  final String? logoUrl;
  final ClubCabor cabor;
  final String? headName;
  final String? phone;
  final String? email;
  final String? since;
  final String? noSk;
  final int status;
  final String statusLabel;
  final ClubAddress secretariat;
  final int totalAthleteInClub;
  final ClubAddress? training;
  final String? fileSkUrl;
  final ClubPersonnelBlock officials;
  final ClubPersonnelBlock coaches;
  final ClubManagementBlock management;

  ClubDetail copyWith({
    int? id,
    String? code,
    String? name,
    String? logoUrl,
    ClubCabor? cabor,
    String? headName,
    String? phone,
    String? email,
    String? since,
    String? noSk,
    int? status,
    String? statusLabel,
    ClubAddress? secretariat,
    int? totalAthleteInClub,
    ClubAddress? training,
    String? fileSkUrl,
    ClubPersonnelBlock? officials,
    ClubPersonnelBlock? coaches,
    ClubManagementBlock? management,
  }) {
    return ClubDetail(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      cabor: cabor ?? this.cabor,
      headName: headName ?? this.headName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      since: since ?? this.since,
      noSk: noSk ?? this.noSk,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      secretariat: secretariat ?? this.secretariat,
      totalAthleteInClub: totalAthleteInClub ?? this.totalAthleteInClub,
      training: training ?? this.training,
      fileSkUrl: fileSkUrl ?? this.fileSkUrl,
      officials: officials ?? this.officials,
      coaches: coaches ?? this.coaches,
      management: management ?? this.management,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubDetail &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          logoUrl == other.logoUrl &&
          cabor == other.cabor &&
          headName == other.headName &&
          phone == other.phone &&
          email == other.email &&
          since == other.since &&
          noSk == other.noSk &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          secretariat == other.secretariat &&
          totalAthleteInClub == other.totalAthleteInClub &&
          training == other.training &&
          fileSkUrl == other.fileSkUrl &&
          officials == other.officials &&
          coaches == other.coaches &&
          management == other.management;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    logoUrl,
    cabor,
    headName,
    phone,
    email,
    since,
    noSk,
    status,
    statusLabel,
    secretariat,
    totalAthleteInClub,
    training,
    fileSkUrl,
    officials,
    coaches,
    management,
  );
}
