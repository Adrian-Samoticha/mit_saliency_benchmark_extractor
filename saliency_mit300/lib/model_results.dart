class ModelResults {
  final String modelName;
  final String aucJudd;
  final String sim;
  final String emd;
  final String aucBorji;
  final String sAUC;
  final String cc;
  final String nss;
  final String kl;

  const ModelResults(
      {required this.modelName,
      required this.aucJudd,
      required this.sim,
      required this.emd,
      required this.aucBorji,
      required this.sAUC,
      required this.cc,
      required this.nss,
      required this.kl});

  @override
  String toString() {
    return 'ModelResults(modelName: $modelName, aucJudd: $aucJudd, sim: $sim, emd: $emd, aucBorji: $aucBorji, sAUC: '
        '$sAUC, cc: $cc, nss: $nss, kl: $kl)';
  }
}
