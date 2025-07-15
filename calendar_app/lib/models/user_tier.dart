enum UserTier {
  tier1, // Full access - can see all views and edit data
  tier2, // Limited access - only yearly view, read-only
}

extension UserTierExtension on UserTier {
  String get name {
    switch (this) {
      case UserTier.tier1:
        return 'tier1';
      case UserTier.tier2:
        return 'tier2';
    }
  }

  String get displayName {
    switch (this) {
      case UserTier.tier1:
        return 'Tier 1 - Full Access';
      case UserTier.tier2:
        return 'Tier 2 - View Only';
    }
  }

  String get description {
    switch (this) {
      case UserTier.tier1:
        return 'Full access to all features: week view, employee management, vacation editing';
      case UserTier.tier2:
        return 'Limited access: yearly view only, read-only mode';
    }
  }

  bool get canAccessWeekView => this == UserTier.tier1;
  bool get canAccessEmployeeSettings => this == UserTier.tier1;
  bool get canEditData => this == UserTier.tier1;
  bool get canAccessYearView => true; // Both tiers can access year view
}

class UserProfile {
  final String id;
  final String email;
  final UserTier tier;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.tier,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      tier: UserTier.values.byName(json['tier'] as String? ?? 'tier1'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'tier': tier.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 