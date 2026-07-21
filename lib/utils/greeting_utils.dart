// lib/core/utils/greeting_utils.dart

class GreetingUtils {
  /// Returns a time-appropriate greeting based on the device's current hour.
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return "Good morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good afternoon";
    } else if (hour >= 17 && hour < 21) {
      return "Good evening";
    } else {
      return "Good night";
    }
  }

  /// Small emoji that matches the time of day — purely cosmetic.
  static String getGreetingEmoji() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) return "☀️";
    if (hour >= 12 && hour < 17) return "🌤️";
    if (hour >= 17 && hour < 21) return "🌇";
    return "🌙";
  }
}