class FitbitHeartRateReading {
  const FitbitHeartRateReading({
    required this.value,
    required this.isResting,
    required this.isHistorical,
  });

  final int? value;
  final bool isResting;
  final bool isHistorical;
}

FitbitHeartRateReading readFitbitHeartRate(Map<String, dynamic>? metrics) {
  final intraday = _asMap(metrics?['heartRateIntraday']);
  final intradayPayload = _asMap(intraday?['activities-heart-intraday']);
  final dataset = _asList(intradayPayload?['dataset']);

  for (final sample in dataset.reversed) {
    final reading = _asInt(_asMap(sample)?['value']);
    if (reading != null) {
      return FitbitHeartRateReading(
        value: reading,
        isResting: false,
        isHistorical: false,
      );
    }
  }

  final heartRate = _asMap(metrics?['heartRate']);
  final activities = _asList(heartRate?['activities-heart']);
  final today = activities.isNotEmpty ? _asMap(activities.first) : null;
  final value = _asMap(today?['value']);

  final restingHeartRate = _asInt(value?['restingHeartRate']);
  if (restingHeartRate != null) {
    return FitbitHeartRateReading(
      value: restingHeartRate,
      isResting: true,
      isHistorical: false,
    );
  }

  final historicalRestingHeartRate = _readRecentRestingHeartRate(
    _asMap(metrics?['heartRateHistory']),
  );
  if (historicalRestingHeartRate != null) {
    return FitbitHeartRateReading(
      value: historicalRestingHeartRate,
      isResting: true,
      isHistorical: true,
    );
  }

  return const FitbitHeartRateReading(
    value: null,
    isResting: false,
    isHistorical: false,
  );
}

int? _readRecentRestingHeartRate(Map<String, dynamic>? heartRateHistory) {
  final historicalActivities = _asList(heartRateHistory?['activities-heart']);
  for (final activity in historicalActivities.reversed) {
    final value = _asMap(_asMap(activity)?['value']);
    final restingHeartRate = _asInt(value?['restingHeartRate']);
    if (restingHeartRate != null) {
      return restingHeartRate;
    }
  }

  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  return null;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const [];
}

int? _asInt(dynamic value) {
  if (value is num) {
    return value.round();
  }

  if (value is String) {
    final parsedValue = num.tryParse(value);
    return parsedValue?.round();
  }

  return null;
}
