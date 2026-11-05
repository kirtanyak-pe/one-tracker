import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

enum Category {
  food('Food & drinks', LucideIcons.utensils),
  groceries('Groceries', LucideIcons.shoppingCart),
  transport('Transport', LucideIcons.car),
  shopping('Shopping', LucideIcons.shoppingBag),
  bills('Bills & utilities', LucideIcons.receiptText),
  entertainment('Entertainment', LucideIcons.film),
  health('Health', LucideIcons.heart),
  travel('Travel', LucideIcons.plane),
  people('People', LucideIcons.user),
  cash('Cash', LucideIcons.banknote),
  income('Income', LucideIcons.arrowDownLeft),
  other('Other', LucideIcons.ellipsis);

  const Category(this.label, this.icon);

  final String label;
  final IconData icon;

  static Category? byName(String? name) =>
      Category.values.where((c) => c.name == name).firstOrNull;

  /// Categories a spend can be filed under (income is for credits).
  static List<Category> get spending =>
      values.where((c) => c != Category.income).toList();
}
