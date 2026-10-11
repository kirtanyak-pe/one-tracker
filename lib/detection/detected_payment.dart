class DetectedPayment {
  const DetectedPayment({
    required this.id,
    required this.amountMinor,
    required this.merchant,
    required this.sourceApp,
    required this.detectedAt,
  });

  final String id;
  final int amountMinor;
  final String? merchant;

  /// Android package that posted the notification (e.g. com.phonepe.app).
  final String sourceApp;
  final DateTime detectedAt;

  factory DetectedPayment.fromJson(Map<String, dynamic> json) => DetectedPayment(
        id: json['id'] as String,
        amountMinor: json['amountMinor'] as int,
        merchant: json['merchant'] as String?,
        sourceApp: json['sourceApp'] as String,
        detectedAt: DateTime.parse(json['detectedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amountMinor': amountMinor,
        'merchant': merchant,
        'sourceApp': sourceApp,
        'detectedAt': detectedAt.toIso8601String(),
      };
}
