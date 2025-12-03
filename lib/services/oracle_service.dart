import 'package:cloud_functions/cloud_functions.dart';

class OracleService {
  static final OracleService _instance = OracleService._internal();
  factory OracleService() => _instance;
  OracleService._internal();

  Future<String> askQuestion(String query) async {
    try {
      // Appel de la Cloud Function 'ask_oracle'
      final result = await FirebaseFunctions.instance.httpsCallable('ask_oracle').call(
        {'query': query},
      );
      return result.data['response'] as String;
    } catch (e) {
      print("Erreur Oracle: $e");
      return "L'Oracle est silencieux. Vérifiez votre connexion internet ou réessayez plus tard.";
    }
  }
}