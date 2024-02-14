import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:num_remap/num_remap.dart';
import 'package:saliency_mit300/metric.dart';
import 'package:saliency_mit300/model_results.dart';
import 'package:saliency_mit300/task.dart';
import 'package:saliency_mit300/util.dart';
import 'package:sprintf/sprintf.dart';

Future<dynamic> _readJsonFile(String filePath) async {
  if (!File(filePath).existsSync()) {
    return null;
  }

  var input = await File(filePath).readAsString();
  var map = jsonDecode(input);
  return map;
}

String _findNumberInJson(dynamic json) {
  final number = RegExp(r'\d+(\.\d+)?').firstMatch(json.toString());
  return number?.group(0) ?? '--';
}

String _getNumberForMetric(dynamic json, Metric metric, String dataSource) {
  final index = metricToIndex(metric, dataSource);

  if (index == null) {
    return '--';
  }

  return _findNumberInJson(json[index]);
}

ModelResults? _modelResultsFromJson(
    Map<String, dynamic> json, String dataSource) {
  final td = json['td'];

  if (td == null) {
    return null;
  }

  if (td!.length < 11) {
    return null;
  }

  return ModelResults(
    modelName: td[0].toString(),
    published: td[1].toString(),
    aucJudd: _getNumberForMetric(td, Metric.aucJudd, dataSource),
    sim: _getNumberForMetric(td, Metric.sim, dataSource),
    emd: _getNumberForMetric(td, Metric.emd, dataSource),
    aucBorji: _getNumberForMetric(td, Metric.aucBorji, dataSource),
    sAUC: _getNumberForMetric(td, Metric.sAUC, dataSource),
    cc: _getNumberForMetric(td, Metric.cc, dataSource),
    nss: _getNumberForMetric(td, Metric.nss, dataSource),
    kl: _getNumberForMetric(td, Metric.kl, dataSource),
    ig: _getNumberForMetric(td, Metric.ig, dataSource),
    json: td,
    dataSource: dataSource,
  );
}

List<ModelResults> _modelResultsFromJsonList(
    List<dynamic> jsonList, String dataSource) {
  return jsonList
      .map((e) => _modelResultsFromJson(e, dataSource))
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
}

