import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MedicalApiClient {
  MedicalApiClient({
    required this.calculatorBaseUrl,
    required this.knowledgeBaseUrl,
  });

  final String calculatorBaseUrl;
  final String knowledgeBaseUrl;
  static const _timeout = Duration(seconds: 20);

  Future<List<CalculatorSummary>> calculators({String query = ''}) async {
    final path = query.trim().isEmpty
        ? '/api/v1/calculators'
        : '/api/v1/search';
    final parameters = query.trim().isEmpty
        ? const {'limit': '200'}
        : {'q': query.trim(), 'limit': '50'};
    final payload = await _get(calculatorBaseUrl, path, parameters);
    final tools = payload['tools'];
    if (tools is! List) return const [];
    return tools
        .whereType<Map>()
        .map(
          (item) => CalculatorSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<CalculatorField>> calculatorSchema(String toolId) async {
    final payload = await _get(
      calculatorBaseUrl,
      '/api/v1/calculators/$toolId/schema',
    );
    final inputs = payload['inputs'];
    if (inputs is! List) return const [];
    return inputs
        .whereType<Map>()
        .map(
          (item) => CalculatorField.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<CalculationResult> calculate(
    String toolId,
    Map<String, dynamic> params,
  ) async {
    final uri = Uri.parse('$calculatorBaseUrl/api/v1/calculate/$toolId');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'params': params}),
        )
        .timeout(_timeout);
    final payload = _decode(response);
    return CalculationResult.fromJson(payload);
  }

  Future<List<KnowledgeEvidence>> searchKnowledge(String query) async {
    final payload = await _get(knowledgeBaseUrl, '/api/search', {
      'q': query.trim(),
      'limit': '20',
    });
    final results = payload['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map(
          (item) => KnowledgeEvidence.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<ClinicalCategory>> clinicalCategories() async {
    final payload = await _get(knowledgeBaseUrl, '/api/clinical/categories');
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (item) => ClinicalCategory.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<ClinicalDiseaseSummary>> clinicalDiseases({
    String query = '',
    String category = '',
  }) async {
    final parameters = <String, String>{'limit': '200'};
    if (query.trim().length >= 2) parameters['q'] = query.trim();
    if (category.isNotEmpty) parameters['category'] = category;
    final payload = await _get(
      knowledgeBaseUrl,
      '/api/clinical/diseases',
      parameters,
    );
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              ClinicalDiseaseSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<ProtocolDocument> protocolDocument(String docId) async {
    final payload = await _get(
      knowledgeBaseUrl,
      '/api/documents/${Uri.encodeComponent(docId)}/presentation',
    );
    return ProtocolDocument.fromJson(payload);
  }

  Future<Map<String, dynamic>> health(String baseUrl) =>
      _get(baseUrl, '/health');

  Future<Map<String, dynamic>> _get(
    String baseUrl,
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final base = Uri.parse('$baseUrl$path');
    final uri = base.replace(queryParameters: queryParameters);
    final response = await http.get(uri).timeout(_timeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        'Сервер вернул некорректный ответ (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(
        detail?.toString() ?? 'Ошибка сервера: ${response.statusCode}.',
      );
    }
    if (decoded is! Map) throw const ApiException('Ожидался JSON-объект.');
    return Map<String, dynamic>.from(decoded);
  }
}
