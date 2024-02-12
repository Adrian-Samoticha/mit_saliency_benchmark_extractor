import 'metric.dart';

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
  final String ig;
  final dynamic json;
  final String dataSource;

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
      required this.ig,
      required this.json,
      required this.dataSource});

  @override
  String toString() {
    return 'ModelResults(readableName: $readableName, $published, aucJudd: '
        '$aucJudd, sim: $sim, emd: $emd, aucBorji: $aucBorji, sAUC: $sAUC, cc: '
        '$cc, nss: $nss, kl: $kl, ig: $ig, releaseDate: $releaseYear, '
        'dataSource: $dataSource)';
  }

  String getMetric(Metric metric) {
    switch (metric) {
      case Metric.aucJudd:
        return aucJudd;
      case Metric.sim:
        return sim;
      case Metric.emd:
        return emd;
      case Metric.aucBorji:
        return aucBorji;
      case Metric.sAUC:
        return sAUC;
      case Metric.cc:
        return cc;
      case Metric.nss:
        return nss;
      case Metric.kl:
        return kl;
      case Metric.ig:
        return ig;
    }
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

  String? get releaseYear {
    final publishedWithoutUrls = published.replaceAll(
        RegExp(
            r'https?://(www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_+.~#?&/=]*)'),
        '');

    return _findYearInString(publishedWithoutUrls);
  }

  String? _getReadableNameFromNameJson(dynamic nameJson) {
    if (nameJson is String && nameJson.length < 64) {
      return nameJson;
    }

    if (nameJson is List && nameJson.isNotEmpty) {
      return nameJson[0].toString();
    }

    if (nameJson is Map) {
      if (nameJson.containsKey('p')) {
        return _getReadableNameFromNameJson(nameJson['p']);
      }

      final a = nameJson['a'];
      if (a is Map) {
        final text = a['#text'];
        if (text != null) {
          return text.toString();
        }
      }
    }

    return null;
  }

  String get readableName {
    final match1 = RegExp(r'\(.*(?=\))').firstMatch(modelName);
    if (match1 != null) {
      final result = match1.group(0)!.substring(1);

      if (result == 'VGG-16,Imagenet') {
        return 'Forward-Backward Feature Fusion';
      }

      return result;
    }

    final nameJson = json[0];

    return _getReadableNameFromNameJson(nameJson) ?? '--';
  }
}
