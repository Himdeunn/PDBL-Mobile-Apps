class User {
  int? id;
  String? name;
  String? email;
  String? avatar;
  String? avatarUrl;
  bool isGuest = false;
  DateTime? loginAt;
  int todayTarget = 0;

  User();

  User.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      email = json['email'],
      avatar = json['avatar'] ?? json['avatar_url'],
      avatarUrl = json['avatar_url'] ?? json['avatar'],
      isGuest = json['isGuest'] ?? false,
      todayTarget = (json['today_target'] as num?)?.toInt() ?? 0,
      loginAt = json['loginAt'] != null
          ? DateTime.parse(json['loginAt'])
          : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar': avatar,
    'avatar_url': avatarUrl,
    'isGuest': isGuest,
    'today_target': todayTarget,
    'loginAt': loginAt?.toIso8601String(),
  };
}
