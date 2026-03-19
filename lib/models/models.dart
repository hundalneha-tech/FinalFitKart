import 'package:flutter/material.dart';

// lib/models/models.dart

class UserProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final String level;
  final int levelNum;
  final double totalCoins;
  final double inrValue;
  final int lifetimeSteps;
  final double lifetimeCalories;
  final bool isPro;
  final String rankTag; // "Top 5% this week"

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.level,
    required this.levelNum,
    required this.totalCoins,
    required this.inrValue,
    required this.lifetimeSteps,
    required this.lifetimeCalories,
    this.isPro = false,
    this.rankTag = '',
  });

  static UserProfile mock() => const UserProfile(
    id: 'user_001',
    name: 'Alex Stride',
    avatarUrl: '',
    level: 'Pro Walker',
    levelNum: 24,
    totalCoins: 12450,
    inrValue: 1245,
    lifetimeSteps: 1200000,
    lifetimeCalories: 45200,
    isPro: false,
    rankTag: 'Top 5% this week',
  );
}

class TodayActivity {
  final int steps;
  final int goalSteps;
  final double calories;
  final int activeMinutes;
  final double distanceKm;
  final double coinsEarned;
  final double inrEarned;

  const TodayActivity({
    required this.steps,
    required this.goalSteps,
    required this.calories,
    required this.activeMinutes,
    required this.distanceKm,
    required this.coinsEarned,
    required this.inrEarned,
  });

  double get progress => (steps / goalSteps).clamp(0.0, 1.0);

  static TodayActivity mock() => const TodayActivity(
    steps: 8432,
    goalSteps: 10000,
    calories: 420,
    activeMinutes: 52,
    distanceKm: 6.2,
    coinsEarned: 42.50,
    inrEarned: 14.20,
  );
}

class WeeklyData {
  final String day;
  final int steps;
  final double coins;

  const WeeklyData({required this.day, required this.steps, required this.coins});

  static List<WeeklyData> mockWeek() => const [
    WeeklyData(day: 'M', steps: 7200, coins: 36),
    WeeklyData(day: 'T', steps: 9100, coins: 45.5),
    WeeklyData(day: 'W', steps: 8500, coins: 42.5),
    WeeklyData(day: 'T', steps: 11200, coins: 56),
    WeeklyData(day: 'F', steps: 6800, coins: 34),
    WeeklyData(day: 'S', steps: 9400, coins: 47),
    WeeklyData(day: 'S', steps: 8432, coins: 42.5),
  ];

  static List<WeeklyData> mockMonths() => const [
    WeeklyData(day: 'Jun', steps: 7100, coins: 35.5),
    WeeklyData(day: 'Jul', steps: 8200, coins: 41),
    WeeklyData(day: 'Aug', steps: 7800, coins: 39),
    WeeklyData(day: 'Sep', steps: 9000, coins: 45),
    WeeklyData(day: 'Oct', steps: 8500, coins: 42.5),
    WeeklyData(day: 'Nov', steps: 10200, coins: 51),
    WeeklyData(day: 'Dec', steps: 11800, coins: 59),
  ];
}

class Perk {
  final String id;
  final String brand;
  final String category;
  final String description;
  final int coins;
  final double discount;
  final String discountLabel;
  final String imageUrl;
  final bool isFeatured;

  const Perk({
    required this.id,
    required this.brand,
    required this.category,
    required this.description,
    required this.coins,
    required this.discount,
    required this.discountLabel,
    required this.imageUrl,
    this.isFeatured = false,
  });

