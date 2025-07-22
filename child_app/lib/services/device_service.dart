import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DeviceService {
  static const String baseUrl = 'http://192.168.1.21:3000/api';

  // BLE Servis ve Karakteristik UUID'leri
  static const String serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String configCharacteristicUuid =
      "12345678-1234-1234-1234-123456789abd";
  static const String statusCharacteristicUuid =
      "12345678-1234-1234-1234-123456789abe";

  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  // İzin kontrolü
  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  // BLE tarama başlat
  Future<Stream<List<ScanResult>>> startScan() async {
    print('DeviceService: BLE tarama başlatılıyor...');

    // İzinleri kontrol et
    if (!await _checkPermissions()) {
      throw Exception('BLE izinleri gerekli');
    }

    // Bluetooth açık mı kontrol et
    if (!(await FlutterBluePlus.isAvailable)) {
      throw Exception('Bluetooth mevcut değil');
    }

    if (!(await FlutterBluePlus.isOn)) {
      throw Exception('Bluetooth kapalı');
    }

    _scanResults.clear();
    _isScanning = true;

    // ESP32-C3 cihazları için tarama yap
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [], // Tüm cihazları tara
    );

    return FlutterBluePlus.scanResults;
  }

  // Taramayı durdur
  Future<void> stopScan() async {
    print('DeviceService: BLE tarama durduruluyor...');
    await FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  // ESP32 cihazına bağlan ve yapılandır
  Future<Map<String, dynamic>> pairDevice(BluetoothDevice device,
      String deviceName, Map<String, String> wifiInfo) async {
    try {
      print('DeviceService: ${device.platformName} cihazına bağlanılıyor...');

      // Cihaza bağlan
      await device.connect(timeout: const Duration(seconds: 15));
      print('DeviceService: Bağlantı başarılı');

      // Servisleri keşfet
      List<BluetoothService> services = await device.discoverServices();
      print('DeviceService: ${services.length} servis bulundu');

      // Kumbara servisini bul
      BluetoothService? kumbaraService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            serviceUuid.toLowerCase()) {
          kumbaraService = service;
          break;
        }
      }

      if (kumbaraService == null) {
        throw Exception('Kumbara servisi bulunamadı');
      }

      // Config karakteristiği bul
      BluetoothCharacteristic? configChar;
      for (var char in kumbaraService.characteristics) {
        if (char.uuid.toString().toLowerCase() ==
            configCharacteristicUuid.toLowerCase()) {
          configChar = char;
          break;
        }
      }

      if (configChar == null) {
        throw Exception('Config karakteristiği bulunamadı');
      }

      // Kullanıcı bilgilerini al
      final user = await AuthService().getCurrentUser();
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // WiFi ve kullanıcı bilgilerini ESP32'ye gönder
      final configData = {
        'action': 'configure',
        'ssid': wifiInfo['ssid']!,
        'password': wifiInfo['password']!,
        'server': 'http://192.168.1.21:3000',
        'userId': user.id,
        'deviceName': deviceName,
        'secret': 'esp32-secret-key-2025'
      };

      print('DeviceService: Konfigürasyon gönderiliyor...');
      await configChar.write(utf8.encode(json.encode(configData)));

      // Backend'e cihazı kaydet
      final deviceId =
          '${device.remoteId.str}-${DateTime.now().millisecondsSinceEpoch}';
      await _registerDeviceToBackend(deviceId, deviceName, user.id);

      // Bağlantıyı kes
      await device.disconnect();

      return {
        'success': true,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'message': 'Cihaz başarıyla eşleştirildi'
      };
    } catch (e) {
      print('DeviceService: Eşleştirme hatası - $e');
      try {
        await device.disconnect();
      } catch (_) {}
      rethrow;
    }
  }

  // Backend'e cihaz kaydetme
  Future<void> _registerDeviceToBackend(
      String deviceId, String deviceName, String userId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final response = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'deviceId': deviceId,
          'name': deviceName,
          'type': 'ESP32-C3',
          'userId': userId,
        }),
      );

      if (response.statusCode != 201) {
        print('DeviceService: Backend kayıt hatası - ${response.body}');
        throw Exception('Cihaz backend\'e kaydedilemedi');
      }

      print('DeviceService: Cihaz backend\'e başarıyla kaydedildi');
    } catch (e) {
      print('DeviceService: Backend kayıt hatası - $e');
      throw Exception('Backend kayıt hatası: $e');
    }
  }

  // Kullanıcının cihazlarını getir
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final response = await http.get(
        Uri.parse('$baseUrl/devices'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Cihazlar getirilemedi');
      }
    } catch (e) {
      print('DeviceService: Cihazları getirme hatası - $e');
      return [];
    }
  }

  // Cihaz silme
  Future<bool> deleteDevice(String deviceId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final response = await http.delete(
        Uri.parse('$baseUrl/devices/$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('DeviceService: Cihaz silme hatası - $e');
      return false;
    }
  }

  // ESP32 cihaz mı kontrol et
  bool isESP32Device(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    return name.contains('esp32') ||
        name.contains('kumbara') ||
        name.contains('esp-c3') ||
        result.advertisementData.localName.toLowerCase().contains('esp32');
  }

  // Tarama durumu
  bool get isScanning => _isScanning;

  // Bulunan cihazlar
  List<ScanResult> get scanResults => _scanResults;

  // ESP32'ye hedef bilgilerini gönder
  Future<bool> sendGoalsToDevice(
      String deviceId, List<Map<String, dynamic>> goals) async {
    try {
      print('DeviceService: Hedef bilgileri ESP32\'ye gönderiliyor...');

      // ESP32 cihazını bul ve bağlan
      // Önce tarama yap
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 3));

      final scanResults = await FlutterBluePlus.scanResults.first;
      BluetoothDevice? targetDevice;

      for (var result in scanResults) {
        if (isESP32Device(result)) {
          targetDevice = result.device;
          break;
        }
      }

      await FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        throw Exception('ESP32 cihazı bulunamadı');
      }

      // Cihaza bağlan
      await targetDevice.connect(timeout: const Duration(seconds: 10));

      // Servisleri keşfet
      List<BluetoothService> services = await targetDevice.discoverServices();

      // Kumbara servisini bul (güncellenmiş UUID ile)
      BluetoothService? kumbaraService;
      for (var service in services) {
        String serviceUuidStr = service.uuid.toString().toLowerCase();
        if (serviceUuidStr.contains('12345678-1234-1234-1234-123456789abc')) {
          kumbaraService = service;
          break;
        }
      }

      if (kumbaraService == null) {
        throw Exception('Kumbara servisi bulunamadı');
      }

      // Config karakteristiği bul
      BluetoothCharacteristic? configChar;
      for (var char in kumbaraService.characteristics) {
        String charUuidStr = char.uuid.toString().toLowerCase();
        if (charUuidStr.contains('12345678-1234-1234-1234-123456789abd')) {
          configChar = char;
          break;
        }
      }

      if (configChar == null) {
        throw Exception('Config karakteristiği bulunamadı');
      }

      // Hedef verilerini hazırla
      final goalsData = {
        'action': 'update_goals',
        'goals': goals,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print(
          'DeviceService: Hedef verileri gönderiliyor: ${goals.length} hedef');
      await configChar.write(utf8.encode(json.encode(goalsData)));

      // Bağlantıyı kes
      await targetDevice.disconnect();

      print('DeviceService: Hedef bilgileri başarıyla gönderildi');
      return true;
    } catch (e) {
      print('DeviceService: Hedef gönderme hatası - $e');
      return false;
    }
  }
}
