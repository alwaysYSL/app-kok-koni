import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'mock_data.dart';
import 'mock_session_store.dart';

/// ANSI color helper for rich terminal logging.
class _Ansi {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const green = '\x1B[32m';
  static const red = '\x1B[31m';
  static const yellow = '\x1B[33m';
  static const cyan = '\x1B[36m';
  static const magenta = '\x1B[35m';
  static const gray = '\x1B[90m';
  static const blue = '\x1B[34m';
}

/// Standalone Mock HTTP Server for the SICABOR KOK API.
class SicaborMockServer {
  SicaborMockServer({MockSessionStore? sessionStore})
    : sessionStore = sessionStore ?? MockSessionStore();

  final MockSessionStore sessionStore;
  HttpServer? _server;
  bool _verbose = true;

  /// Gets the running server port, or null if not running.
  int? get port => _server?.port;

  /// Starts the mock server.
  Future<HttpServer> start({
    String host = '127.0.0.1',
    int port = 8080,
    bool verbose = true,
  }) async {
    _verbose = verbose;
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest);
    return _server!;
  }

  /// Stops the mock server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Request pipeline handler.
  Future<void> _handleRequest(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    final response = request.response;

    // Apply global CORS headers
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization, X-Requested-With',
    );

    // Handle pre-flight CORS OPTIONS request
    if (request.method.toUpperCase() == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      _logRequest(request, HttpStatus.ok, stopwatch.elapsedMilliseconds);
      return;
    }

    try {
      final path = _normalizePath(request.uri.path);

      if (path == '/mock-media/logo-koni.png' ||
          path == '/mock-media/mascot.png') {
        if (request.method != 'GET') {
          response.statusCode = HttpStatus.methodNotAllowed;
          await response.close();
        } else {
          response.headers.contentType = ContentType('image', 'png');
          final file = path.endsWith('logo-koni.png')
              ? File('assets/branding/logo-koni.png')
              : File('assets/branding/mascot.png');
          await file.openRead().pipe(response);
        }
        _logRequest(
          request,
          response.statusCode,
          stopwatch.elapsedMilliseconds,
        );
        return;
      } else if (path == '/api/auth' || path == '/auth') {
        await _handleAuth(request, response);
      } else if (path.startsWith('/api/v1/kok') || _isKokPathAlias(path)) {
        await _handleProtectedKok(request, response, path);
      } else {
        _sendJson(response, HttpStatus.notFound, {
          'success': false,
          'message': 'Endpoint tidak ditemukan.',
          'error_code': 'NOT_FOUND',
        });
      }
    } catch (e, stack) {
      _sendJson(response, HttpStatus.internalServerError, {
        'success': false,
        'message': 'Terjadi kesalahan internal pada mock server.',
        'error': e.toString(),
      });
      if (_verbose) {
        stderr.writeln('${_Ansi.red}[ERROR] $e\n$stack${_Ansi.reset}');
      }
    }

    await response.close();
    _logRequest(request, response.statusCode, stopwatch.elapsedMilliseconds);
  }

  String _normalizePath(String rawPath) {
    var path = rawPath.trim();
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  bool _isKokPathAlias(String path) {
    return path == '/profile' ||
        path == '/cabor' ||
        path.startsWith('/club') ||
        path.startsWith('/athlete');
  }

  /// Canonicalizes path by stripping `/api/v1/kok` or leading slashes.
  String _canonicalKokPath(String path) {
    var p = path;
    if (p.startsWith('/api/v1/kok')) {
      p = p.substring('/api/v1/kok'.length);
    }
    if (!p.startsWith('/')) {
      p = '/$p';
    }
    return p;
  }

  /// Handles POST /api/auth.
  Future<void> _handleAuth(HttpRequest request, HttpResponse response) async {
    if (request.method.toUpperCase() != 'POST') {
      _sendJson(response, HttpStatus.methodNotAllowed, {
        'status': false,
        'message': 'Metode HTTP tidak diizinkan. Gunakan POST.',
      });
      return;
    }

    final bodyStr = await utf8.decodeStream(request);
    String username = '';
    String password = '';

    final contentType = request.headers.contentType?.mimeType.toLowerCase();
    if (contentType == 'application/json') {
      try {
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        username = (json['username'] ?? '').toString();
        password = (json['password'] ?? '').toString();
      } catch (_) {
        // Fallback or ignore JSON parsing error
      }
    } else {
      final queryParams = Uri.splitQueryString(bodyStr);
      username = queryParams['username'] ?? '';
      password = queryParams['password'] ?? '';
    }

    if (username.isEmpty || password.isEmpty) {
      _sendJson(response, HttpStatus.unauthorized, {
        'status': false,
        'message': 'Username dan password wajib diisi.',
      });
      return;
    }

    final account = MockData.findAccountByUsername(username);
    if (account == null || !MockData.verifyPassword(account, password)) {
      _sendJson(response, HttpStatus.unauthorized, {
        'status': false,
        'message': 'Username atau password salah.',
      });
      return;
    }

    final token = sessionStore.issue(account);
    _sendJson(response, HttpStatus.ok, {
      'status': true,
      'message': 'LOGIN SUCCESSFULLY',
      'data': {
        'id': account.id.toString(),
        'username': account.username,
        'name': account.name,
        'email': account.email,
        'type': account.type,
      },
      'token': token,
    });
  }

  /// Authenticates and routes protected `/api/v1/kok/*` requests.
  Future<void> _handleProtectedKok(
    HttpRequest request,
    HttpResponse response,
    String rawPath,
  ) async {
    // 1. Check Authorization header
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      _sendJson(response, HttpStatus.unauthorized, {
        'success': false,
        'error_code': 'INVALID_TOKEN',
        'message': 'Token tidak valid atau telah kedaluwarsa',
      });
      return;
    }

    final token = authHeader.substring('Bearer '.length).trim();
    final lookup = sessionStore.lookup(
      token,
      accountResolver: (id) => MockData.findAccountById(id),
    );

    if (lookup.status == MockSessionStatus.unknownOrExpired) {
      _sendJson(response, HttpStatus.unauthorized, {
        'success': false,
        'error_code': 'INVALID_TOKEN',
        'message': 'Token tidak valid atau telah kedaluwarsa',
      });
      return;
    }

    if (lookup.status == MockSessionStatus.memberMissing) {
      _sendJson(response, HttpStatus.forbidden, {
        'success': false,
        'error_code': 'MEMBER_NOT_FOUND',
        'message': 'Data member tidak ditemukan',
      });
      return;
    }

    final account = lookup.account!;

    // 2. Check account status (active)
    if (!account.isActive) {
      _sendJson(response, HttpStatus.forbidden, {
        'success': false,
        'message': 'Akun Anda telah dinonaktifkan.',
        'error_code': 'MEMBER_INACTIVE',
      });
      return;
    }

    // 3. Check account type (admin_kok)
    if (!account.isKok) {
      _sendJson(response, HttpStatus.forbidden, {
        'success': false,
        'message': 'Endpoint ini hanya dapat diakses oleh akun KOK.',
        'error_code': 'NOT_KOK',
      });
      return;
    }

    // 4. Check subdistrict assignment
    if (!account.hasSubdistrict) {
      _sendJson(response, HttpStatus.forbidden, {
        'success': false,
        'message': 'Akun KOK belum memiliki wilayah kecamatan.',
        'error_code': 'NO_SUBDISTRICT',
      });
      return;
    }

    // 5. Check HTTP Method
    if (request.method.toUpperCase() != 'GET') {
      _sendJson(response, HttpStatus.methodNotAllowed, {
        'success': false,
        'message':
            'Metode HTTP tidak diizinkan. Semua endpoint KOK adalah GET.',
      });
      return;
    }

    final path = _canonicalKokPath(rawPath);
    final params = request.uri.queryParameters;
    final mediaOrigin =
        'http://${request.headers.value(HttpHeaders.hostHeader)}';

    // Route: /profile
    if (path == '/profile') {
      final json = MockData.buildProfileJson(account);
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /cabor
    if (path == '/cabor') {
      final limit = int.tryParse(params['limit'] ?? '') ?? 25;
      final offset = int.tryParse(params['offset'] ?? '') ?? 0;
      final source = params['source'] ?? 'all';
      final sort = params['sort'];

      final json = MockData.buildCaborListJson(
        account,
        mediaOrigin: mediaOrigin,
        limit: limit,
        offset: offset,
        source: source,
        sort: sort,
      );
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /club
    if (path == '/club') {
      final limit = int.tryParse(params['limit'] ?? '') ?? 25;
      final offset = int.tryParse(params['offset'] ?? '') ?? 0;
      final idCabor = int.tryParse(params['id_cabor'] ?? '');
      final status = int.tryParse(params['status'] ?? '');
      final search = params['search'];
      final sort = params['sort'];

      final json = MockData.buildClubListJson(
        account,
        mediaOrigin: mediaOrigin,
        limit: limit,
        offset: offset,
        idCabor: idCabor,
        status: status,
        search: search,
        sort: sort,
      );
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /club/detail/{id}
    if (path.startsWith('/club/detail/')) {
      final idStr = path.substring('/club/detail/'.length);
      final id = int.tryParse(idStr);
      if (id == null) {
        _sendClubNotFound(response);
        return;
      }

      final json = MockData.buildClubDetailJson(
        id,
        account: account,
        mediaOrigin: mediaOrigin,
      );
      if (json == null) {
        _sendClubNotFound(response);
      } else {
        _sendJson(response, HttpStatus.ok, json);
      }
      return;
    }

    // Route: /club/official/{id}
    if (path.startsWith('/club/official/')) {
      final idStr = path.substring('/club/official/'.length);
      final id = int.tryParse(idStr);
      if (id == null || !_isClubInSubdistrict(id, account.subdistrictId)) {
        _sendClubNotFound(response);
        return;
      }

      final json = MockData.buildClubOfficialJson(id, account: account);
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /club/coach/{id}
    if (path.startsWith('/club/coach/')) {
      final idStr = path.substring('/club/coach/'.length);
      final id = int.tryParse(idStr);
      if (id == null || !_isClubInSubdistrict(id, account.subdistrictId)) {
        _sendClubNotFound(response);
        return;
      }

      final json = MockData.buildClubCoachJson(id, account: account);
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /club/management/{id}
    if (path.startsWith('/club/management/')) {
      final idStr = path.substring('/club/management/'.length);
      final id = int.tryParse(idStr);
      if (id == null) {
        _sendClubNotFound(response);
        return;
      }

      final json = MockData.buildClubManagementJson(id, account: account);
      if (json == null) {
        _sendClubNotFound(response);
      } else {
        _sendJson(response, HttpStatus.ok, json);
      }
      return;
    }

    // Route: /athlete
    if (path == '/athlete') {
      final limit = int.tryParse(params['limit'] ?? '') ?? 25;
      final offset = int.tryParse(params['offset'] ?? '') ?? 0;
      final idCabor = int.tryParse(params['id_cabor'] ?? '');
      final idClub = int.tryParse(params['id_club'] ?? '');
      final sex = params['sex'];
      final status = int.tryParse(params['status'] ?? '');
      final search = params['search'];
      final sort = params['sort'];

      final json = MockData.buildAthleteListJson(
        account,
        mediaOrigin: mediaOrigin,
        limit: limit,
        offset: offset,
        idCabor: idCabor,
        idClub: idClub,
        sex: sex,
        status: status,
        search: search,
        sort: sort,
      );
      _sendJson(response, HttpStatus.ok, json);
      return;
    }

    // Route: /athlete/detail/{id}
    if (path.startsWith('/athlete/detail/')) {
      final idStr = path.substring('/athlete/detail/'.length);
      final id = int.tryParse(idStr);
      if (id == null) {
        _sendAthleteNotFound(response);
        return;
      }

      final json = MockData.buildAthleteDetailJson(
        id,
        account: account,
        mediaOrigin: mediaOrigin,
      );
      if (json == null) {
        _sendAthleteNotFound(response);
      } else {
        _sendJson(response, HttpStatus.ok, json);
      }
      return;
    }

    // Unknown KOK subroute
    _sendJson(response, HttpStatus.notFound, {
      'success': false,
      'message': 'Endpoint KOK tidak ditemukan.',
      'error_code': 'NOT_FOUND',
    });
  }

  bool _isClubInSubdistrict(int clubId, int? subdistrictId) {
    if (subdistrictId == null) return false;
    for (final club in MockData.clubs) {
      if (club.id == clubId && club.secretariatSubdistrictId == subdistrictId) {
        return true;
      }
    }
    return false;
  }

  void _sendClubNotFound(HttpResponse response) {
    _sendJson(response, HttpStatus.notFound, {
      'success': false,
      'message': 'Data club tidak ditemukan.',
      'error_code': 'CLUB_NOT_FOUND',
    });
  }

  void _sendAthleteNotFound(HttpResponse response) {
    _sendJson(response, HttpStatus.notFound, {
      'success': false,
      'message': 'Data atlet tidak ditemukan.',
      'error_code': 'ATHLETE_NOT_FOUND',
    });
  }

  void _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    response.write(jsonEncode(body));
  }

  void _logRequest(HttpRequest request, int statusCode, int durationMs) {
    if (!_verbose) return;

    final now = DateTime.now().toIso8601String().substring(11, 19);
    final method = request.method.padRight(7);
    final path = request.uri.toString();

    String statusColor;
    if (statusCode >= 200 && statusCode < 300) {
      statusColor = '${_Ansi.green}[$statusCode]${_Ansi.reset}';
    } else if (statusCode >= 400 && statusCode < 500) {
      statusColor = '${_Ansi.yellow}[$statusCode]${_Ansi.reset}';
    } else {
      statusColor = '${_Ansi.red}[$statusCode]${_Ansi.reset}';
    }

    stdout.writeln(
      '${_Ansi.gray}$now${_Ansi.reset} $statusColor ${_Ansi.cyan}$method${_Ansi.reset} $path ${_Ansi.gray}(${durationMs}ms)${_Ansi.reset}',
    );
  }
}

/// CLI Entrypoint for running the SICABOR Mock Server directly.
void main(List<String> args) async {
  String host = '127.0.0.1';
  int? explicitPort;
  bool verbose = true;

  for (final arg in args) {
    if (arg.startsWith('--port=')) {
      explicitPort = int.tryParse(arg.substring(7));
    } else if (arg.startsWith('-p=')) {
      explicitPort = int.tryParse(arg.substring(3));
    } else if (arg.startsWith('--host=')) {
      host = arg.substring(7);
    } else if (arg.startsWith('-h=')) {
      host = arg.substring(3);
    } else if (arg == '--quiet' || arg == '-q') {
      verbose = false;
    } else if (arg == '--help') {
      stdout.writeln('SICABOR Mock Server');
      stdout.writeln(
        'Usage: dart run scripts/mock_server/sicabor_mock_server.dart [options]',
      );
      stdout.writeln('Options:');
      stdout.writeln(
        '  --port=<port>       Set port to listen on (default: 8088)',
      );
      stdout.writeln(
        '  --host=<host>       Set host address (default: 127.0.0.1)',
      );
      stdout.writeln('  --quiet, -q         Disable request logging');
      stdout.writeln('  --help              Display this help message');
      exit(0);
    }
  }

  final server = SicaborMockServer();
  int port = explicitPort ?? 8088;

  try {
    await server.start(host: host, port: port, verbose: verbose);
  } on SocketException catch (e) {
    if (explicitPort == null) {
      // If 8088 failed, try 8090
      final fallbackPort = (port == 8088) ? 8090 : 8088;
      stderr.writeln(
        '${_Ansi.yellow}[WARN] Port $port is occupied or restricted ($e). Trying fallback port $fallbackPort...${_Ansi.reset}',
      );
      try {
        await server.start(host: host, port: fallbackPort, verbose: verbose);
        port = fallbackPort;
      } catch (fallbackError) {
        stderr.writeln(
          '${_Ansi.red}[ERROR] Failed to start mock server on port $fallbackPort: $fallbackError${_Ansi.reset}',
        );
        exit(1);
      }
    } else {
      stderr.writeln(
        '${_Ansi.red}[ERROR] Port $port is not available: $e${_Ansi.reset}',
      );
      exit(1);
    }
  }

  stdout.writeln('''
${_Ansi.cyan}${_Ansi.bold}========================================================================${_Ansi.reset}
${_Ansi.green}${_Ansi.bold}  SICABOR KOK API Mock Server (KONI Kabupaten Garut)${_Ansi.reset}
${_Ansi.cyan}========================================================================${_Ansi.reset}
  ${_Ansi.bold}Status:${_Ansi.reset}      Running on ${_Ansi.green}http://$host:$port${_Ansi.reset}
  ${_Ansi.bold}Local URL:${_Ansi.reset}   ${_Ansi.cyan}http://localhost:$port${_Ansi.reset}
  ${_Ansi.bold}Android Em:${_Ansi.reset}  ${_Ansi.cyan}http://10.0.2.2:$port${_Ansi.reset}

${_Ansi.bold}Available Mock Accounts:${_Ansi.reset}
  • ${_Ansi.cyan}kt.garutkota${_Ansi.reset}     (Kecamatan Garut Kota - 32 Cabor, 10 Clubs, 361 Athletes)
  • ${_Ansi.cyan}kt.bllimbangan${_Ansi.reset}   (Kecamatan Balubur Limbangan - 17 Cabor, 0 Clubs, 159 Athletes)
  • ${_Ansi.cyan}kt.tarogongkidul${_Ansi.reset} (Kecamatan Tarogong Kidul - 28 Cabor, 12 Clubs, 290 Athletes)
  • ${_Ansi.magenta}bukan_kok${_Ansi.reset}        (Testing 403 NOT_KOK)
  • ${_Ansi.magenta}non_aktif${_Ansi.reset}        (Testing 403 MEMBER_INACTIVE)
  • ${_Ansi.magenta}tanpa_kecamatan${_Ansi.reset}  (Testing 403 NO_SUBDISTRICT)

${_Ansi.bold}Key Endpoints Implemented:${_Ansi.reset}
  • ${_Ansi.green}POST${_Ansi.reset} /api/auth
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/profile
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/cabor
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/club
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/club/detail/{id}
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/athlete
  • ${_Ansi.blue}GET${_Ansi.reset}  /api/v1/kok/athlete/detail/{id}

${_Ansi.gray}Press Ctrl+C to stop the mock server.${_Ansi.reset}
${_Ansi.cyan}========================================================================${_Ansi.reset}
''');

  // Handle graceful exit on Ctrl+C / SIGINT
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln(
      '\n${_Ansi.yellow}Stopping SICABOR Mock Server...${_Ansi.reset}',
    );
    await server.stop();
    stdout.writeln('${_Ansi.green}Mock server stopped. Goodbye!${_Ansi.reset}');
    exit(0);
  });
}
