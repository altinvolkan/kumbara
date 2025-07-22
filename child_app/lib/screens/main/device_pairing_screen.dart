import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../../services/device_service.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final DeviceService _deviceService = DeviceService();
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isPairing = false;
  String? _pairingDeviceId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _deviceService.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      setState(() {
        _isScanning = true;
        _scanResults.clear();
      });

      final scanStream = await _deviceService.startScan();

      scanStream.listen((results) {
        setState(() {
          _scanResults = results
              .where((result) =>
                  _deviceService.isESP32Device(result) ||
                  result.device.platformName.isNotEmpty)
              .toList();
        });
      });

      // 10 saniye sonra taramayı durdur
      Future.delayed(const Duration(seconds: 10), () {
        _stopScan();
      });
    } catch (e) {
      print('Tarama hatası: $e');
      Get.snackbar(
        'Hata',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    await _deviceService.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _pairDevice(BluetoothDevice device) async {
    // Cihaz adı dialog'u
    String? deviceName = await _showDeviceNameDialog();
    if (deviceName == null || deviceName.trim().isEmpty) return;

    // WiFi bilgileri dialog'u
    Map<String, String>? wifiInfo = await _showWiFiConfigDialog();
    if (wifiInfo == null) return;

    try {
      setState(() {
        _isPairing = true;
        _pairingDeviceId = device.remoteId.str;
      });

      final result =
          await _deviceService.pairDevice(device, deviceName.trim(), wifiInfo);

      if (result['success']) {
        Get.snackbar(
          'Başarılı!',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Ana ekrana dön
        Get.back();
      }
    } catch (e) {
      print('Eşleştirme hatası: $e');
      Get.snackbar(
        'Eşleştirme Hatası',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isPairing = false;
        _pairingDeviceId = null;
      });
    }
  }

  Future<String?> _showDeviceNameDialog() async {
    String deviceName = '';

    return await Get.dialog<String>(
      AlertDialog(
        title: const Text('Cihaz Adı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu kumbara cihazına bir ad verin:'),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => deviceName = value,
              decoration: const InputDecoration(
                hintText: 'Örn: Odamdaki Kumbara',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: deviceName),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showWiFiConfigDialog() async {
    String ssid = '';
    String password = '';

    return await Get.dialog<Map<String, String>>(
      AlertDialog(
        title: const Text('WiFi Ayarları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ESP32\'nin bağlanacağı WiFi bilgilerini girin:'),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => ssid = value,
              decoration: const InputDecoration(
                labelText: 'WiFi Adı (SSID)',
                hintText: 'Örn: EVWiFi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => password = value,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'WiFi Şifresi',
                hintText: 'WiFi şifrenizi girin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ssid.trim().isEmpty) {
                Get.snackbar('Hata', 'WiFi adı gerekli!',
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              Get.back(result: {'ssid': ssid.trim(), 'password': password});
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    final isESP32 = _deviceService.isESP32Device(result);
    final isPairingThis = _isPairing && _pairingDeviceId == device.remoteId.str;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          isESP32 ? Icons.savings : Icons.bluetooth,
          color: isESP32 ? Colors.green : Colors.blue,
          size: 32,
        ),
        title: Text(
          device.platformName.isEmpty
              ? 'Bilinmeyen Cihaz'
              : device.platformName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC: ${device.remoteId.str}'),
            if (result.rssi != 0) Text('Sinyal: ${result.rssi} dBm'),
            if (isESP32)
              const Text(
                '🎯 Kumbara Cihazı Bulundu!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: isPairingThis
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              )
            : ElevatedButton(
                onPressed: _isPairing ? null : () => _pairDevice(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isESP32 ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(isESP32 ? 'Eşleştir' : 'Bağlan'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kumbara Cihazı Eşleştir'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isScanning ? _stopScan : _startScan,
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
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
        child: Column(
          children: [
            // Bilgi kartı
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.bluetooth_searching,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kumbara Cihazı Aranıyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning
                        ? 'ESP32-C3 kumbara cihazları taranıyor'
                        : 'Tarama durdu. Yenilemek için tazeleme butonuna basın',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Bulunan cihazlar listesi
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_disabled,
                            color: Colors.white.withOpacity(0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning
                                ? 'Cihazlar aranıyor...'
                                : 'Henüz cihaz bulunamadı',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          if (!_isScanning) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Kumbara cihazınızın açık olduğundan emin olun',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        return _buildDeviceCard(_scanResults[index]);
                      },
                    ),
            ),

            // Alt bilgi
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '💡 İpucu: Kumbara cihazınız listede "Kumbara Cihazı Bulundu!" yazısıyla gösterilecektir.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
