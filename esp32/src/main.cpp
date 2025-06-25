#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <TFT_eSPI.h>
// QR Code kütüphanesi - Arduino IDE için manuel kurulmalı
// #include <qrcode.h>

// ESP32-C3 Mini Pin Tanımlamaları
#define COIN_SENSOR_PIN 4      // Para algılama sensörü
#define BUTTON_PIN 9           // Kullanıcı butonu
#define LED_PIN 8              // Durum LED'i
#define BATTERY_PIN A0         // Batarya seviyesi (ADC)

// GC9A01 Yuvarlak OLED Ekran bağlantıları:
// RST -> GPIO 1
// CS  -> GPIO 10  
// DC  -> GPIO 2
// SDA -> GPIO 7 (MOSI)
// SCL -> GPIO 6 (SCK)
// VCC -> 3.3V
// GND -> GND

// GC9A01 240x240 Yuvarlak Ekran
#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 240
#define SCREEN_RADIUS 120

// Sistem sabitleri
#define DEVICE_NAME "KumbaraKontrol"
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Global değişkenler
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String deviceId;
String pairingCode;
String authToken;
String linkedAccountId;
String wifiSSID;
String wifiPassword;
String serverUrl = "http://192.168.1.21:3000"; // Varsayılan sunucu
int batteryLevel = 100;
unsigned long lastStatusUpdate = 0;
unsigned long lastBatteryCheck = 0;
unsigned long lastCoinTime = 0;
bool isWifiConnected = false;
Preferences preferences;
TFT_eSPI tft = TFT_eSPI();

// WiFi ve Server durumları
enum SystemState {
  STATE_INIT,
  STATE_WAITING_PAIR,
  STATE_WIFI_SETUP,
  STATE_CONNECTED,
  STATE_ERROR
};
SystemState currentState = STATE_INIT;

// Fonksiyon bildirimleri
void setLED(int state);
void generateDeviceId();
void generatePairingCode();
void initDisplay();
void drawPairingScreen();
void showStatusScreen();
void handleBLECommand(String command);
void connectWiFi();
void updateServerStatus();
void sendCoinTransaction(float amount = 1.0);
void checkBattery();

// BLE Callback sınıfları
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("BLE Cihaz bağlandı");
    setLED(LOW); // Bağlantı LED'i
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("BLE Cihaz bağlantısı kesildi");
    setLED(HIGH); // Bağlantı kesildi LED'i
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      Serial.println("BLE Komut alındı: " + value);
      handleBLECommand(value);
    }
  }
};

// Yardımcı fonksiyonlar
void setLED(int state) {
  digitalWrite(LED_PIN, state);
}

void generateDeviceId() {
  uint64_t chipid = ESP.getEfuseMac();
  deviceId = String((uint32_t)(chipid >> 32), HEX) + String((uint32_t)chipid, HEX);
  preferences.putString("deviceId", deviceId);
  Serial.println("Device ID oluşturuldu: " + deviceId);
}

void generatePairingCode() {
  pairingCode = String(random(100000, 999999));
  preferences.putString("pairingCode", pairingCode);
  Serial.println("Pairing Code: " + pairingCode);
}

void initDisplay() {
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM); // Merkez ortalama
  
  // Başlangıç ekranı
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("KUMBARA", SCREEN_WIDTH/2, 60);
  tft.drawString("KONTROL", SCREEN_WIDTH/2, 80);
  
  tft.setTextSize(1);
  tft.drawString("Device ID:", SCREEN_WIDTH/2, 120);
  tft.drawString(deviceId.substring(deviceId.length()-8), SCREEN_WIDTH/2, 140);
  
  Serial.println("Display başlatıldı");
}

void drawPairingScreen() {
  tft.fillScreen(TFT_BLACK);
  
  // Başlık
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("KUMBARA", SCREEN_WIDTH/2, 40);
  
  // Pairing bilgileri
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("BLE Eşleştirme", SCREEN_WIDTH/2, 80);
  
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("Kod:", SCREEN_WIDTH/2, 120);
  tft.drawString(pairingCode, SCREEN_WIDTH/2, 150);
  
  // Alt bilgi
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("Child App ile", SCREEN_WIDTH/2, 190);
  tft.drawString("Eşleştirin", SCREEN_WIDTH/2, 210);
}

