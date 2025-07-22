/*
 * ÇALIŞAN KOD YEDEGİ - 26.01.2025
 * Kumbara ESP32-C3 - Ultra Minimal (TFT-Free Test)
 * 
 * ✅ %100 ÇALIŞIYOR - ESP32 BLE SYNC BAŞARILI!
 * 
 * Test Sonuçları:
 * - BLE bağlantısı: ✅ BAŞARILI
 * - Child App sync: ✅ BAŞARILI  
 * - Hedef döngüsü: ✅ ÇALIŞIYOR
 * - ASCII Progress: ✅ MÜKEMMEEl
 * 
 * Sadece: BLE + Serial Monitor
 * Board: ESP32C3 Dev Module
 * Partition: Huge APP (3MB No OTA/1MB SPIFFS)
 */

#include "ArduinoJson.h"
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"

// BLE
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// Hedefler
struct Goal {
  String title;
  int current;
  int target;
};

Goal goals[3];
int goalCount = 0;
int currentIndex = 0;
unsigned long lastUpdate = 0;

// Forward declarations
void handleCommand(String command);
void showGoal();

// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 BLE cihaz bağlandı!");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE cihaz bağlantısı kesildi");
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      Serial.println("📩 BLE komutu alındı: " + value);
      handleCommand(value);
    }
  }
};

void handleCommand(String command) {
  DynamicJsonDocument doc(512);
  if (deserializeJson(doc, command) != DeserializationError::Ok) {
    Serial.println("❌ JSON parse hatası");
    return;
  }
  
  String action = doc["action"];
  if (action == "update_goals") {
    goalCount = 0;
    JsonArray goalsArray = doc["goals"];
    
    Serial.println("🎯 Hedefler güncelleniyor...");
    
    for (JsonObject goalObj : goalsArray) {
      if (goalCount >= 3) break;
      
      goals[goalCount].title = goalObj["title"].as<String>();
      goals[goalCount].current = goalObj["currentAmount"].as<int>();
      goals[goalCount].target = goalObj["targetAmount"].as<int>();
      
      Serial.println("  " + String(goalCount+1) + ". " + goals[goalCount].title + 
                    " (" + String(goals[goalCount].current) + "/" + String(goals[goalCount].target) + ")");
      
      goalCount++;
    }
    
    currentIndex = 0;
    Serial.println("✅ " + String(goalCount) + " hedef yüklendi");
    showGoal();
  }
}

void showGoal() {
  if (goalCount == 0) {
    Serial.println("📭 Gösterilecek hedef yok");
    return;
  }
  
  Goal g = goals[currentIndex];
  int progress = (g.target > 0) ? (g.current * 100) / g.target : 0;
  
  Serial.println("🎯 AKTİF HEDEF: " + g.title);
  Serial.println("💰 İlerleme: " + String(g.current) + "/" + String(g.target) + " (%" + String(progress) + ")");
  Serial.println("📊 Progress: " + String(progress) + "%");
  
  // ASCII progress bar
  String progressBar = "[";
  for (int i = 0; i < 20; i++) {
    if (i < (progress / 5)) {
      progressBar += "█";
    } else {
      progressBar += "░";
    }
  }
  progressBar += "]";
  Serial.println("📈 " + progressBar);
  Serial.println("───────────────────────────");
}

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n🚀 ESP32-C3 Kumbara Başlatılıyor ===");
  Serial.println("📺 TFT devre dışı - Sadece Serial Monitor");
  
  // BLE başlat
  Serial.println("🔵 BLE başlatılıyor...");
  
  BLEDevice::init("KumbaraDisplay");
  Serial.println("✅ BLE device hazır");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  Serial.println("✅ BLE server oluşturuldu");
  
  BLEService *pService = pServer->createService("12345678-1234-1234-1234-123456789abc");
  Serial.println("✅ BLE service oluşturuldu");
  
  pCharacteristic = pService->createCharacteristic(
    "12345678-1234-1234-1234-123456789abd",
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  Serial.println("✅ BLE characteristic oluşturuldu");
  
  pCharacteristic->setCallbacks(new CharacteristicCallbacks());
  pService->start();
  Serial.println("✅ BLE service başlatıldı");
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID("12345678-1234-1234-1234-123456789abc");
  pAdvertising->start();
  Serial.println("✅ BLE advertising başlatıldı");
  
  Serial.println("🎉 === KURULUM TAMAMLANDI ===");
  Serial.println("📱 Child App'ten 'KumbaraDisplay' cihazına bağlanın");
  Serial.println("🔄 Hedef döngüsü: 5 saniyede bir");
  Serial.println("═══════════════════════════════════");
}

void loop() {
  static unsigned long lastHeartbeat = 0;
  
  // Heartbeat - 10 saniyede bir
  if (millis() - lastHeartbeat > 10000) {
    Serial.println("💓 ESP32 çalışıyor... (" + String(millis() / 1000) + "s)");
    if (deviceConnected) {
      Serial.println("🔗 BLE bağlantısı aktif");
    } else {
      Serial.println("🔍 BLE bağlantısı bekleniyor...");
    }
    lastHeartbeat = millis();
  }
  
  // Hedef döngüsü (5 saniyede bir)
  if (millis() - lastUpdate > 5000 && goalCount > 0) {
    currentIndex = (currentIndex + 1) % goalCount;
    Serial.println("🔄 Sonraki hedefe geçiliyor...");
    showGoal();
    lastUpdate = millis();
  }
  
  // BLE yeniden başlat
  if (!deviceConnected && pServer) {
    delay(500);
    pServer->startAdvertising();
  }
  
  delay(100);
}

/*
 * TEST SONUÇLARI (26.01.2025):
 * 
 * ✅ ESP32 Serial Monitor Çıktısı:
 * 🎯 AKTİF HEDEF: PC
 * 💰 İlerleme: 28000/50000 (%56)
 * 📈 [███████████░░░░░░░░░]
 * ───────────────────────────
 * 🔄 Sonraki hedefe geçiliyor...
 * 🎯 AKTİF HEDEF: asdf
 * 💰 İlerleme: 20000/20000 (%100)
 * 📈 [████████████████████]
 * 
 * ✅ Child App Sync: BAŞARILI
 * ✅ BLE Bağlantısı: STABİL
 * ✅ Hedef Döngüsü: ÇALIŞIYOR
 * 
 * UUID'ler:
 * Service: 12345678-1234-1234-1234-123456789abc
 * Characteristic: 12345678-1234-1234-1234-123456789abd
 */ 