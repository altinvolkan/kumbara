import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/account_service.dart';
import 'children_management_screen.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _accountService = AccountService();
  Map<String, dynamic>? _mainAccount;
  List<Map<String, dynamic>> _savingsAccounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    debugPrint('Loading accounts...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.getCurrentUser();
      debugPrint('Current user: ${user?.toMap()}');

      if (user == null) {
        debugPrint('No user found, redirecting to login');
        Get.offAllNamed('/login');
        return;
      }

      final mainAccount = await _accountService.getMainAccount(user.id!);
      debugPrint('Main account: $mainAccount');

      final savingsAccounts = await _accountService.getSavingsAccounts(
        user.id!,
      );
      debugPrint('Savings accounts: $savingsAccounts');

      if (mounted) {
        setState(() {
          _mainAccount = mainAccount;
          _savingsAccounts = savingsAccounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showDepositDialog() async {
    final controller = TextEditingController();
    final result = await Get.dialog<double>(
      AlertDialog(
        title: const Text('Para Yatır'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Miktar (₺)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Get.back(result: amount);
              }
            },
            child: const Text('Yatır'),
          ),
        ],
      ),
    );

    if (result != null && _mainAccount != null) {
      try {
        final newBalance = (_mainAccount!['balance'] as double) + result;
        await _accountService.updateMainAccountBalance(
          _mainAccount!['id'] as int,
          newBalance,
        );
        _loadAccounts();
      } catch (e) {
        Get.snackbar(
          'Error',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showWithdrawDialog() async {
    final controller = TextEditingController();
    final result = await Get.dialog<double>(
      AlertDialog(
        title: const Text('Para Çek'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Miktar (₺)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Get.back(result: amount);
              }
            },
            child: const Text('Çek'),
          ),
        ],
      ),
    );

    if (result != null && _mainAccount != null) {
      if ((_mainAccount!['balance'] as double) < result) {
        Get.snackbar(
          'Hata',
          'Yetersiz bakiye',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      try {
        final newBalance = (_mainAccount!['balance'] as double) - result;
        await _accountService.updateMainAccountBalance(
          _mainAccount!['id'] as int,
          newBalance,
        );
        _loadAccounts();
      } catch (e) {
        Get.snackbar(
          'Error',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showCreateSavingsAccountDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;

    final result = await Get.dialog<Map<String, dynamic>>(
      AlertDialog(
        title: const Text('Yeni Birikim Hesabı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Hesap Adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hedef Miktar (₺)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (date != null) {
                  selectedDate = date;
                }
              },
              child: const Text('Hedef Tarih Seç'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (nameController.text.isNotEmpty &&
                  amount != null &&
                  amount > 0 &&
                  selectedDate != null) {
                Get.back(
                  result: {
                    'name': nameController.text,
                    'targetAmount': amount,
                    'targetDate': selectedDate,
                  },
                );
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          await _accountService.createSavingsAccount(
            userId: user.id!,
            name: result['name'],
            targetAmount: result['targetAmount'],
            targetDate: result['targetDate'],
          );
          _loadAccounts();
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kumbara'),
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom),
            onPressed: () => Get.to(() => const ChildrenManagementScreen()),
            tooltip: 'Çocuk Hesapları',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAccounts),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              Get.offAllNamed('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hata: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAccounts,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ana Hesap',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₺${_mainAccount?['balance']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showDepositDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Para Yatır'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showWithdrawDialog,
                                        icon: const Icon(Icons.remove),
                                        label: const Text('Para Çek'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Birikim Hesapları',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _savingsAccounts.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _savingsAccounts.length) {
                                return Card(
                                  child: ListTile(
                                    title: const Text('Yeni Birikim Hesabı'),
                                    leading: const Icon(Icons.add),
                                    onTap: _showCreateSavingsAccountDialog,
                                  ),
                                );
                              }

                              final account = _savingsAccounts[index];
                              final progress = (account['balance'] as double) /
                                  (account['target_amount'] as double);
                              final targetDate = DateTime.parse(
                                account['target_date'] as String,
                              );
                              final daysLeft =
                                  targetDate.difference(DateTime.now()).inDays;

                              return Card(
                                child: ListTile(
                                  title: Text(account['name'] as String),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      LinearProgressIndicator(value: progress),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₺${account['balance']?.toStringAsFixed(2)} / ₺${account['target_amount']?.toStringAsFixed(2)}',
                                      ),
                                      Text('$daysLeft gün kaldı'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.arrow_forward),
                                    onPressed: () {
                                      // TODO: Hesap detayları ve transfer
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
