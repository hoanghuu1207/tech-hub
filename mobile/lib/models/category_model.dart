class Category {
  final String id;
  final String name;
  final String icon;
  final String description;
  final int itemCount;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.itemCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      description: json['description'] as String,
      itemCount: json['item_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'item_count': itemCount,
    };
  }
}