  static List<Perk> mockList() => const [
    Perk(id: '1', brand: 'Myntra',     category: 'Fashion',       description: 'Fashion & Lifestyle', coins: 450, discount: 500,  discountLabel: '₹500 OFF', imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400', isFeatured: true),
    Perk(id: '2', brand: 'Zomato',     category: 'Food',          description: 'Food Delivery',       coins: 180, discount: 200,  discountLabel: '₹200 OFF', imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400'),
    Perk(id: '3', brand: 'PVR Cinemas',category: 'Entertainment', description: 'Entertainment',       coins: 300, discount: 0,   discountLabel: 'Buy 1 Get 1', imageUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400'),
    Perk(id: '4', brand: 'Nykaa',      category: 'Beauty',        description: 'Beauty & Care',       coins: 220, discount: 25,  discountLabel: '25% OFF',  imageUrl: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=400'),
    Perk(id: '5', brand: 'Nike Store', category: 'Fashion',       description: 'Extra discount on footwear', coins: 500, discount: 20, discountLabel: '20% OFF', imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400', isFeatured: true),
    Perk(id: '6', brand: 'Starbucks',  category: 'Food',          description: 'Free beverage',       coins: 150, discount: 0,   discountLabel: 'Free Drink', imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400', isFeatured: true),
  ];
}

class Friend {
  final String id;
  final String name;
  final String avatarUrl;
  final int steps;
  final int streakDays;
  final bool isOnline;
  final String? activity;
  final double? nearbyKm;

  const Friend({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.steps,
    required this.streakDays,
    required this.isOnline,
    this.activity,
    this.nearbyKm,
  });

  static List<Friend> mockList() => const [
    Friend(id: '1', name: 'Arjun Mehta',   avatarUrl: '', steps: 12402, streakDays: 14, isOnline: true,  activity: 'Walking now', nearbyKm: 0.8),
    Friend(id: '2', name: 'Priya Sharma',  avatarUrl: '', steps: 9820,  streakDays: 8,  isOnline: true,  activity: 'Cycling',     nearbyKm: 1.2),
    Friend(id: '3', name: 'Marcus Chen',   avatarUrl: '', steps: 15100, streakDays: 21, isOnline: false, activity: null),
    Friend(id: '4', name: 'Sarah',         avatarUrl: '', steps: 42000, streakDays: 5,  isOnline: false, activity: null),
    Friend(id: '5', name: 'Rahul',         avatarUrl: '', steps: 39000, streakDays: 3,  isOnline: true,  activity: null),
  ];
}

class Challenge {
  final String id;
  final String title;
  final String type; // 'Steps' | 'Streak' | 'Distance'
  final String imageUrl;
  final int joined;
  final String timeLeft;
  final bool isJoined;
  final String? globalProgress; // "384,400 km"

  const Challenge({
    required this.id,
    required this.title,
    required this.type,
    required this.imageUrl,
    required this.joined,
    required this.timeLeft,
    this.isJoined = false,
    this.globalProgress,
  });

  static List<Challenge> mockList() => const [
    Challenge(id: '1', title: 'Weekend Warrior', type: 'Steps',  imageUrl: 'https://images.unsplash.com/photo-1541252260730-0412e8e2108e?w=400', joined: 1200, timeLeft: '2d left'),
    Challenge(id: '2', title: 'Morning Streak',  type: 'Streak', imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400', joined: 840,  timeLeft: '5d left'),
    Challenge(id: '3', title: 'Walk to the Moon', type: 'Distance', imageUrl: '', joined: 50000, timeLeft: 'Ongoing', isJoined: false, globalProgress: '384,400 km'),
  ];
}

class LeaderboardEntry {
  final int rank;
  final String name;
  final String avatarUrl;
  final int steps;
  final double inrEarned;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.steps,
    required this.inrEarned,
    this.isMe = false,
  });

  static List<LeaderboardEntry> mockList() => const [
    LeaderboardEntry(rank: 1, name: 'Alex M.',     avatarUrl: '', steps: 48500, inrEarned: 48.5),
    LeaderboardEntry(rank: 2, name: 'Sarah',        avatarUrl: '', steps: 42000, inrEarned: 42),
    LeaderboardEntry(rank: 3, name: 'Rahul',        avatarUrl: '', steps: 39000, inrEarned: 39),
    LeaderboardEntry(rank: 4, name: 'Priya Sharma', avatarUrl: '', steps: 35402, inrEarned: 40),
    LeaderboardEntry(rank: 5, name: 'You (Me)',     avatarUrl: '', steps: 32110, inrEarned: 35, isMe: true),
    LeaderboardEntry(rank: 6, name: 'David Chen',   avatarUrl: '', steps: 28900, inrEarned: 30),
  ];
}

class WalkSession {
  final DateTime date;
  final int steps;
  final double distanceKm;
  final double inrEarned;
  final int coinsEarned;
  final String type; // 'walk' | 'run' | 'cycle'

  const WalkSession({
    required this.date,
    required this.steps,
    required this.distanceKm,
    required this.inrEarned,
    required this.coinsEarned,
    required this.type,
  });

  static List<WalkSession> mockList() => [
    WalkSession(date: DateTime.now().subtract(const Duration(days: 1)), steps: 12432, distanceKm: 8.2, inrEarned: 24.50, coinsEarned: 72,  type: 'walk'),
    WalkSession(date: DateTime.now().subtract(const Duration(days: 2)), steps: 8102,  distanceKm: 5.4, inrEarned: 15.20, coinsEarned: 45,  type: 'run'),
    WalkSession(date: DateTime.now().subtract(const Duration(days: 3)), steps: 10500, distanceKm: 7.1, inrEarned: 20.00, coinsEarned: 60,  type: 'cycle'),
  ];
}

class Cause {
  final String id;
  final String title;
  final String imageUrl;
  final int targetCoins;
  final int currentCoins;

  const Cause({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.targetCoins,
    required this.currentCoins,
  });

  double get progress => currentCoins / targetCoins;

  static List<Cause> mockList() => const [
    Cause(id: '1', title: 'Clean Water Initiative', imageUrl: 'https://images.unsplash.com/photo-1541252260730-0412e8e2108e?w=300', targetCoins: 50000, currentCoins: 42500),
    Cause(id: '2', title: 'Plant a Forest',          imageUrl: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=300', targetCoins: 100000, currentCoins: 40000),
  ];
}

class ActivityFeedItem {
  final String userId;
  final String userName;
  final String avatarInitials;
  final Color avatarColor;
  final String action;
  final String badge;
  final String timeAgo;

  const ActivityFeedItem({
    required this.userId,
    required this.userName,
    required this.avatarInitials,
    required this.avatarColor,
    required this.action,
    required this.badge,
    required this.timeAgo,
  });
}
