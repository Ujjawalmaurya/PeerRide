class RideModel {
  final String id;
  final int rideId;
  final String? riderId;
  final String? driverId;
  final LocationModel pickupLocation;
  final LocationModel dropLocation;
  final double fare;
  final String status;
  final String? blockchainTxHash;

  RideModel({
    required this.id,
    required this.rideId,
    this.riderId,
    this.driverId,
    required this.pickupLocation,
    required this.dropLocation,
    required this.fare,
    required this.status,
    this.blockchainTxHash,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['_id'],
      rideId: json['rideId'],
      riderId: json['riderId'] is Map ? json['riderId']['_id'] : json['riderId'],
      driverId: json['driverId'] is Map ? json['driverId']['_id'] : json['driverId'],
      pickupLocation: LocationModel.fromJson(json['pickupLocation']),
      dropLocation: LocationModel.fromJson(json['dropLocation']),
      fare: (json['fare'] as num).toDouble(),
      status: json['status'],
      blockchainTxHash: json['blockchainTxHash'],
    );
  }
}

class LocationModel {
  final double latitude;
  final double longitude;
  final String address;

  LocationModel({required this.latitude, required this.longitude, required this.address});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude, 'address': address};
  }
}