void showStatusScreen() {
  tft.fillScreen(TFT_BLACK);
  
  // Durum başlığı
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("BAGLI", SCREEN_WIDTH/2, 40);
  
  // WiFi durumu
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("WiFi: " + String(isWifiConnected ? "OK" : "NONE"), SCREEN_WIDTH/2, 80);
  
  // Server durumu
  tft.drawString("Server: " + String(authToken.length() > 0 ? "OK" : "NONE"), SCREEN_WIDTH/2, 100);
  
  // Batarya seviyesi
  tft.drawString("Batarya: %" + String(batteryLevel), SCREEN_WIDTH/2, 120);
  
  // Account ID (kısa hali)
  if (linkedAccountId.length() > 0) {
    tft.drawString("Account: " + linkedAccountId.substring(linkedAccountId.length()-8), SCREEN_WIDTH/2, 140);
  }
  
  // Para bekleme durumu
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("Para Atmaya Hazir", SCREEN_WIDTH/2, 180);
}

void handleBLECommand(String command) {
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, command);
  
  if (error) {
    Serial.println("JSON parse hatası: " + String(error.c_str()));
    return;
  }
  
  String action = doc["action"];
  
  if (action == "configure") {
    // Child app'ten gelen konfigürasyon
    wifiSSID = doc["ssid"].as<String>();
    wifiPassword = doc["password"].as<String>();
    serverUrl = doc["server"].as<String>();
    String userId = doc["userId"].as<String>();
    String deviceName = doc["deviceName"].as<String>();
    
    // Bilgileri kaydet
    preferences.putString("wifiSSID", wifiSSID);
    preferences.putString("wifiPassword", wifiPassword);
    preferences.putString("serverUrl", serverUrl);
    preferences.putString("userId", userId);
    preferences.putString("deviceName", deviceName);
    
    Serial.println("Konfigürasyon alındı:");
    Serial.println("SSID: " + wifiSSID);
    Serial.println("Server: " + serverUrl);
    Serial.println("User ID: " + userId);
    Serial.println("Device Name: " + deviceName);
    
    // WiFi'ye bağlanmayı dene
    connectWiFi();
  }
  else if (action == "pair") {
    String code = doc["code"];
    if (code == pairingCode) {
      authToken = doc["token"].as<String>();
      linkedAccountId = doc["accountId"].as<String>();
      preferences.putString("authToken", authToken);
      preferences.putString("linkedAccountId", linkedAccountId);
      
      Serial.println("Eşleştirme başarılı!");
      Serial.println("Token: " + authToken);
      Serial.println("Account ID: " + linkedAccountId);
      
      currentState = STATE_WIFI_SETUP;
    }
  }
}

void connectWiFi() {
  if (wifiSSID.length() == 0) {
    Serial.println("WiFi SSID bulunamadı");
    return;
  }
  
  Serial.println("WiFi'ye bağlanılıyor: " + wifiSSID);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    isWifiConnected = true;
    Serial.println("\nWiFi bağlandı!");
    Serial.println("IP adresi: " + WiFi.localIP().toString());
    currentState = STATE_CONNECTED;
    showStatusScreen();
  } else {
    isWifiConnected = false;
    Serial.println("\nWiFi bağlantısı başarısız!");
    currentState = STATE_ERROR;
  }
}

void updateServerStatus() {
  if (!isWifiConnected || authToken.length() == 0) return;
  
  HTTPClient http;
  http.begin(serverUrl + "/api/devices/" + deviceId + "/status");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + authToken);
  
  String payload = "{\"batteryLevel\":" + String(batteryLevel) + 
                   ",\"wifiSignal\":" + String(WiFi.RSSI()) + 
                   ",\"lastSeen\":\"" + String(millis()) + "\"}";
  
  int httpResponseCode = http.POST(payload);
  
  if (httpResponseCode > 0) {
    Serial.println("Server status güncellendi: " + String(httpResponseCode));
  } else {
    Serial.println("Server status güncellenemedi: " + String(httpResponseCode));
  }
  
  http.end();
}

