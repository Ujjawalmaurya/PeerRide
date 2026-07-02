class FareBreakdown {
  final double baseFare;
  final double distanceCharge;
  final double ambulanceTypeSurcharge;
  final double citySurcharge;
  final double total;

  FareBreakdown({
    required this.baseFare,
    required this.distanceCharge,
    required this.ambulanceTypeSurcharge,
    required this.citySurcharge,
    required this.total,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    return FareBreakdown(
      baseFare: (json['baseFare'] as num).toDouble(),
      distanceCharge: (json['distanceCharge'] as num).toDouble(),
      ambulanceTypeSurcharge: (json['ambulanceTypeSurcharge'] as num).toDouble(),
      citySurcharge: (json['citySurcharge'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseFare': baseFare,
      'distanceCharge': distanceCharge,
      'ambulanceTypeSurcharge': ambulanceTypeSurcharge,
      'citySurcharge': citySurcharge,
      'total': total,
    };
  }
}
