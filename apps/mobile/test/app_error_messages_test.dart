import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/app_error.dart';

void main() {
  group('AppError.message turns exceptions into plain language', () {
    test('network failures mention the connection, never the raw exception', () {
      final msg = AppError.message(const SocketException('Failed host lookup'), action: 'save the shop');
      expect(msg, startsWith("Couldn't save the shop."));
      expect(msg, contains('internet connection'));
      expect(msg, isNot(contains('SocketException')));
      expect(AppError.message(TimeoutException('slow')), contains('internet connection'));
    });

    test('billing blocked and stock errors pass their own message through', () {
      expect(AppError.message(const BillingBlockedException('Upgrade to bill.')), 'Upgrade to bill.');
      expect(AppError.message(InsufficientStockException('Soap: 2 left')), 'Not enough stock: Soap: 2 left');
    });

    test('Postgres error codes are mapped to readable reasons', () {
      expect(
        AppError.message(const PostgrestException(message: 'dup key', code: '23505'), action: 'save the product'),
        "Couldn't save the product. This record already exists (duplicate number or name).",
      );
      expect(AppError.message(const PostgrestException(message: 'denied', code: '42501')), contains("don't have permission"));
      expect(AppError.message(const PostgrestException(message: 'Tenant is inactive', code: 'P0001')), 'Tenant is inactive');
      expect(AppError.message(const PostgrestException(message: 'weird internal', code: 'XX000')),
          'The server rejected the request. Please try again.');
    });

    test('auth errors are friendly', () {
      expect(AppError.message(const AuthException('Invalid login credentials')), 'Incorrect email or password.');
      expect(AppError.message(const AuthException('Email not confirmed')), contains('confirm your email'));
    });

    test('Dart prefixes are stripped and plain strings pass through', () {
      expect(AppError.message(StateError('Please sign in again.')), 'Please sign in again.');
      expect(AppError.message('Please enter a shop / outlet name'), 'Please enter a shop / outlet name');
    });

    test('unreadable errors fall back to a generic sentence', () {
      expect(AppError.message(Object(), action: 'load orders'), "Couldn't load orders. Something went wrong. Please try again.");
    });
  });

  group('AppState billing policy', () {
    test('billing is allowed on an active plan and blocked reason is null', () {
      final s = AppState(loadMockData: false);
      s.tenant = s.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
        subscriptionEndDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(s.billingBlockReason, isNull);
      expect(s.ensureCanCreateBills, returnsNormally);
    });

    test('plan restrictions surface their message', () {
      expect(AppError.message(const PlanRestrictionException('Plan ended.')), 'Plan ended.');
    });
  });
}
