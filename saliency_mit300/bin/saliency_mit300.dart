import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:saliency_mit300/model_results.dart';

Future<dynamic> _readJsonFile(String filePath) async {
  var input = await File(filePath).readAsString();
  var map = jsonDecode(input);
  return map;
}

ModelResults? _modelResultsFromJson(Map<String, dynamic> json) {
  final td = json['td'];

  if (td == null) {
    return null;
  }

  if (td!.length < 12) {
    return null;
  }

  return ModelResults(
    modelName: td[0].toString(),
    aucJudd: td[3].toString(),
    sim: td[4].toString(),
    emd: td[5].toString(),
    aucBorji: td[6].toString(),
    sAUC: td[7].toString(),
    cc: td[8].toString(),
    nss: td[9].toString(),
    kl: td[10].toString(),
  );
}

List<ModelResults> _modelResultsFromJsonList(List<dynamic> jsonList) {
  return jsonList
      .map((e) => _modelResultsFromJson(e))
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
}

String _sanitizeString(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

bool _isModel(String name, ModelResults modelResults) {
  final sanitizedString = _sanitizeString(name);
  return _sanitizeString(modelResults.modelName).contains(sanitizedString);
}

bool _isAmongModels(List<String> names, ModelResults modelResults) {
  for (var name in names) {
    if (_isModel(name, modelResults)) {
      return true;
    }
  }

  return false;
}

class _ModelNameQuery {
  final String query;
  final String displayName;

  const _ModelNameQuery(this.query, this.displayName);
}

String rightPad(String input, int length) {
  if (input.length >= length) {
    return input;
  }
  return input + ' ' * (length - input.length);
}

String _generateLaTeXLineForModelNameQuery(
    _ModelNameQuery query, List<ModelResults> modelResults,
    {int nameLength = 0}) {
  final modelResultsForQuery = modelResults
      .map<ModelResults?>((e) => e)
      .firstWhere((element) => _isModel(query.query, element!),
          orElse: () => null);

  if (modelResultsForQuery == null) {
    return "% “${query.displayName}” missing";
  }

  final paddedDisplayName = rightPad(query.displayName, nameLength);

  return '$paddedDisplayName & ${modelResultsForQuery.aucJudd} & ${modelResultsForQuery.sim} & '
      '${modelResultsForQuery.emd} & ${modelResultsForQuery.aucBorji} & ${modelResultsForQuery.sAUC} & '
      '${modelResultsForQuery.cc} & ${modelResultsForQuery.nss} & ${modelResultsForQuery.kl} \\\\';
}

Future<void> _printLatexLinesForDataset(String dataset) async {
  final mit300Json = await _readJsonFile('./data/${dataset}_results.json');

  final tbody = mit300Json['tbody'];
  final tr = tbody['tr'];

  final modelResults = _modelResultsFromJsonList(tr);

  const models = [
    _ModelNameQuery("SAM-ResNet", "SAM-ResNet~\\cite{8400593}"),
    _ModelNameQuery("SAM-VGG", "SAM-VGG~\\cite{8400593}"),
    _ModelNameQuery("PDP", "PDP~\\cite{jetley2018endtoend}"),
    _ModelNameQuery("DeepFix", "DeepFix~\\cite{7937829}"),
    _ModelNameQuery("SalGAN", "SalGAN~\\cite{Pan_2017_SalGAN}"),
    _ModelNameQuery("Mr-CNN", "Mr-CNN~\\cite{7298633}"),
    _ModelNameQuery("SALICON", "SALICON~\\cite{7410395}"),
    _ModelNameQuery("eDN", "eDN~\\cite{6909754}"),
    _ModelNameQuery("Judd Model", "Judd~\\cite{5459462}"),
  ];

  final longestDisplayName =
      models.map((e) => e.displayName.length).reduce(max);

  for (var model in models) {
    final latexLine = _generateLaTeXLineForModelNameQuery(model, modelResults,
        nameLength: longestDisplayName);
    print(latexLine);
  }
}

void main(List<String> arguments) {
  final dataset = arguments.first;

  _printLatexLinesForDataset(dataset);
}
