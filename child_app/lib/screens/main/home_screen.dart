import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user.dart';
import '../../models/goal.dart';
import '../../services/auth_service.dart';
import '../../services/goal_service.dart';
import '../../services/account_service.dart';
import '../../services/device_service.dart';
import '../auth/login_screen.dart';
import 'create_goal_screen.dart';
import 'device_pairing_screen.dart';
import 'device_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final GoalService _goalService = GoalService();
  final AccountService _accountService = AccountService();
  final DeviceService _deviceService = DeviceService();

  User? _currentUser;
  List<Goal> _goals = [];
  List<Goal> _completedGoals = [];
  Map<String, dynamic>? _linkedAccount;
  bool _isLoading = true;

  Timer? _refreshTimer;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    print('HomeScreen: _loadData() başladı');
    try {
      final user = await _authService.getCurrentUser();
      print('HomeScreen: User yüklendi: ${user?.name} (${user?.role})');

      if (user == null) {
        print('HomeScreen: User null, login ekranına yönlendiriliyor');
        Get.offAll(() => const LoginScreen());
        return;
      }

      print('HomeScreen: getVisibleGoals() çağrılıyor...');
      final goals = await _goalService.getVisibleGoals();
      print('HomeScreen: ${goals.length} hedef yüklendi');

      print('HomeScreen: getCompletedGoals() çağrılıyor...');
      final completedGoals = await _goalService.getCompletedGoals();
      print('HomeScreen: ${completedGoals.length} tamamlanan hedef yüklendi');

      print('HomeScreen: getLinkedAccount() çağrılıyor...');
      Map<String, dynamic>? account;
      try {
        account = await _accountService.getLinkedAccount();
        print('HomeScreen: Hesap bilgisi: $account');
      } catch (e) {
        print('HomeScreen: Account service error: $e');
        account = null;
      }

      setState(() {
        _currentUser = user;
        _goals = goals;
        _completedGoals = completedGoals;
        _linkedAccount = account;
        _isLoading = false;
      });
      print('HomeScreen: setState tamamlandı');
    } catch (e) {
      print('HomeScreen: Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    Get.offAll(() => const LoginScreen());
  }

  void _createNewGoal() async {
    final result = await Get.to(() => const CreateGoalScreen());
    // Hedef oluşturulduysa listeyi yenile
    if (result == true) {
      _loadData();
    }
  }

  // ESP32'ye hedef bilgilerini gönder
  Future<void> _syncGoalsToESP32() async {
    try {
      // Loading göster
      Get.dialog(
        const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('ESP32\'ye gönderiliyor...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Hedef verilerini hazırla
      List<Map<String, dynamic>> goalData = [];

      // Aktif hedefler
      for (var goal in _goals) {
        goalData.add({
          'id': goal.id,
          'title': goal.title,
          'currentAmount': goal.currentAmount,
          'targetAmount': goal.targetAmount,
          'progress': goal.progress,
          'isCompleted': false,
        });
      }

      // Tamamlanan hedefler (son 3 tane)
      var recentCompleted = _completedGoals.take(3).toList();
      for (var goal in recentCompleted) {
        goalData.add({
          'id': goal.id,
          'title': goal.title,
          'currentAmount': goal.currentAmount,
          'targetAmount': goal.targetAmount,
          'progress': 1.0,
          'isCompleted': true,
        });
      }

      // ESP32'ye gönder
      bool success = await _deviceService.sendGoalsToDevice('', goalData);

      // Dialog'u kapat
      Get.back();

      if (success) {
        Get.snackbar(
          'Başarılı! 🎉',
          'Hedef bilgileri ESP32\'ye gönderildi',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Hata ❌',
          'ESP32\'ye gönderim başarısız',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Dialog'u kapat
      Get.back();

      Get.snackbar(
        'Hata ❌',
        'ESP32 bağlantı hatası: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1), // Purple 600
              Color(0xFF9333EA), // Purple 500
              Color(0xFFEC4899), // Pink 500
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          child: Text(
                            _currentUser?.name.substring(0, 1).toUpperCase() ??
                                'C',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B46C1),
                              fontFamily: 'Comic Neue',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba, ${_currentUser?.name ?? 'Çocuk'}! 👋',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Comic Neue',
                                ),
                              ),
                              Text(
                                'Level ${_currentUser?.level ?? 1} • ${_currentUser?.xp ?? 0} XP',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontFamily: 'Comic Neue',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _syncGoalsToESP32,
                          icon: const Icon(
                            Icons.sync,
                            color: Colors.white,
                          ),
                          tooltip: 'ESP32\'ye Hedefleri Gönder',
                        ),
                        IconButton(
                          onPressed: () =>
                              Get.to(() => const DeviceManagementScreen()),
                          icon: const Icon(
                            Icons.bluetooth,
                            color: Colors.white,
                          ),
                          tooltip: 'Kumbara Cihazlarım',
                        ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bakiye Kartı
                  if (_linkedAccount != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _linkedAccount!['name'] ?? 'Kumbaranın',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontFamily: 'Comic Neue',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _accountService.formatBalance(
                                  (_linkedAccount!['balance'] ?? 0).toDouble()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comic Neue',
                              ),
                            ),
                            const Text(
                              'Mevcut Bakiye',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontFamily: 'Comic Neue',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Content Container
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _goals.isEmpty
                          ? _buildEmptyState()
                          : _buildGoalsList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewGoal,
        backgroundColor: const Color(0xFF6B46C1),
        icon: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
        label: const Text(
          'Yeni Hedef',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Comic Neue',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              size: 60,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Henüz hedefin yok!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Comic Neue',
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ebeveynlerinden ilk hedefini\noluşturmalarını iste 😊',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Comic Neue',
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '🎯 Hedeflerim',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Comic Neue',
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showHelpDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // TabBar
        if (_tabController != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController!,
              indicator: BoxDecoration(
                color: const Color(0xFF6B46C1),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontFamily: 'Comic Neue',
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text('Aktif (${_goals.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text('Tamamlanan (${_completedGoals.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // TabBarView
        if (_tabController != null)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              controller: _tabController!,
              children: [
                // Aktif Hedefler
                _goals.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _goals.length,
                        itemBuilder: (context, index) {
                          final goal = _goals[index];
                          return _buildGoalCard(goal, isCompleted: false);
                        },
                      ),

                // Tamamlanan Hedefler
                _completedGoals.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _completedGoals.length,
                        itemBuilder: (context, index) {
                          final goal = _completedGoals[index];
                          return _buildGoalCard(goal, isCompleted: true);
                        },
                      ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGoalCard(Goal goal, {bool isCompleted = false}) {
    final progress = goal.progress;
    final progressColor = progress >= 1.0
        ? Colors.green
        : progress >= 0.7
            ? Colors.orange
            : const Color(0xFF6B46C1);

    return GestureDetector(
      onLongPress: () => _showGoalOptionsDialog(goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        goal.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        _getCategoryIcon(goal.category),
                        color: progressColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Comic Neue',
                          color: Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${goal.currentAmount.toInt()}₺ / ${goal.targetAmount.toInt()}₺',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Comic Neue',
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'TAMAMLANDI!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Comic Neue',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ] else ...[
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Comic Neue',
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showTransferMoneyDialog(goal),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.green,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showDeleteGoalDialog(goal),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
              ),
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                goal.description,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Comic Neue',
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'toy':
        return Icons.toys_rounded;
      case 'electronics':
        return Icons.phone_android_rounded;
      case 'clothes':
        return Icons.checkroom_rounded;
      case 'sport':
        return Icons.sports_soccer_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'travel':
        return Icons.flight_rounded;
      case 'games':
      case 'game':
        return Icons.sports_esports_rounded;
      case 'book':
      case 'books':
      case 'kitap':
        return Icons.menu_book_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  // Yardım dialog'u
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Nasıl Kullanılır?',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silme butonu: Hedefi tamamen sil',
                      style: TextStyle(fontFamily: 'Comic Neue'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Basılı tut: Seçenekler menüsü aç',
                      style: TextStyle(fontFamily: 'Comic Neue'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '🎯 Öncelik Sistemi',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• 1 = En yüksek öncelik (ilk önce dolar)\n• 2 = Orta öncelik\n• 3, 4, 5 = Düşük öncelik\n\nAynı önceliktekilere eşit pay!',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '💰 Para Dağıtımı',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Yeni para geldiğinde:\n• Önce yüksek öncelikli hedefler dolar\n• Hedef silindiğinde parası diğerlerine dağıtılır',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Anladım! 👍',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Hedef seçenekleri dialog'u (basılı tutma)
  void _showGoalOptionsDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                _getCategoryIcon(goal.category),
                color: const Color(0xFF6B46C1),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(
                    fontFamily: 'Comic Neue',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.priority_high_rounded,
                  color: Color(0xFF6B46C1),
                ),
                title: const Text(
                  'Öncelik Değiştir',
                  style: TextStyle(fontFamily: 'Comic Neue'),
                ),
                subtitle: Text(
                  'Mevcut öncelik: ${goal.priority}',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPriorityDialog(goal);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Hedefi Sil',
                  style: TextStyle(fontFamily: 'Comic Neue'),
                ),
                subtitle: goal.currentAmount > 0
                    ? Text(
                        '${goal.currentAmount.toInt()}₺ diğer hedeflere dağıtılacak',
                        style: const TextStyle(fontFamily: 'Comic Neue'),
                      )
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteGoalDialog(goal);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Öncelik değiştirme dialog'u
  void _showPriorityDialog(Goal goal) {
    int newPriority = goal.priority;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Öncelik Seç',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Düşük sayı = Yüksek öncelik\n1 = En yüksek öncelik',
                    style: TextStyle(
                      fontFamily: 'Comic Neue',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1, 2, 3, 4, 5].map((priority) {
                      final isSelected = newPriority == priority;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            newPriority = priority;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6B46C1)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6B46C1)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              priority.toString(),
                              style: TextStyle(
                                fontFamily: 'Comic Neue',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'İptal',
                    style: TextStyle(
                      fontFamily: 'Comic Neue',
                      color: Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: newPriority != goal.priority
                      ? () {
                          Navigator.of(context).pop();
                          _updateGoalPriority(goal, newPriority);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Güncelle',
                    style: TextStyle(
                      fontFamily: 'Comic Neue',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Hedef önceliğini güncelle
  Future<void> _updateGoalPriority(Goal goal, int newPriority) async {
    try {
      // Loading göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Öncelik güncelleniyor...',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Hedefi güncelle
      await _goalService.updateGoal(goal.id, priority: newPriority);

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  '${goal.name} önceliği $newPriority olarak güncellendi!',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Listeyi yenile
      await _loadData();
    } catch (e) {
      debugPrint('Öncelik güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  'Öncelik güncellenemedi: $e',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Hedef silme onay dialog'u
  void _showDeleteGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Hedefi Sil',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${goal.name}" hedefini silmek istediğine emin misin?',
                style: const TextStyle(
                  fontFamily: 'Comic Neue',
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (goal.currentAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu hedefdeki ${goal.currentAmount.toInt()}₺ diğer hedeflerine öncelik sırasına göre dağıtılacak.',
                        style: const TextStyle(
                          fontFamily: 'Comic Neue',
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteGoal(goal);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sil',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Hedefi sil
  Future<void> _deleteGoal(Goal goal) async {
    try {
      // Loading göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${goal.name} siliniyor...',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Hedefi sil
      await _goalService.deleteGoal(goal.id);

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${goal.name} silindi${goal.currentAmount > 0 ? ' ve ${goal.currentAmount.toInt()}₺ diğer hedeflere dağıtıldı' : ''}!',
                    style: const TextStyle(fontFamily: 'Comic Neue'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Listeyi yenile
      await _loadData();
    } catch (e) {
      debugPrint('Hedef silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hedef silinemedi: $e',
                    style: const TextStyle(fontFamily: 'Comic Neue'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Para aktarım dialog'u
  void _showTransferMoneyDialog(Goal goal) {
    final TextEditingController amountController = TextEditingController();
    final remainingAmount = goal.targetAmount - goal.currentAmount;
    final accountBalance = _linkedAccount?['balance'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Para Aktar',
                  style: TextStyle(
                    fontFamily: 'Comic Neue',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${goal.name}" hedefine para aktar',
                style: const TextStyle(
                  fontFamily: 'Comic Neue',
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              // Bilgi kartları
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bakiye',
                            style: TextStyle(
                              fontFamily: 'Comic Neue',
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '${accountBalance.toInt()}₺',
                            style: const TextStyle(
                              fontFamily: 'Comic Neue',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.track_changes_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Kalan',
                            style: TextStyle(
                              fontFamily: 'Comic Neue',
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '${remainingAmount.toInt()}₺',
                            style: const TextStyle(
                              fontFamily: 'Comic Neue',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Miktar input
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Aktarılacak Miktar (₺)',
                  labelStyle: const TextStyle(fontFamily: 'Comic Neue'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                ),
                style: const TextStyle(fontFamily: 'Comic Neue'),
              ),
              const SizedBox(height: 12),

              // Hızlı miktar butonları
              Row(
                children: [
                  _buildQuickAmountButton(amountController, '10', goal),
                  const SizedBox(width: 8),
                  _buildQuickAmountButton(amountController, '50', goal),
                  const SizedBox(width: 8),
                  _buildQuickAmountButton(amountController, '100', goal),
                  const SizedBox(width: 8),
                  _buildQuickAmountButton(amountController, 'Max', goal),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.of(context).pop();
                  _transferMoneyToGoal(goal, amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Geçerli bir miktar girin',
                        style: TextStyle(fontFamily: 'Comic Neue'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Aktar',
                style: TextStyle(
                  fontFamily: 'Comic Neue',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAmountButton(
      TextEditingController controller, String label, Goal goal) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == 'Max') {
            final remainingAmount = goal.targetAmount - goal.currentAmount;
            final accountBalance =
                _linkedAccount?['balance']?.toDouble() ?? 0.0;
            final maxAmount = remainingAmount < accountBalance
                ? remainingAmount
                : accountBalance;
            controller.text = maxAmount.toInt().toString();
          } else {
            controller.text = label;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            label == 'Max' ? 'Max' : '${label}₺',
            style: const TextStyle(
              fontFamily: 'Comic Neue',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Para aktarım fonksiyonu
  Future<void> _transferMoneyToGoal(Goal goal, double amount) async {
    try {
      // Loading göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${amount.toInt()}₺ aktarılıyor...',
                  style: const TextStyle(fontFamily: 'Comic Neue'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Para aktarımı yap
      final result = await _accountService.transferToGoal(goal.id, amount);

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ??
                        '${amount.toInt()}₺ başarıyla aktarıldı!',
                    style: const TextStyle(fontFamily: 'Comic Neue'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Veriyi yenile
      await _loadData();
    } catch (e) {
      debugPrint('Para aktarım hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Para aktarılamadı: $e',
                    style: const TextStyle(fontFamily: 'Comic Neue'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
