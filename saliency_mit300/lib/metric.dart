enum Metric {
  aucJudd,
  sim,
  emd,
  aucBorji,
  sAUC,
  cc,
  nss,
  kl,
  ig,
}

int? metricToIndex(Metric metric, String source) {
  if (source == 'mit') {
    switch (metric) {
      case Metric.aucJudd:
        return 3;
      case Metric.sim:
        return 4;
      case Metric.emd:
        return 5;
      case Metric.aucBorji:
        return 6;
      case Metric.sAUC:
        return 7;
      case Metric.cc:
        return 8;
      case Metric.nss:
        return 9;
      case Metric.kl:
        return 10;
      default:
        return null;
    }
  }

  switch (metric) {
    case Metric.aucJudd:
      return 4;
    case Metric.sim:
      return 9;
    case Metric.ig:
      return 3;
    case Metric.sAUC:
      return 5;
    case Metric.cc:
      return 7;
    case Metric.nss:
      return 6;
    case Metric.kl:
      return 8;
    default:
      return null;
  }
}
