import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/device_service.dart';
import 'device_pairing_screen.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final DeviceService _deviceService = DeviceService();
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _deviceService.getUserDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      print('Cihazları yükleme hatası: $e');
      setState(() => _isLoading = false);
      Get.snackbar(
        'Hata',
        'Cihazlar yüklenirken bir hata oluştu',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteDevice(String deviceId, String deviceName) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Cihaz Sil'),
        content: Text('$deviceName cihazını silmek istediğinize emin misiniz?'),
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
      final success = await _deviceService.deleteDevice(deviceId);
      if (success) {
        Get.snackbar(
          'Başarılı',
          'Cihaz başarıyla silindi',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadDevices(); // Listeyi yenile
      } else {
        Get.snackbar(
          'Hata',
          'Cihaz silinirken bir hata oluştu',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(
          Icons.savings,
          color: Colors.green,
          size: 32,
        ),
        title: Text(
          device['name'] ?? 'Bilinmeyen Cihaz',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tip: ${device['type'] ?? 'ESP32'}'),
            Text('ID: ${device['deviceId'] ?? 'N/A'}'),
            if (device['createdAt'] != null)
              Text(
                  'Eklenme: ${DateTime.parse(device['createdAt']).day}/${DateTime.parse(device['createdAt']).month}/${DateTime.parse(device['createdAt']).year}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sil'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'delete') {
              _deleteDevice(device['deviceId'], device['name'] ?? 'Cihaz');
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
        title: const Text('Kumbara Cihazlarım'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bluetooth_disabled,
                          color: Colors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz eşleştirilmiş cihaz yok',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kumbara cihazınızı eşleştirmek için aşağıdaki butona basın',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () =>
                              Get.to(() => const DevicePairingScreen()),
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Cihaz Eşleştir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6B46C1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Üst bilgi
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.savings,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Eşleştirilmiş Cihazlar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_devices.length} cihaz bağlı',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Get.to(() => const DevicePairingScreen()),
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                              ),
                              tooltip: 'Yeni Cihaz Ekle',
                            ),
                          ],
                        ),
                      ),

                      // Cihaz listesi
                      Expanded(
                        child: ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            return _buildDeviceCard(_devices[index]);
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
