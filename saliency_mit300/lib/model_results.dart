class ModelResults {
  final String modelName;
  final String published;
  final String aucJudd;
  final String sim;
  final String emd;
  final String aucBorji;
  final String sAUC;
  final String cc;
  final String nss;
  final String kl;
  final dynamic json;

  const ModelResults(
      {required this.modelName,
      required this.published,
      required this.aucJudd,
      required this.sim,
      required this.emd,
      required this.aucBorji,
      required this.sAUC,
      required this.cc,
      required this.nss,
      required this.kl,
      required this.json});

  @override
  String toString() {
    return 'ModelResults(modelName: $modelName, $published, aucJudd: $aucJudd, '
        'sim: $sim, emd: $emd, aucBorji: $aucBorji, sAUC: $sAUC, cc: $cc, nss: '
        '$nss, kl: $kl)';
  }

  String? _findYearInString(String input) {
    final matchWithClosingSquareBracket =
        RegExp(r'(19|20)\d{2}(?=])').firstMatch(input);

    if (matchWithClosingSquareBracket != null) {
      return matchWithClosingSquareBracket.group(0)!;
    }

    final match = RegExp(r'(19|20)\d{2}').firstMatch(input);
    if (match == null) {
      return null;
    }
    final result = match.group(0);

    final yearAsInt = int.parse(result!);

    if (yearAsInt > 2024) {
      return null;
    }

    if (yearAsInt < 1980) {
      return null;
    }

    return result;
  }

  String? get releaseDate => _findYearInString(published);

  String? get readableName {
    final match1 = RegExp(r'\(.*(?=\))').firstMatch(modelName);
    if (match1 != null) {
      final result = match1.group(0)!.substring(1);

      if (result == 'VGG-16,Imagenet') {
        return 'Forward-Backward Feature Fusion';
      }

      return result;
    }

    final nameJson = json[0];

    if (nameJson is String && nameJson.length < 64) {
      return nameJson;
    }

    if (nameJson is List && nameJson.isNotEmpty) {
      return nameJson[0].toString();
    }

    if (nameJson is Map) {
      final a = nameJson['a'];
      if (a is Map) {
        final text = a['#text'];
        if (text != null) {
          return text.toString();
        }
      }
    }

    return '-';
  }
}
