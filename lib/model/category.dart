import 'package:flutter/material.dart';

enum Category {
  food('Food & drinks', Icons.restaurant_outlined),
  groceries('Groceries', Icons.local_grocery_store_outlined),
  transport('Transport', Icons.directions_car_outlined),
  shopping('Shopping', Icons.shopping_bag_outlined),
  bills('Bills & utilities', Icons.receipt_long_outlined),
  entertainment('Entertainment', Icons.movie_outlined),
  health('Health', Icons.favorite_outline),
  travel('Travel', Icons.flight_outlined),
  people('People', Icons.person_outline),
  cash('Cash', Icons.local_atm_outlined),
  income('Income', Icons.south_west),
  other('Other', Icons.more_horiz);

  const Category(this.label, this.icon);

  final String label;
  final IconData icon;

  static Category? byName(String? name) =>
      Category.values.where((c) => c.name == name).firstOrNull;

  /// Categories a spend can be filed under (income is for credits).
  static List<Category> get spending =>
      values.where((c) => c != Category.income).toList();
}
