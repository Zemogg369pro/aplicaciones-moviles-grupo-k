/// Favorito: la pareja usuario–lugar es única.
class Favorite {
  final String userId;
  final String placeId;
  const Favorite({required this.userId, required this.placeId});

  String get key => '$userId|$placeId';

  factory Favorite.fromMap(Map<String, dynamic> m) => Favorite(userId: m['userId'], placeId: m['placeId']);
  Map<String, dynamic> toMap() => {'userId': userId, 'placeId': placeId};
}
