import 'package:auto_split/ui/payee_logo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Made-up names and numbers only.
  final contacts = <PhoneContact>[
    (id: 1, name: 'Rahul Kumar', phones: ['9876543210']),
    (id: 2, name: 'Priya Sharma', phones: []),
    (id: 3, name: 'Priya Iyer', phones: []),
    (id: 4, name: 'Anil K. Mehta', phones: ['9123456780']),
  ];

  ContactQuery q({List<String> phones = const [], List<String> names = const [], bool loose = false}) =>
      (phones: phones, names: names, loose: loose);

  test('a number matches exactly', () {
    expect(ContactMatcher.match(q(phones: ['9123456780']), contacts), 4);
    expect(ContactMatcher.match(q(phones: ['9000000000']), contacts), isNull);
  });

  test('finds a number in a UPI id or text', () {
    expect(ContactMatcher.phoneIn('919876543210'), '9876543210');
    expect(ContactMatcher.phoneIn('rahul.k'), isNull);
  });

  test('names ignore case, order, punctuation and honorifics', () {
    expect(ContactMatcher.match(q(names: ['MR RAHUL KUMAR']), contacts), 1);
    expect(ContactMatcher.match(q(names: ['KUMAR RAHUL']), contacts), 1);
    expect(ContactMatcher.match(q(names: ['MEHTA ANIL']), contacts), 4);
  });

  test('names cut short and initials still match', () {
    expect(ContactMatcher.match(q(names: ['RAHUL KUMA']), contacts), 1);
    expect(ContactMatcher.match(q(names: ['R KUMAR']), contacts), 1);
  });

  test('a name that fits two contacts matches none', () {
    expect(ContactMatcher.match(q(names: ['Priya'], loose: true), contacts), isNull);
    expect(ContactMatcher.match(q(names: ['Priya Sharma']), contacts), 2);
  });

  test('one-word names only match when loose', () {
    expect(ContactMatcher.match(q(names: ['Rahul']), contacts), isNull);
    expect(ContactMatcher.match(q(names: ['Rahul'], loose: true), contacts), 1);
  });

  test('extra words the contact lacks do not match', () {
    expect(ContactMatcher.match(q(names: ['Rahul Kumar Stores']), contacts), isNull);
  });
}
