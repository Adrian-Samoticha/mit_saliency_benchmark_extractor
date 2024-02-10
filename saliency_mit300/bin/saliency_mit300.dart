import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:num_remap/num_remap.dart';
import 'package:saliency_mit300/model_results.dart';
import 'package:saliency_mit300/task.dart';
import 'package:sprintf/sprintf.dart';

Future<dynamic> _readJsonFile(String filePath) async {
  var input = await File(filePath).readAsString();
  var map = jsonDecode(input);
  return map;
}

String _findNumberInJson(dynamic json) {
  final number = RegExp(r'\d+(\.\d+)?').firstMatch(json.toString());
  return number?.group(0) ?? '--';
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
    published: td[1].toString(),
    aucJudd: _findNumberInJson(td[3]),
    sim: _findNumberInJson(td[4]),
    emd: _findNumberInJson(td[5]),
    aucBorji: _findNumberInJson(td[6]),
    sAUC: _findNumberInJson(td[7]),
    cc: _findNumberInJson(td[8]),
    nss: _findNumberInJson(td[9]),
    kl: _findNumberInJson(td[10]),
    json: td,
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

ModelResults? _findModelResultsFromQuery(
    _ModelNameQuery query, List<ModelResults> modelResults) {
  return modelResults.map<ModelResults?>((e) => e).firstWhere(
      (element) => _isModel(query.query, element!),
      orElse: () => null);
}

String _generateLaTeXTableColumnLineForModelNameQuery(
    _ModelNameQuery query, List<ModelResults> modelResults,
    {int nameLength = 0}) {
  final modelResultsForQuery = _findModelResultsFromQuery(query, modelResults);

  if (modelResultsForQuery == null) {
    return "% “${query.displayName}” missing";
  }

  final paddedDisplayName = rightPad(query.displayName, nameLength);

  return '$paddedDisplayName & ${modelResultsForQuery.aucJudd} & ${modelResultsForQuery.sim} & '
      '${modelResultsForQuery.emd} & ${modelResultsForQuery.aucBorji} & ${modelResultsForQuery.sAUC} & '
      '${modelResultsForQuery.cc} & ${modelResultsForQuery.nss} & ${modelResultsForQuery.kl} \\\\';
}

bool _isModelInQueryList(
    ModelResults modelResults, List<_ModelNameQuery> queryList) {
  return queryList.any((element) => _isModel(element.query, modelResults));
}

String _generatePerformancePlot(
    List<ModelResults> modelResults, List<_ModelNameQuery> selectedModels) {
  var elementsString = '';

  // sort model results by release year
  final sortedModelResults = modelResults
      .where((e) => e.releaseDate != null)
      .toList()
    ..sort((a, b) => a.releaseDate!.compareTo(b.releaseDate!));

  final earliestReleaseDate = int.parse(sortedModelResults.first.releaseDate!);
  final latestReleaseDate = int.parse(sortedModelResults.last.releaseDate!);

  const xMin = 0.0;
  const xMax = 12.0;

  final worstPerformance =
      sortedModelResults.map((e) => double.parse(e.nss)).reduce(min);
  final bestPerformance =
      sortedModelResults.map((e) => double.parse(e.nss)).reduce(max);

  const yMin = 0.0;
  const yMax = 15.0;

  for (var model in sortedModelResults) {
    final releaseDate = int.parse(model.releaseDate!);
    final x =
        releaseDate.remap(earliestReleaseDate, latestReleaseDate, xMin, xMax);
    final y = double.parse(model.nss)
        .remap(worstPerformance, bestPerformance, yMin, yMax);

    final name = model.readableName;

    final isModelSelected = _isModelInQueryList(model, selectedModels);

    final color = isModelSelected ? 'black' : 'gray';
    final fontSize = isModelSelected ? 'small' : 'tiny';
    final nodeSize = isModelSelected ? '2pt' : '1.75pt';

    elementsString +=
        '\\filldraw[$color] ($x, $y) circle ($nodeSize) node[anchor=west]{\\$fontSize $name};\n';
  }

  elementsString += '\\draw[black, thick] (0,0) -- ($xMax,0);\n';
  elementsString += '\\draw[black, thick] (0,0) -- (0,$yMax);\n';

  // draw year lines and numbers
  for (int i = earliestReleaseDate; i <= latestReleaseDate; i += 1) {
    final x = i.remap(earliestReleaseDate, latestReleaseDate, xMin, xMax);
    elementsString += '\\draw[black, thick] ($x,-0.1) -- ($x,0.1);\n'
        '\\node[rotate=270] at ($x,-0.75) {$i};\n';
  }

  // draw performance lines and numbers
  for (double i = 0.0; i <= 1.0; i += 0.1) {
    final performance = i.remap(0.0, 1.0, worstPerformance, bestPerformance);
    final y = performance.remap(worstPerformance, bestPerformance, yMin, yMax);

    final performanceString = sprintf('%.2f', [performance]);
    elementsString += '\\draw[black, thick] (-0.1,$y) -- (0.1,$y);\n'
        '\\node at (-0.75,$y) {$performanceString};\n';
  }

  return '\\begin{figure}\n'
      '\\centering\n'
      '\\begin{tikzpicture}\n'
      '$elementsString'
      '\\end{tikzpicture}\n'
      '\\label{fig:mit300_nss_perf_plot}\n'
      '\\caption{Performance of various saliency map prediction models, measured by their NSS score. '
      'Performance measurements are taken from \\cite{mit-saliency-benchmark}. '
      'Models drawn in black are present in Table~\\ref{tab:mit300_perf}. '
      'Only models whose release date is present in \\cite{mit-saliency-benchmark} are included. '
      'The code that was used to generate this figure is available at: \\url{'
      'https://github.com/Adrian-Samoticha/mit_saliency_benchmark_extractor}}\n'
      '\\end{figure}\n';
}

Future<void> _printLatexTableColumnLinesForDataset(
    String dataset, Task task) async {
  final mit300Json = await _readJsonFile('./data/${dataset}_results.json');

  final tbody = mit300Json['tbody'];
  final tr = tbody['tr'];

  final modelResults = _modelResultsFromJsonList(tr);

  const selectedModels = [
    _ModelNameQuery("SAM-ResNet", "SAM-ResNet \\cite{8400593}"),
    _ModelNameQuery("SAM-VGG", "SAM-VGG \\cite{8400593}"),
    _ModelNameQuery("PDP", "PDP \\cite{jetley2018endtoend}"),
    _ModelNameQuery("DeepFix", "DeepFix \\cite{7937829}"),
    _ModelNameQuery("SalGAN", "SalGAN \\cite{Pan_2017_SalGAN}"),
    _ModelNameQuery("SalNet", "Pan (deep) \\cite{7780440}"),
    _ModelNameQuery("JuntingNet", "Pan (shallow) \\cite{7780440}"),
    _ModelNameQuery("Mr-CNN", "Mr-CNN \\cite{7298633}"),
    _ModelNameQuery("SALICON", "SALICON \\cite{7410395}"),
    _ModelNameQuery("Deep Gaze 2", "Deep Gaze~II \\cite{kümmerer2015deep}"),
    _ModelNameQuery("Deep Gaze 1", "Deep Gaze~I \\cite{kümmerer2015deep}"),
    _ModelNameQuery("eDN", "eDN \\cite{6909754}"),
    _ModelNameQuery("BMS", "BMS \\cite{6751128}"),
    _ModelNameQuery("Judd Model", "Judd \\cite{5459462}"),
    _ModelNameQuery("Hou \\& Zhang", "Hou \\& Zhang \\cite{4270292}"),
    _ModelNameQuery("GBVS", "GBVS \\cite{NIPS2006_4db0f8b0}"),
    _ModelNameQuery("Itti", "Itti et al. \\cite{730558}"),
  ];

  switch (task) {
    case Task.generateTableRows:
      final longestDisplayName =
          selectedModels.map((e) => e.displayName.length).reduce(max);

      for (var model in selectedModels) {
        final latexLine = _generateLaTeXTableColumnLineForModelNameQuery(
            model, modelResults,
            nameLength: longestDisplayName);
        print(latexLine);
      }

    case Task.generatePerformancePlot:
      final plot = _generatePerformancePlot(modelResults, selectedModels);
      print(plot);
  }
}

void main(List<String> arguments) {
  final dataset = arguments.first;
  final task =
      Task.values.firstWhere((element) => element.name == arguments[1]);

  _printLatexTableColumnLinesForDataset(dataset, task);
}
