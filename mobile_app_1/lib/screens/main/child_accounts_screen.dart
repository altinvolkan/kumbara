import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/account_service.dart';

class ChildAccountsScreen extends StatefulWidget {
  const ChildAccountsScreen({super.key});

  @override
  State<ChildAccountsScreen> createState() => _ChildAccountsScreenState();
}

class _ChildAccountsScreenState extends State<ChildAccountsScreen> {
  final _authService = AuthService();
  final _accountService = AccountService();
  List<Map<String, dynamic>> _childAccounts = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildAccounts();
  }

  Future<void> _loadChildAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accounts = await _authService.getChildAccounts();
      final userAccounts = await _accountService.getAccounts();
      if (mounted) {
        setState(() {
          _childAccounts = accounts;
          _accounts = userAccounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateChildDialog() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null || currentUser.id == null) {
        Get.snackbar(
          'Hata',
          'Oturum bilgisi bulunamadı',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (_accounts.isEmpty) {
        Get.snackbar(
          'Hata',
          'Önce bir hesap oluşturmalısınız',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final nameController = TextEditingController();
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      Map<String, dynamic>? selectedAccount;

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Çocuk Hesabı Oluştur'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen ad soyad girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta girin';
                      }
                      if (!GetUtils.isEmail(value)) {
                        return 'Geçerli bir e-posta girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Şifre',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifre girin';
                      }
                      if (value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(
                      labelText: 'Bağlanacak Hesap',
                      border: OutlineInputBorder(),
                    ),
                    items: _accounts.map((account) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: account,
                        child:
                            Text('${account['name']} - ₺${account['balance']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedAccount = value;
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Lütfen bir hesap seçin';
                      }
                      return null;
                    },
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
                if (formKey.currentState!.validate() &&
                    selectedAccount != null) {
                  Get.back(
                    result: {
                      'name': nameController.text,
                      'email': emailController.text,
                      'password': passwordController.text,
                      'linkedAccountId': selectedAccount!['id'],
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
        await _authService.createChildAccount(
          name: result['name'],
          email: result['email'],
          password: result['password'],
          linkedAccountId: result['linkedAccountId'],
        );
        _loadChildAccounts();
        Get.snackbar(
          'Başarılı',
          'Çocuk hesabı oluşturuldu',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Çocuk hesabı oluşturulamadı: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showUpdateChildDialog(Map<String, dynamic> childAccount) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null || currentUser.id == null) {
        Get.snackbar(
          'Hata',
          'Oturum bilgisi bulunamadı',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final nameController = TextEditingController(text: childAccount['name']);
      final emailController =
          TextEditingController(text: childAccount['email']);
      final formKey = GlobalKey<FormState>();

      // Bağlı hesabı _accounts listesinden bul
      Map<String, dynamic>? selectedAccount;
      if (childAccount['linkedAccount'] != null) {
        final linkedAccountId = childAccount['linkedAccount']['_id'].toString();
        selectedAccount = _accounts.firstWhere(
          (account) => account['id'].toString() == linkedAccountId,
          orElse: () => childAccount['linkedAccount'],
        );
      }

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Çocuk Hesabını Güncelle'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen ad soyad girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen e-posta girin';
                        }
                        if (!GetUtils.isEmail(value)) {
                          return 'Geçerli bir e-posta girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Bağlanacak Hesap',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedAccount,
                      items: _accounts.map((account) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: account,
                          child: Text(
                              '${account['name']} - ₺${account['balance']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedAccount = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Lütfen bir hesap seçin';
                        }
                        return null;
                      },
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
                  if (formKey.currentState!.validate() &&
                      selectedAccount != null) {
                    Get.back(
                      result: {
                        'name': nameController.text,
                        'email': emailController.text,
                        'linkedAccountId': selectedAccount!['id'],
                      },
                    );
                  }
                },
                child: const Text('Güncelle'),
              ),
            ],
          ),
        ),
      );

      if (result != null) {
        await _authService.updateChildAccount(
          childId: childAccount['_id'].toString(),
          name: result['name'],
          email: result['email'],
          linkedAccountId: result['linkedAccountId'],
        );
        _loadChildAccounts();
        Get.snackbar(
          'Başarılı',
          'Çocuk hesabı güncellendi',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Çocuk hesabı güncellenemedi: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showDeleteChildDialog(Map<String, dynamic> childAccount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çocuk Hesabını Sil'),
        content: Text(
          '${childAccount['name']} hesabını silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _authService.deleteChildAccount(childAccount['_id'].toString());
        _loadChildAccounts();
        Get.snackbar(
          'Başarılı',
          'Çocuk hesabı silindi',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Çocuk hesabı silinemedi: ${e.toString()}',
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
        title: const Text('Çocuk Hesapları'),
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
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChildAccounts,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChildAccounts,
                  child: _childAccounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Henüz çocuk hesabı bulunmuyor'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showCreateChildDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Yeni Hesap Oluştur'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _childAccounts.length,
                          itemBuilder: (context, index) {
                            final account = _childAccounts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(account['name']),
                                subtitle: Text(account['email']),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Düzenle'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Sil'),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showUpdateChildDialog(account);
                                        break;
                                      case 'delete':
                                        _showDeleteChildDialog(account);
                                        break;
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateChildDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
