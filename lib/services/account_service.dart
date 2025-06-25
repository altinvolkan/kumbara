import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class AccountService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Map<String, dynamic>> getMainAccount(int userId) async {
    debugPrint('Getting main account for user: $userId');
    final db = await _db.database;

    final accounts = await db.query(
      'main_accounts',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    debugPrint('Found main accounts: $accounts');

    if (accounts.isEmpty) {
      debugPrint('No main account found');
      throw Exception('Main account not found');
    }

    debugPrint('Returning main account: ${accounts.first}');
    return accounts.first;
  }

  Future<List<Map<String, dynamic>>> getSavingsAccounts(int userId) async {
    debugPrint('Getting savings accounts for user: $userId');
    final db = await _db.database;

    final accounts = await db.query(
      'savings_accounts',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    debugPrint('Found savings accounts: $accounts');
    return accounts;
  }

  Future<Map<String, dynamic>> createSavingsAccount({
    required int userId,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
  }) async {
    debugPrint('Creating savings account: $name for user: $userId');
    final db = await _db.database;

    final now = DateTime.now().toIso8601String();
    final id = await db.insert('savings_accounts', {
      'user_id': userId,
      'name': name,
      'balance': 0.0,
      'target_amount': targetAmount,
      'target_date': targetDate.toIso8601String(),
      'created_at': now,
    });
    debugPrint('Savings account created with ID: $id');

    final account = await db.query(
      'savings_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Returning new savings account: ${account.first}');
    return account.first;
  }

  Future<void> deposit({
    required int accountId,
    required double amount,
    required bool isMainAccount,
  }) async {
    debugPrint(
      'Depositing $amount to ${isMainAccount ? "main" : "savings"} account: $accountId',
    );
    final db = await _db.database;

    final table = isMainAccount ? 'main_accounts' : 'savings_accounts';
    await db.transaction((txn) async {
      final accounts = await txn.query(
        table,
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (accounts.isEmpty) {
        debugPrint('Account not found');
        throw Exception('Account not found');
      }

      final currentBalance = accounts.first['balance'] as double;
      final newBalance = currentBalance + amount;
      debugPrint('Updating balance: $currentBalance -> $newBalance');

      await txn.update(
        table,
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      await txn.insert('transactions', {
        'account_id': accountId,
        'type': 'deposit',
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    debugPrint('Deposit completed');
  }

  Future<void> withdraw({
    required int accountId,
    required double amount,
    required bool isMainAccount,
  }) async {
    debugPrint(
      'Withdrawing $amount from ${isMainAccount ? "main" : "savings"} account: $accountId',
    );
    final db = await _db.database;

    final table = isMainAccount ? 'main_accounts' : 'savings_accounts';
    await db.transaction((txn) async {
      final accounts = await txn.query(
        table,
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (accounts.isEmpty) {
        debugPrint('Account not found');
        throw Exception('Account not found');
      }

      final currentBalance = accounts.first['balance'] as double;
      if (currentBalance < amount) {
        debugPrint('Insufficient funds: $currentBalance < $amount');
        throw Exception('Insufficient funds');
      }

      final newBalance = currentBalance - amount;
      debugPrint('Updating balance: $currentBalance -> $newBalance');

      await txn.update(
        table,
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      await txn.insert('transactions', {
        'account_id': accountId,
        'type': 'withdraw',
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    debugPrint('Withdrawal completed');
  }

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required bool isFromMainAccount,
    required bool isToMainAccount,
  }) async {
    debugPrint(
      'Transferring $amount from account $fromAccountId to account $toAccountId',
    );
    final db = await _db.database;

    final fromTable = isFromMainAccount ? 'main_accounts' : 'savings_accounts';
    final toTable = isToMainAccount ? 'main_accounts' : 'savings_accounts';

    await db.transaction((txn) async {
      // Check and update source account
      final fromAccounts = await txn.query(
        fromTable,
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      if (fromAccounts.isEmpty) {
        debugPrint('Source account not found');
        throw Exception('Source account not found');
      }

      final fromBalance = fromAccounts.first['balance'] as double;
      if (fromBalance < amount) {
        debugPrint('Insufficient funds: $fromBalance < $amount');
        throw Exception('Insufficient funds');
      }

      await txn.update(
        fromTable,
        {'balance': fromBalance - amount},
        where: 'id = ?',
        whereArgs: [fromAccountId],
      );

      // Check and update destination account
      final toAccounts = await txn.query(
        toTable,
        where: 'id = ?',
        whereArgs: [toAccountId],
      );

      if (toAccounts.isEmpty) {
        debugPrint('Destination account not found');
        throw Exception('Destination account not found');
      }

      final toBalance = toAccounts.first['balance'] as double;
      await txn.update(
        toTable,
        {'balance': toBalance + amount},
        where: 'id = ?',
        whereArgs: [toAccountId],
      );

      // Record transaction
      await txn.insert('transactions', {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'type': 'transfer',
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    debugPrint('Transfer completed');
  }
}
