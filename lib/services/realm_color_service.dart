import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/realm_config.dart';

class RealmColorService {
  // Get primary color (custom or default)
  static Future<Color> getPrimaryColor(String realmName) async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt('realm_primary_$realmName');
    if (savedColor != null) return Color(savedColor);
    return RealmConfig.getPrimaryColor(realmName);
  }

  // Get accent color (custom or default)
  static Future<Color> getAccentColor(String realmName) async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt('realm_accent_$realmName');
    if (savedColor != null) return Color(savedColor);
    return RealmConfig.getAccentColor(realmName);
  }

  // Save primary color
  static Future<void> setPrimaryColor(String realmName, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('realm_primary_$realmName', color.value);
  }

  // Save accent color
  static Future<void> setAccentColor(String realmName, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('realm_accent_$realmName', color.value);
  }

  // Reset realm colors
  static Future<void> resetRealmColors(String realmName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('realm_primary_$realmName');
    await prefs.remove('realm_accent_$realmName');
  }

  // Reset all realm colors
  static Future<void> resetAllColors() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('realm_primary_') || key.startsWith('realm_accent_')) {
        await prefs.remove(key);
      }
    }
  }
}
