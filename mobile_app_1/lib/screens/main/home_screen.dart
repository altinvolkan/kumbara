import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../services/account_service.dart';
import 'child_accounts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _accountService = AccountService();
  Map<String, dynamic>? _accountSummary;
  List<Map<String, dynamic>> _accounts = [];
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

      final accounts = await _accountService.getAccounts();
      debugPrint('Accounts: $accounts');

      final summary = await _accountService.getAccountSummary();
      debugPrint('Account summary: $summary');

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _accountSummary = summary;
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
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Para Yatır'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Miktar',
              prefixText: '₺',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen miktar girin';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Geçerli bir miktar girin';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Get.back(result: double.parse(controller.text));
              }
            },
            child: const Text('Yatır'),
          ),
        ],
      ),
    );

    if (amount != null && mounted && _accounts.isNotEmpty) {
      try {
        await _accountService.deposit(
          accountId: _accounts[0]['id'],
          amount: amount,
        );
        _loadAccounts();
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Para yatırma başarısız: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showWithdrawDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Para Çek'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Miktar',
              prefixText: '₺',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen miktar girin';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Geçerli bir miktar girin';
              }
              if (_accounts.isEmpty) {
                return 'Hesap bulunamadı';
              }
              final balance = (_accounts[0]['balance'] as num).toDouble();
              if (amount > balance) {
                return 'Yetersiz bakiye';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Get.back(result: double.parse(controller.text));
              }
            },
            child: const Text('Çek'),
          ),
        ],
      ),
    );

    if (amount != null && mounted && _accounts.isNotEmpty) {
      try {
        await _accountService.withdraw(
          accountId: _accounts[0]['id'],
          amount: amount,
        );
        _loadAccounts();
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Para çekme başarısız: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showTransferDialog(Map<String, dynamic> toAccount) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Para Transferi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hedef Hesap: ${toAccount['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Miktar',
                  prefixText: '₺',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen miktar girin';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Geçerli bir miktar girin';
                  }
                  if (_accounts.isEmpty) {
                    return 'Hesap bulunamadı';
                  }
                  final balance = (_accounts[0]['balance'] as num).toDouble();
                  if (amount > balance) {
                    return 'Yetersiz bakiye';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Get.back(result: double.parse(controller.text));
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (amount != null && mounted && _accounts.isNotEmpty) {
      try {
        debugPrint(
            'Transfer: From ${_accounts[0]['id']} to ${toAccount['id']} amount: $amount');
        await _accountService.transfer(
          fromAccountId: _accounts[0]['id'],
          toAccountId: toAccount['id'],
          amount: amount,
        );
        _loadAccounts();
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Transfer başarısız: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showCreateAccountDialog() async {
    final nameController = TextEditingController();
    final targetAmountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedType = 'savings';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Hesap Oluştur'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Hesap Adı',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen hesap adı girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Hesap Tipi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'savings', child: Text('Birikim Hesabı')),
                    DropdownMenuItem(
                        value: 'piggy', child: Text('Kumbara Hesabı')),
                  ],
                  onChanged: (value) => selectedType = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: targetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hedef Miktar (opsiyonel)',
                    prefixText: '₺',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Geçerli bir miktar girin';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setState) => OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Text(
                      'Hedef Tarih: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Get.back(
                  result: {
                    'name': nameController.text,
                    'type': selectedType,
                    'targetAmount': targetAmountController.text.isNotEmpty
                        ? double.parse(targetAmountController.text)
                        : 0,
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

    if (result != null && mounted) {
      try {
        await _accountService.createAccount(
          name: result['name'],
          type: result['type'],
          targetAmount: result['targetAmount'],
          description:
              'Hedef: ₺${result['targetAmount']} - ${result['targetDate'].day}/${result['targetDate'].month}/${result['targetDate'].year}',
        );
        _loadAccounts();
        Get.snackbar(
          'Başarılı',
          'Hesap başarıyla oluşturuldu',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Hesap oluşturma başarısız: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  IconData _getIconData(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return Icons.account_balance_wallet;
    }

    // Eğer string ise, wallet -> account_balance_wallet dönüşümü
    switch (iconString.toLowerCase()) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'savings':
        return Icons.savings;
      case 'piggy':
        return Icons.money_off;
      default:
        // Eğer hex değer ise
        try {
          return IconData(
            int.parse(iconString, radix: 16),
            fontFamily: 'MaterialIcons',
          );
        } catch (e) {
          return Icons.account_balance_wallet;
        }
    }
  }

  Color _getColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.blue;
    }

    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.replaceAll('#', '0xFF')));
      } else {
        return Color(int.parse(colorString));
      }
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kumbara'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Get.to(() => const ChildAccountsScreen()),
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
              : RefreshIndicator(
                  onRefresh: _loadAccounts,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Hesap Özeti Kartı
                      if (_accountSummary != null)
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hesap Özeti',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Toplam Bakiye'),
                                    Text(
                                      '₺${_accountSummary!['summary']['totalBalance'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Toplam Hesap'),
                                    Text(
                                      '${_accountSummary!['summary']['totalAccounts']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Son Güncelleme'),
                                    Text(
                                      DateTime.parse(_accountSummary!['summary']
                                              ['lastUpdate'])
                                          .toLocal()
                                          .toString()
                                          .split('.')[0],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Hesaplar Listesi
                      const Text(
                        'Hesaplarım',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_accountSummary != null &&
                          _accountSummary!['accounts'].isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _accountSummary!['accounts'].length,
                          itemBuilder: (context, index) {
                            final account = _accountSummary!['accounts'][index];
                            return Card(
                              elevation: 2,
                              child: ListTile(
                                leading: Icon(
                                  _getIconData(account['icon']),
                                  color: _getColor(account['color']),
                                ),
                                title: Text(account['accountName']),
                                subtitle: Text(account['accountType']),
                                trailing: Text(
                                  '₺${account['balance'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                onTap: () {
                                  if (account['accountType'] != 'main') {
                                    // accountSummary'den gelen account'u _accounts listesindeki karşılığıyla eşleştir
                                    final fullAccount = _accounts.firstWhere(
                                      (acc) =>
                                          acc['id'] == account['accountId'],
                                      orElse: () => account,
                                    );
                                    _showTransferDialog(fullAccount);
                                  }
                                },
                              ),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Text(
                            'Henüz hesap bulunmuyor',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: _accounts.isNotEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'new_account',
                  onPressed: _showCreateAccountDialog,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.account_balance_wallet, size: 20),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'withdraw',
                      onPressed: _showWithdrawDialog,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.remove, size: 20),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      heroTag: 'deposit',
                      onPressed: _showDepositDialog,
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            )
          : null,
    );
  }
}