void sendCoinTransaction(float amount) {
  if (!isWifiConnected || linkedAccountId.length() == 0) {
    Serial.println("WiFi veya Account bağlantısı yok!");
    return;
  }
  
  HTTPClient http;
  http.begin(serverUrl + "/api/esp32/transaction");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-ESP32-Secret", "esp32-secret-key-2025");
  
  String payload = "{\"deviceId\":\"" + deviceId + 
                   "\",\"type\":\"deposit\"" +
                   ",\"amount\":" + String(amount) + 
                   ",\"description\":\"ESP32-C3 Para Yatırma\"}";
  
  Serial.println("Para işlemi gönderiliyor: " + payload);
  
  int httpResponseCode = http.POST(payload);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Para işlemi başarılı: " + response);
    
    // Ekranda başarı mesajı göster
    tft.fillRect(0, 200, SCREEN_WIDTH, 40, TFT_BLACK);
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.setTextSize(1);
    tft.drawString("+" + String(amount) + " TL EKLENDI", SCREEN_WIDTH/2, 220);
    
    // LED yanıp sönsün
    for (int i = 0; i < 5; i++) {
      setLED(LOW);
      delay(100);
      setLED(HIGH);
      delay(100);
    }
    
    // 3 saniye sonra normal ekrana dön
    delay(3000);
    showStatusScreen();
    
  } else {
    Serial.println("Para işlemi başarısız: " + String(httpResponseCode));
    
    // Ekranda hata mesajı göster
    tft.fillRect(0, 200, SCREEN_WIDTH, 40, TFT_BLACK);
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.setTextSize(1);
    tft.drawString("HATA: " + String(httpResponseCode), SCREEN_WIDTH/2, 220);
    
    delay(2000);
    showStatusScreen();
  }
  
  http.end();
}

void checkBattery() {
  int adcValue = analogRead(BATTERY_PIN);
  batteryLevel = map(adcValue, 0, 4095, 0, 100);
  if (batteryLevel > 100) batteryLevel = 100;
  if (batteryLevel < 0) batteryLevel = 0;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Kumbara Kontrol sistemi başlatılıyor...");
  
  // Pin modları
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(COIN_SENSOR_PIN, INPUT_PULLUP);
  
  // LED'i yakarak başlangıcı göster
  setLED(HIGH);
  
  // Preferences başlat
  preferences.begin("kumbara", false);
  
  // Kaydedilmiş değerleri yükle
  deviceId = preferences.getString("deviceId", "");
  if (deviceId.length() == 0) {
    generateDeviceId();
  }
  
  authToken = preferences.getString("authToken", "");
  linkedAccountId = preferences.getString("linkedAccountId", "");
  wifiSSID = preferences.getString("wifiSSID", "");
  wifiPassword = preferences.getString("wifiPassword", "");
  serverUrl = preferences.getString("serverUrl", "http://192.168.1.21:3000");
  
  // Display başlat
  initDisplay();
  
  // Reset butonu kontrolü
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("Reset butonu basılı - ayarlar temizleniyor...");
    preferences.clear();
    ESP.restart();
  }
  
  // BLE başlat
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE
                    );
  
  pCharacteristic->setCallbacks(new CharacteristicCallbacks());
  
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE advertising başladı");
  
  // Pairing code oluştur ve eşleştirme ekranını göster
  generatePairingCode();
  drawPairingScreen();
  
  currentState = STATE_WAITING_PAIR;
  
  // Eğer daha önce WiFi bilgileri varsa bağlanmayı dene
  if (wifiSSID.length() > 0 && authToken.length() > 0) {
    Serial.println("Önceki WiFi ayarları bulundu, bağlanılıyor...");
    connectWiFi();
  }
  
  Serial.println("Sistem hazır!");
}

void loop() {
  // BLE bağlantı durumu değişikliği kontrolü
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // BLE stack'in hazır olması için bekle
    pServer->startAdvertising();
    Serial.println("BLE advertising yeniden başladı");
    oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  
  // Para sensörü kontrolü
  if (digitalRead(COIN_SENSOR_PIN) == LOW && currentState == STATE_CONNECTED) {
    // Debounce kontrolü
    if (millis() - lastCoinTime > 1000) {
      Serial.println("Para algılandı!");
      sendCoinTransaction(1.0); // 1 TL para ekle
      lastCoinTime = millis();
    }
  }
  
  // Reset butonu kontrolü
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(3000); // 3 saniye basılı tutma kontrolü
    if (digitalRead(BUTTON_PIN) == LOW) {
      Serial.println("Reset butonu 3 saniye basılı - ayarlar temizleniyor...");
      preferences.clear();
      tft.fillScreen(TFT_RED);
      tft.setTextColor(TFT_WHITE, TFT_RED);
      tft.drawString("RESET...", SCREEN_WIDTH/2, SCREEN_HEIGHT/2);
      delay(2000);
      ESP.restart();
    }
  }
  
  // Periyodik kontroller
  if (millis() - lastStatusUpdate > 60000) { // 1 dakikada bir
    updateServerStatus();
    lastStatusUpdate = millis();
  }
  
  if (millis() - lastBatteryCheck > 300000) { // 5 dakikada bir
    checkBattery();
    if (currentState == STATE_CONNECTED) {
      showStatusScreen(); // Batarya bilgisini güncelle
    }
    lastBatteryCheck = millis();
  }
  
  delay(100); // CPU yükünü azaltmak için
} 