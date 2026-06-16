import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultCalculatorApiUrl = String.fromEnvironment(
  'CALCULATOR_API_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const defaultKnowledgeApiUrl = String.fromEnvironment(
  'KNOWLEDGE_API_URL',
  defaultValue: 'http://127.0.0.1:8090',
);

class SettingsController extends ChangeNotifier {
  static const _calculatorKey = 'calculator_api_url';
  static const _knowledgeKey = 'knowledge_api_url';

  String calculatorApiUrl = defaultCalculatorApiUrl;
  String knowledgeApiUrl = defaultKnowledgeApiUrl;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    calculatorApiUrl =
        preferences.getString(_calculatorKey) ?? defaultCalculatorApiUrl;
    knowledgeApiUrl =
        preferences.getString(_knowledgeKey) ?? defaultKnowledgeApiUrl;
  }

  Future<void> save({
    required String calculatorUrl,
    required String knowledgeUrl,
  }) async {
    calculatorApiUrl = normalizeBaseUrl(calculatorUrl);
    knowledgeApiUrl = normalizeBaseUrl(knowledgeUrl);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_calculatorKey, calculatorApiUrl);
    await preferences.setString(_knowledgeKey, knowledgeApiUrl);
    notifyListeners();
  }

  static String normalizeBaseUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
