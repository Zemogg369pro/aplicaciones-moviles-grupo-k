/// Lugar cultural. Su código de registro es único. Tiene visitas.
class Place {
  final String id;
  final String name;
  final String category;
  final String municipality;
  final String address;
  final String description;
  final String schedule;
  final String image; // URL o recurso equivalente (se muestra un ícono si no hay red)
  final String code; // código de registro único (normalizado en mayúsculas)
  final bool active;

  const Place({
    required this.id, required this.name, required this.category, required this.municipality, required this.address,
    required this.description, required this.schedule, required this.image, required this.code, this.active = true,
  });

  Place copyWith({String? name, String? category, String? municipality, String? address, String? description,
          String? schedule, String? image, String? code, bool? active}) =>
      Place(
        id: id, name: name ?? this.name, category: category ?? this.category,
        municipality: municipality ?? this.municipality, address: address ?? this.address,
        description: description ?? this.description, schedule: schedule ?? this.schedule,
        image: image ?? this.image, code: code ?? this.code, active: active ?? this.active,
      );

  factory Place.fromMap(Map<String, dynamic> m) => Place(
        id: m['id'], name: m['name'], category: m['category'], municipality: m['municipality'],
        address: m['address'] ?? '', description: m['description'] ?? '', schedule: m['schedule'] ?? '',
        image: m['image'] ?? '', code: m['code'], active: m['active'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'category': category, 'municipality': municipality, 'address': address,
        'description': description, 'schedule': schedule, 'image': image, 'code': code, 'active': active,
      };
}