String _sanitizeString(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

class _ModelNameQuery {
  final List<String> queries;
  final String displayName;

  const _ModelNameQuery(this.queries, this.displayName);

  bool matches(ModelResults modelResults) {
    for (var query in queries) {
      final sanitizedQuery = _sanitizeString(query);
      final sanitizedModelName = _sanitizeString(modelResults.modelName);

      final hasMatch =
          RegExp('(?<!\\w)$sanitizedQuery(?!\\w)').hasMatch(sanitizedModelName);

      if (hasMatch) {
        return true;
      }
    }

    return false;
  }
}

ModelResults? _findModelResultsFromQuery(
    _ModelNameQuery query, List<ModelResults> modelResults) {
  return modelResults
      .map<ModelResults?>((e) => e)
      .firstWhere((element) => query.matches(element!), orElse: () => null);
}

String _changeStringFloatPrecision(String input, int precision) {
  final number = double.tryParse(input);

  if (number == null) {
    return input.padRight(precision + 2);
  }

  return sprintf('%.${precision}f', [number]);
}

String _getMetricStringForTableRow(ModelResults modelResults) {
  const metrics = [
    Metric.aucJudd,
    Metric.sim,
    Metric.emd,
    Metric.aucBorji,
    Metric.sAUC,
    Metric.cc,
    Metric.nss,
    Metric.kl,
  ];

  return metrics.map((e) {
    final raw = modelResults.getMetric(e);
    return _changeStringFloatPrecision(raw, 2);
  }).join(' & ');
}

String _generateLaTeXTableRowLineForModelNameQuery(
    _ModelNameQuery query, List<ModelResults> modelResults,
    {int nameLength = 0}) {
  final modelResultsForQuery = _findModelResultsFromQuery(query, modelResults);

  if (modelResultsForQuery == null) {
    return "% “${query.displayName}” missing";
  }

  final paddedDisplayName = query.displayName.padRight(nameLength);

  return '$paddedDisplayName & ${_getMetricStringForTableRow(modelResultsForQuery)} \\\\ '
      '% ${modelResultsForQuery.readableName} (${modelResultsForQuery.dataSource})';
}

bool _isModelInQueryList(
    ModelResults modelResults, List<_ModelNameQuery> queryList) {
  return queryList.any((element) => element.matches(modelResults));
}

String _getPointColor(bool isModelSelected, String dataSource) {
  if (dataSource == 'mit') {
    return isModelSelected ? 'black' : 'black!30';
  }

  return isModelSelected ? 'SteelBlue' : 'SteelBlue!30';
}

String _generatePerformancePlot(List<ModelResults> modelResults,
    List<_ModelNameQuery> selectedModels, String dataset) {
  var backgroundElementsString = '';
  var foregroundElementsString = '';

  // sort model results by release year
  final sortedModelResults = modelResults
      .where((e) => e.releaseYear != null)
      .toList()
    ..sort((a, b) => a.releaseYear!.compareTo(b.releaseYear!));

  final earliestReleaseDate = int.parse(sortedModelResults.first.releaseYear!);
  final latestReleaseDate = int.parse(sortedModelResults.last.releaseYear!);

  const xMin = 0.0;
  const xMax = 12.0;

  final worstPerformance =
      sortedModelResults.map((e) => double.parse(e.nss)).reduce(min);
  final bestPerformance =
      sortedModelResults.map((e) => double.parse(e.nss)).reduce(max);

  const yMin = 0.0;
  const yMax = 15.0;

  for (var model in sortedModelResults) {
    final releaseDate = int.parse(model.releaseYear!);
    final x =
        releaseDate.remap(earliestReleaseDate, latestReleaseDate, xMin, xMax);
    final y = double.parse(model.nss)
        .remap(worstPerformance, bestPerformance, yMin, yMax);

    final name = model.readableName.sanitize();

    final isModelSelected = _isModelInQueryList(model, selectedModels);

    final color = _getPointColor(isModelSelected, model.dataSource);
    final fontSize = isModelSelected ? 'small' : 'tiny';
    final nodeSize = isModelSelected ? '2pt' : '1.75pt';

    final addedElementString =
        '\\filldraw[$color] ($x, $y) circle ($nodeSize) node[anchor=west]{\\$fontSize $name};\n';

    if (isModelSelected) {
      foregroundElementsString += addedElementString;
    } else {
      backgroundElementsString += addedElementString;
    }
  }

  foregroundElementsString += '\\draw[black, thick] (0,0) -- ($xMax,0);\n';
  foregroundElementsString += '\\draw[black, thick] (0,0) -- (0,$yMax);\n';

  // draw year lines and numbers
  for (int i = earliestReleaseDate; i <= latestReleaseDate; i += 1) {
    final x = i.remap(earliestReleaseDate, latestReleaseDate, xMin, xMax);
    foregroundElementsString += '\\draw[black, thick] ($x,-0.1) -- ($x,0.1);\n'
        '\\node[rotate=270] at ($x,-0.75) {$i};\n';
  }

  // draw performance lines and numbers
  for (double i = 0.0; i <= 1.0; i += 0.1) {
    final performance = i.remap(0.0, 1.0, worstPerformance, bestPerformance);
    final y = performance.remap(worstPerformance, bestPerformance, yMin, yMax);

    final performanceString = sprintf('%.2f', [performance]);
    foregroundElementsString += '\\draw[black, thick] (-0.1,$y) -- (0.1,$y);\n'
        '\\node at (-0.75,$y) {$performanceString};\n';
  }

  return '\\begin{figure}\n'
      '\\centering\n'
      '\\begin{tikzpicture}\n'
      '$backgroundElementsString'
      '$foregroundElementsString'
      '\\end{tikzpicture}\n'
      '\\label{fig:mit300_nss_perf_plot}\n'
      '\\caption{Performance of various saliency map prediction models, measured by the NSS score each model achieved '
      'on the ${dataset.toUpperCase()} dataset. '
      'Performance measurements are taken from \\cite{mit-saliency-benchmark, mit-tuebingen-saliency-benchmark} '
      'and are colored in \\textcolor{black}{black} or \\textcolor{SteelBlue}{blue}, respectively. '
      'Models drawn with a dark color are present in Table~\\ref{tab:mit300_perf}. '
      'Only models whose release date is present in \\cite{mit-saliency-benchmark, mit-tuebingen-saliency-benchmark} '
      'are included. '
      'The code that was used to generate this figure is available at: \\url{'
      'https://github.com/Adrian-Samoticha/mit_saliency_benchmark_extractor}}\n'
      '\\end{figure}\n';
}

List<ModelResults> _getModelResultsFromJson(dynamic json, String dataSource) {
  if (json == null) {
    return const [];
  }

  final tbody = json['tbody'];
  final tr = tbody['tr'];

  return _modelResultsFromJsonList(tr, dataSource);
}

Future<void> _printLatexTableRowLinesForDataset(
    String dataset, Task task) async {
  final mitJson = await _readJsonFile('./data/${dataset}_results.json');
  final tuebingenJson =
      await _readJsonFile('./data/${dataset}_results_tuebingen.json');

  final mitModelResults = _getModelResultsFromJson(mitJson, 'mit');
  final tuebingenModelResults =
      _getModelResultsFromJson(tuebingenJson, 'tuebingen');

  final modelResults = [
    ...mitModelResults,
    ...tuebingenModelResults,
  ];

  const selectedModels = [
    _ModelNameQuery(["EML-Net"], "EML-Net \\cite{jia2019emlnetan}"),
    _ModelNameQuery(["SAM-ResNet"], "SAM-ResNet \\cite{8400593}"),
    _ModelNameQuery(["SAM-VGG"], "SAM-VGG \\cite{8400593}"),
    _ModelNameQuery(["PDP"], "PDP \\cite{jetley2018endtoend}"),
    _ModelNameQuery(["ML-Net"], "ML-Net \\cite{Cornia2016ADM}"),
    _ModelNameQuery(["DeepFix"], "DeepFix \\cite{7937829}"),
    _ModelNameQuery(["SalGAN"], "SalGAN \\cite{Pan_2017_SalGAN}"),
    _ModelNameQuery(["SalNet"], "Pan (deep) \\cite{7780440}"),
    _ModelNameQuery(["JuntingNet"], "Pan (shallow) \\cite{7780440}"),
    _ModelNameQuery(["Mr-CNN"], "Mr-CNN \\cite{7298633}"),
    _ModelNameQuery(["SALICON"], "SALICON \\cite{7410395}"),
    _ModelNameQuery(
      [
        "Deep Gaze 2",
        "DeepGaze II",
      ],
      "Deep Gaze~II \\cite{kümmerer2015deep}",
    ),
    _ModelNameQuery(
      [
        "Deep Gaze 1",
        "DeepGaze I",
      ],
      "Deep Gaze~I \\cite{kümmerer2015deep}",
    ),
    _ModelNameQuery(["eDN"], "eDN \\cite{6909754}"),
    _ModelNameQuery(["BMS"], "BMS \\cite{6751128}"),
    _ModelNameQuery(["Judd Model"], "Judd \\cite{5459462}"),
    _ModelNameQuery(["Hou \\& Zhang"], "Hou \\& Zhang \\cite{4270292}"),
    _ModelNameQuery(["GBVS"], "GBVS \\cite{NIPS2006_4db0f8b0}"),
    _ModelNameQuery(["IttiKoch"], "Itti et al. \\cite{730558}"),
  ];

  switch (task) {
    case Task.generateTableRows:
      final longestDisplayName =
          selectedModels.map((e) => e.displayName.length).reduce(max);

      for (var model in selectedModels) {
        final latexLine = _generateLaTeXTableRowLineForModelNameQuery(
            model, modelResults,
            nameLength: longestDisplayName);
        print(latexLine);
      }

    case Task.generatePerformancePlot:
      final plot =
          _generatePerformancePlot(modelResults, selectedModels, dataset);
      print(plot);
  }
}

void main(List<String> arguments) {
  final dataset = arguments.first;
  final task =
      Task.values.firstWhere((element) => element.name == arguments[1]);

  _printLatexTableRowLinesForDataset(dataset, task);
}
