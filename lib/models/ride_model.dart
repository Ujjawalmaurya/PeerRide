class Ride {
  final String id;
  final String riderId;
  final String? driverId;
  final String pickup;
  final String drop;
  final int distanceKm;
  final int fare;
  final String status;
  final String? txHash;
  final String? reserveTxHash;
  final String? releaseTxHash;

  Ride({
    required this.id,
    required this.riderId,
    this.driverId,
    required this.pickup,
    required this.drop,
    required this.distanceKm,
    required this.fare,
    required this.status,
    this.txHash,
    this.reserveTxHash,
    this.releaseTxHash,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] ?? '',
      riderId: json['riderId'] ?? '',
      driverId: json['driverId'],
      pickup: json['pickup'] ?? '',
      drop: json['drop'] ?? '',
      distanceKm: json['distanceKm'] ?? 0,
      fare: json['fare'] ?? 0,
      status: json['status'] ?? 'pending',
      txHash: json['txHash'],
      reserveTxHash: json['reserveTxHash'],
      releaseTxHash: json['releaseTxHash'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'riderId': riderId,
    'driverId': driverId,
    'pickup': pickup,
    'drop': drop,
    'distanceKm': distanceKm,
    'fare': fare,
    'status': status,
    'txHash': txHash,
    'reserveTxHash': reserveTxHash,
    'releaseTxHash': releaseTxHash,
  };
}
