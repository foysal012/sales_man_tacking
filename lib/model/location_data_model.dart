class LocationModel {
  final int? id;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? timestamp;

  LocationModel({
    this.id,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.timestamp,
  });

  // Convert a LocationModel into a Map (for saving to services or JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  // Create a LocationModel from a Map (from services or JSON)
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
    );
  }
}
