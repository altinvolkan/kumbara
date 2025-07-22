import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/child_service.dart';
import '../../services/account_service.dart';

class ChildrenManagementScreen extends StatefulWidget {
  const ChildrenManagementScreen({super.key});

  @override
  State<ChildrenManagementScreen> createState() =>
      _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  final ChildService _childService = ChildService();
  final AccountService _accountService = AccountService();

  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final children = await _childService.getChildren();
      final accounts = await _accountService.getAccounts();

      setState(() {
        _children = children;
        _accounts = accounts
            .where((account) =>
                account['type'] == 'savings' || account['type'] == 'piggy')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Veri yükleme hatası: $e');
      setState(() => _isLoading = false);
      Get.snackbar(
        'Hata',
        'Veriler yüklenirken bir hata oluştu: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showCreateChildDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedAccountId;

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Yeni Çocuk Hesabı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Çocuk Adı',
                  hintText: 'Ahmet',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'ahmet@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  hintText: 'En az 6 karakter',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Bağlanacak Hesap',
                ),
                value: selectedAccountId,
                items: _accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account['id'],
                    child: Text('${account['name']} (${account['balance']}₺)'),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedAccountId = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  selectedAccountId == null) {
                Get.snackbar(
                  'Hata',
                  'Tüm alanları doldurunuz',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              try {
                await _childService.createChild(
                  name: nameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  linkedAccountId: selectedAccountId!,
                );
                Get.back(result: true);
              } catch (e) {
                Get.snackbar(
                  'Hata',
                  'Çocuk hesabı oluşturulamadı: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadData();
      Get.snackbar(
        'Başarılı! 🎉',
        'Çocuk hesabı oluşturuldu',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showEditChildDialog(Map<String, dynamic> child) async {
    final nameController = TextEditingController(text: child['name']);
    final emailController = TextEditingController(text: child['email']);
    String? selectedAccountId = child['linkedAccount']?['_id'];

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('${child['name']} - Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Çocuk Adı',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Bağlı Hesap',
                ),
                value: selectedAccountId,
                items: _accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account['id'],
                    child: Text('${account['name']} (${account['balance']}₺)'),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedAccountId = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _childService.updateChild(
                  childId: child['_id'],
                  name: nameController.text,
                  email: emailController.text,
                  linkedAccountId: selectedAccountId,
                );
                Get.back(result: true);
              } catch (e) {
                Get.snackbar(
                  'Hata',
                  'Çocuk hesabı güncellenemedi: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadData();
      Get.snackbar(
        'Başarılı! 🎉',
        'Çocuk hesabı güncellendi',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Çocuk Hesabını Sil'),
        content: Text(
            '${child['name']} adlı çocuk hesabını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _childService.deleteChild(child['_id']);
        _loadData();
        Get.snackbar(
          'Başarılı',
          'Çocuk hesabı silindi',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Hata',
          'Çocuk hesabı silinemedi: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final linkedAccount = child['linkedAccount'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            child['name'][0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          child['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${child['email']}'),
            if (linkedAccount != null)
              Text(
                  'Hesap: ${linkedAccount['name']} (${linkedAccount['balance']}₺)')
            else
              const Text('Hesap: Bağlı değil',
                  style: TextStyle(color: Colors.red)),
            Text(
                'Oluşturma: ${DateTime.parse(child['createdAt']).day}/${DateTime.parse(child['createdAt']).month}/${DateTime.parse(child['createdAt']).year}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Düzenle'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sil'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditChildDialog(child);
            } else if (value == 'delete') {
              _deleteChild(child);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çocuk Hesapları'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Üst bilgi
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.family_restroom,
                          color: Colors.blue, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Çocuk Hesapları',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_children.length} çocuk hesabı',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Çocuk listesi
                Expanded(
                  child: _children.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.family_restroom,
                                color: Colors.grey.shade400,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz çocuk hesabı yok',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Yeni çocuk hesabı oluşturmak için + butonuna tıklayın',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _children.length,
                          itemBuilder: (context, index) {
                            return _buildChildCard(_children[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateChildDialog,
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
