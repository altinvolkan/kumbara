import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/goal_service.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GoalService _goalService = GoalService();

  String _selectedCategory = 'toy';
  String _selectedIcon = '🎯';
  String _selectedColor = '#E91E63';
  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _categories = {
    'toy': {'name': 'Oyuncak', 'icon': '🧸', 'color': '#E91E63'},
    'book': {'name': 'Kitap', 'icon': '📚', 'color': '#2196F3'},
    'electronics': {'name': 'Elektronik', 'icon': '📱', 'color': '#9C27B0'},
    'sports': {'name': 'Spor', 'icon': '⚽', 'color': '#4CAF50'},
    'clothes': {'name': 'Kiyafet', 'icon': '👕', 'color': '#FF9800'},
    'games': {'name': 'Oyun', 'icon': '🎮', 'color': '#3F51B5'},
    'art': {'name': 'Sanat', 'icon': '🎨', 'color': '#795548'},
    'music': {'name': 'Müzik', 'icon': '🎵', 'color': '#607D8B'},
    'food': {'name': 'Yemek', 'icon': '🍕', 'color': '#FF5722'},
    'other': {'name': 'Diğer', 'icon': '⭐', 'color': '#757575'},
  };

  @override
  void initState() {
    super.initState();
    _updateIconAndColor();
  }

  void _updateIconAndColor() {
    setState(() {
      _selectedIcon = _categories[_selectedCategory]!['icon'];
      _selectedColor = _categories[_selectedCategory]!['color'];
    });
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _goalService.createGoal(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        targetAmount: double.parse(_amountController.text),
        icon: _selectedIcon,
        color: _selectedColor,
        category: _selectedCategory,
        isVisible: true,
        isParallel: false,
      );

      Get.back(result: true); // Ana ekrana dön ve yenileme sinyali gönder
      Get.snackbar(
        'Başarılı! 🎉',
        'Hedefin oluşturuldu!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Hata 😞',
        'Hedef oluşturulamadı: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF9333EA),
              Color(0xFFEC4899),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Yeni Hedef Oluştur',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Comic Neue',
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hedef Adı
                            const Text(
                              'Hedefin Adı',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comic Neue',
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'Örnek: Nintendo Switch',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: Text(
                                  _selectedIcon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 50,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Hedef adı gerekli';
                                }
                                if (value.trim().length < 2) {
                                  return 'En az 2 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Hedef Tutar
                            const Text(
                              'Kaç Lira Biriktirmek İstiyorsun?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comic Neue',
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: '500',
                                suffixText: '₺',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(
                                  Icons.attach_money_rounded,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Hedef tutar gerekli';
                                }
                                final amount = int.tryParse(value);
                                if (amount == null || amount <= 0) {
                                  return 'Geçerli bir tutar girin';
                                }
                                if (amount < 10) {
                                  return 'En az 10₺ olmalı';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Kategori Seçimi
                            const Text(
                              'Hangi Kategoride?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comic Neue',
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.entries.map((entry) {
                                final isSelected =
                                    entry.key == _selectedCategory;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = entry.key;
                                      _updateIconAndColor();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(int.parse(entry.value['color']
                                              .replaceFirst('#', '0xFF')))
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(int.parse(entry
                                                .value['color']
                                                .replaceFirst('#', '0xFF')))
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.value['icon'],
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          entry.value['name'],
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontFamily: 'Comic Neue',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // Açıklama (İsteğe Bağlı)
                            const Text(
                              'Açıklama (İsteğe Bağlı)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comic Neue',
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Bu hedef neden önemli?',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Kaydet Butonu
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveGoal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B46C1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Hedefi Oluştur 🎯',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Comic Neue',
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
