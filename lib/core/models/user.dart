class User {
  String? name;
  String? email;
  bool isGuest = false;
  DateTime? loginAt;

  User();

  User.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        email = json['email'],
        isGuest = json['isGuest'] ?? false,
        loginAt = json['loginAt'] != null ? DateTime.parse(json['loginAt']) : null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'isGuest': isGuest,
        'loginAt': loginAt?.toIso8601String(),
      };
}
