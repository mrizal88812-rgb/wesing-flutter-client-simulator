class User {
  final String id;
  final String username;
  final String avatar;
  final String? bio;
  final int followersCount;
  final int level;
  final int coins;

  User({
    required this.id,
    required this.username,
    required this.avatar,
    this.bio,
    required this.followersCount,
    required this.level,
    required this.coins,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      avatar: json['avatar'] as String,
      bio: json['bio'] as String?,
      followersCount: json['followersCount'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      coins: json['coins'] as int? ?? 0,
    );
  }
}
