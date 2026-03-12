class User {
  int? id;
  String? name;
  String? email;
  String? avatar;
  bool isGuest = false;
  DateTime? loginAt;

  User();

  User.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      email = json['email'],
      avatar = json['avatar'],
      isGuest = json['isGuest'] ?? false,
      loginAt = json['loginAt'] != null
          ? DateTime.parse(json['loginAt'])
          : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar': avatar,
    'isGuest': isGuest,
    'loginAt': loginAt?.toIso8601String(),
  };
}
