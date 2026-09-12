import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/models.dart';

void main() {
  test('Club membaca kontak dan dokumen dari JSON SICABOR', () {
    final club = Club.fromJson({
      'id': 'garuda',
      'name': 'Klub Garuda Muda',
      'sport': 'Sepak Bola',
      'village': 'Pakuwon',
      'phone': '081234567890',
      'email': 'garuda@example.test',
      'address': 'Jl. Pakuwon',
      'documents': [
        {
          'id': 'doc-1',
          'name': 'SK Klub',
          'status': 'verified',
          'fileUrl': 'https://example.test/doc-1.pdf',
          'uploadedAt': '2026-01-10T08:00:00.000Z',
          'verifiedAt': '2026-01-11T08:00:00.000Z',
        },
      ],
    });

    expect(club.toJson()['phone'], '081234567890');
    expect((club.toJson()['documents'] as List).single['status'], 'verified');
  });

  test('field opsional mempertahankan default list kosong', () {
    final person = SportPerson.fromJson({
      'id': 'p-1',
      'name': 'Nama Atlet',
      'clubId': 'garuda',
      'role': 'Atlet',
      'group': 'U-18',
    });
    expect(person.toJson()['milestones'], isEmpty);
    expect(person.toJson()['requiredDocuments'], isEmpty);
  });

  test('nested API-ready models mempertahankan field detail saat round-trip', () {
    final club = Club(
      id: 'garuda',
      name: 'Klub Garuda Muda',
      sport: 'Sepak Bola',
      village: 'Pakuwon',
      phone: '081234567890',
      email: 'garuda@example.test',
      address: 'Jl. Pakuwon',
      documents: [
        ClubDocument(
          id: 'doc-1',
          name: 'SK Klub',
          status: 'pending-review',
          fileUrl: 'https://example.test/doc-1.pdf',
          uploadedAt: DateTime.parse('2026-01-10T08:00:00.000Z'),
          verifiedAt: null,
        ),
      ],
    );
    final person = SportPerson(
      id: 'p-1',
      name: 'Nama Atlet',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-18',
      nik: '3205010101010001',
      birthPlace: 'Garut',
      birthDate: DateTime.parse('2008-05-01T00:00:00.000Z'),
      address: 'Jl. Cikuray',
      milestones: const [
        Milestone(
          year: '2025',
          title: 'Kejuaraan Antar Klub',
          description: 'Meraih juara dua tingkat kabupaten.',
        ),
      ],
      requiredDocuments: const ['KTP', 'Kartu Keluarga'],
      completedDocuments: const ['KTP'],
    );
    final committee = CommitteeMember(
      id: 'member-1',
      name: 'Nama Pengurus',
      position: 'Ketua',
      division: 'Organisasi',
      phone: '081200000001',
      email: 'pengurus@example.test',
      photoUrl: 'https://example.test/member-1.jpg',
    );
    final snapshot = KokSnapshot(
      scope: const AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      ),
      clubs: [club],
      people: [person],
      committee: [committee],
      loadedAt: DateTime.parse('2026-01-12T08:00:00.000Z'),
      helpdesk: const HelpdeskContact(
        whatsapp: '081299999999',
        phone: '0262234567',
        email: 'helpdesk@example.test',
        address: 'Kantor KONI Garut',
        operationalHours: 'Senin–Jumat, 08.00–16.00',
      ),
    );

    expect(Club.fromJson(club.toJson()), club);
    expect(SportPerson.fromJson(person.toJson()), person);
    expect(CommitteeMember.fromJson(committee.toJson()), committee);
    expect(KokSnapshot.fromJson(snapshot.toJson()), snapshot);
  });

  test('optional nested timestamps dapat bernilai null', () {
    final document = ClubDocument.fromJson({
      'id': 'doc-2',
      'name': 'Kepengurusan',
      'status': 'submitted-by-club',
      'fileUrl': null,
      'uploadedAt': null,
      'verifiedAt': null,
    });

    expect(document.fileUrl, isNull);
    expect(document.uploadedAt, isNull);
    expect(document.verifiedAt, isNull);
  });

  test('Milestone membaca year sebagai String dan description opsional', () {
    final milestone = Milestone.fromJson({
      'year': '2025',
      'title': 'Kejuaraan Antar Klub',
    });

    expect(milestone.year, '2025');
    expect(milestone.description, isNull);
    expect(milestone.toJson()['description'], isNull);
  });

  test('HelpdeskContact menerima payload tanpa field kontak', () {
    final contact = HelpdeskContact.fromJson({});

    expect(contact.whatsapp, isNull);
    expect(contact.phone, isNull);
    expect(contact.email, isNull);
    expect(contact.address, isNull);
    expect(contact.operationalHours, isNull);
  });
}
