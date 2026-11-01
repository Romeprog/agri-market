import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcItem {
  const PsgcItem({required this.code, required this.name});

  final String code;
  final String name;

  factory PsgcItem.fromJson(Map<String, dynamic> json) {
    return PsgcItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  @override
  String toString() => name;
}

class PsgcService {
  PsgcService._();

  static const _baseUrl = 'https://psgc.cloud/api/v2';
  static const _timeout = Duration(seconds: 15);

  static Future<List<PsgcItem>> fetchRegions() {
    return _fetchList('$_baseUrl/regions');
  }
  static Future<List<PsgcItem>> fetchProvinces(String regionCode) {
    return _fetchList('$_baseUrl/regions/$regionCode/provinces');
  }
  static Future<List<PsgcItem>> fetchCitiesMunicipalities(String provinceCode) {
    return _fetchList(
      '$_baseUrl/provinces/$provinceCode/cities-municipalities',
    );
  }
  static Future<List<PsgcItem>> fetchBarangays(String cityMunicipalityCode) {
    return _fetchList(
      '$_baseUrl/cities-municipalities/$cityMunicipalityCode/barangays',
    );
  }
  static Future<List<PsgcItem>> _fetchList(String url) async {
    final items = <PsgcItem>[];
    String? nextUrl = _withInitialPageSize(url);
    var safetyCounter = 0;

    while (nextUrl != null && safetyCounter < 200) {
      safetyCounter++;
      final response = await http.get(Uri.parse(nextUrl)).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('PSGC request failed (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is List<dynamic>) {
        items.addAll(
          decoded.whereType<Map<String, dynamic>>().map(PsgcItem.fromJson),
        );
        break;
      }

      if (decoded is! Map<String, dynamic>) break;

      final rawList = decoded['data'] as List<dynamic>? ?? const <dynamic>[];
      items.addAll(
        rawList.whereType<Map<String, dynamic>>().map(PsgcItem.fromJson),
      );

      nextUrl = _nextPageUrl(decoded, url);
    }

    return items;
  }

  static String _withInitialPageSize(String url) {
    final uri = Uri.parse(url);
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'per_page': '1000'})
        .toString();
  }

  static String? _nextPageUrl(Map<String, dynamic> decoded, String baseUrl) {
    final links = decoded['links'];
    if (links is Map<String, dynamic>) {
      final next = links['next'];
      if (next is String && next.isNotEmpty) return next;
    }
    final meta = decoded['meta'];
    if (meta is Map<String, dynamic>) {
      final currentPage = meta['current_page'];
      final lastPage = meta['last_page'];
      if (currentPage is int && lastPage is int && currentPage < lastPage) {
        final uri = Uri.parse(baseUrl);
        return uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                'per_page': '1000',
                'page': '${currentPage + 1}',
              },
            )
            .toString();
      }
    }

    return null;
  }
}