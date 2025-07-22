/*
 * 🏦 KUMBARA ESP32-C3 IoT DISPLAY
 * Çalışan pin yapılandırması: MOSI=5, SCK=4, CS=3, DC=2, RST=1
 * 
 * 🔄 IoT Workflow:
 * 1. BLE → WiFi + Server config al
 * 2. WiFi → Backend'e bağlan  
 * 3. HTTP → Hedefleri çek
 * 4. TFT → Gauge göster
 * 5. Auto → Periyodik güncelle
 */

#include <TFT_eSPI.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <math.h>

// TFT
TFT_eSPI tft = TFT_eSPI();

// Ekran sabitler
#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 240
#define CENTER_X 120
#define CENTER_Y 120

// Gauge parametreleri
#define OUTER_RADIUS 110
#define INNER_RADIUS 80
#define NEEDLE_LENGTH 75

// Renkler
#define BLACK      0x0000
#define WHITE      0xFFFF
#define RED        0xF800
#define GREEN      0x07E0
#define BLUE       0x001F
#define YELLOW     0xFFE0
#define ORANGE     0xFD20
#define PURPLE     0x780F
#define CYAN       0x07FF
#define KUMBARA_BLUE 0x1E9F
#define LIGHT_GRAY 0xC618
#define DARK_GRAY  0x7BEF

// Sistem durumu
enum SystemState {
  WAITING_CONFIG,
  CONNECTING_WIFI,
  CONNECTED,
  FETCHING_DATA,
  DISPLAYING,
  ERROR_STATE
};

SystemState currentState = WAITING_CONFIG;

// WiFi & Server config
String wifiSSID = "";
String wifiPassword = "";
String serverURL = "";
String userID = "";
String deviceName = "";
String deviceSecret = "";

// BLE
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// Hedefler
struct Goal {
  String title;
  int current;
  int target;
  uint16_t color;
};

Goal goals[5];
int goalCount = 0;
int currentGoalIndex = 0;
unsigned long lastGoalSwitch = 0;
unsigned long lastDataFetch = 0;
unsigned long lastUpdate = 0;

// Timing
const unsigned long GOAL_SWITCH_INTERVAL = 5000;   // 5 saniye
const unsigned long DATA_FETCH_INTERVAL = 30000;   // 30 saniye

// Forward declarations
void handleBLECommand(String command);
void connectToWiFi();
void fetchGoalsFromServer();
void drawCompleteDisplay();
void drawWaitingScreen();
void drawGaugeBase();
void drawProgressArc(int progress);
void drawGoalInfo();
void drawNeedle(float angle);
void drawStatusBar();
void switchToNextGoal();
void showSystemState(String message, uint16_t color = WHITE);

// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 BLE cihaz bağlandı!");
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE bağlantısı kesildi");
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      Serial.println("📩 BLE komutu: " + value);
      handleBLECommand(value);
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("🏦 Kumbara IoT Display başlatılıyor...");
  
  // TFT başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Hoş geldin ekranı
  showWelcomeScreen();
  
  // BLE başlat
  initializeBLE();
  
  // Bekleme ekranı
  drawWaitingScreen();
  
  Serial.println("✅ Sistem hazır - WiFi config bekleniyor!");
}

void loop() {
  unsigned long now = millis();
  
  switch(currentState) {
    case WAITING_CONFIG:
      // BLE config bekleniyor
      if (now % 2000 < 1000) {
        drawStatusBar();
      }
      break;
      
    case CONNECTING_WIFI:
      // WiFi bağlantısı deneniyor
      break;
      
    case CONNECTED:
      // İlk data fetch
      currentState = FETCHING_DATA;
      fetchGoalsFromServer();
      lastDataFetch = now;
      break;
      
    case FETCHING_DATA:
      // Data fetch işlemi devam ediyor
      break;
      
    case DISPLAYING:
      // Normal çalışma modu
      
      // Periyodik data fetch
      if (now - lastDataFetch > DATA_FETCH_INTERVAL) {
        Serial.println("🔄 Periyodik data güncelleme...");
        fetchGoalsFromServer();
        lastDataFetch = now;
      }
      
      // Hedef döngüsü
      if (goalCount > 1 && now - lastGoalSwitch > GOAL_SWITCH_INTERVAL) {
        switchToNextGoal();
        lastGoalSwitch = now;
      }
      
      // Ekran güncelleme
      if (now - lastUpdate > 100) {
        drawStatusBar();
        lastUpdate = now;
      }
      break;
      
    case ERROR_STATE:
      // Hata durumu - config'e geri dön
      if (now % 5000 < 100) {
        currentState = WAITING_CONFIG;
        drawWaitingScreen();
      }
      break;
  }
  
  delay(10);
}

void showWelcomeScreen() {
  tft.fillScreen(BLACK);
  
  // Kumbara logosu
  tft.fillCircle(CENTER_X, CENTER_Y - 20, 40, KUMBARA_BLUE);
  tft.fillRect(CENTER_X - 20, CENTER_Y - 10, 40, 20, KUMBARA_BLUE);
  tft.fillCircle(CENTER_X, CENTER_Y + 10, 15, YELLOW);
  
  // Metin
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", CENTER_X, CENTER_Y + 50);
  
  tft.setTextSize(1);
  tft.setTextColor(LIGHT_GRAY);
  tft.drawString("IoT Display v2.0", CENTER_X, CENTER_Y + 70);
  
  delay(2000);
}

void initializeBLE() {
  BLEDevice::init("Kumbara_IoT");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService("12345678-1234-1234-1234-123456789abc");
  
  pCharacteristic = pService->createCharacteristic(
    "12345678-1234-1234-1234-123456789abd",
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  
  pCharacteristic->setCallbacks(new CharacteristicCallbacks());
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID("12345678-1234-1234-1234-123456789abc");
  pAdvertising->setScanResponse(true);
  pAdvertising->start();
  
  Serial.println("🔵 BLE başlatıldı - 'Kumbara_IoT' olarak yayında");
}

void handleBLECommand(String command) {
  DynamicJsonDocument doc(1024);
  if (deserializeJson(doc, command) != DeserializationError::Ok) {
    Serial.println("❌ JSON parse hatası");
    return;
  }
  
  String action = doc["action"];
  
  if (action == "configure") {
    Serial.println("⚙️ WiFi konfigürasyonu alındı");
    
    wifiSSID = doc["ssid"].as<String>();
    wifiPassword = doc["password"].as<String>();
    serverURL = doc["server"].as<String>();
    userID = doc["userId"].as<String>();
    deviceName = doc["deviceName"].as<String>();
    deviceSecret = doc["secret"].as<String>();
    
    Serial.println("📶 SSID: " + wifiSSID);
    Serial.println("🌐 Server: " + serverURL);
    Serial.println("👤 User: " + userID);
    Serial.println("📱 Device: " + deviceName);
    
    // WiFi'ye bağlanmaya başla
    currentState = CONNECTING_WIFI;
    connectToWiFi();
    
    return;
  }
  
  Serial.println("❓ Bilinmeyen komut: " + action);
}

void connectToWiFi() {
  Serial.println("📡 WiFi'ye bağlanılıyor: " + wifiSSID);
  showSystemState("WiFi Bağlanıyor...", YELLOW);
  
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi bağlantısı başarılı!");
    Serial.println("🌐 IP: " + WiFi.localIP().toString());
    
    showSystemState("WiFi Bağlandı!", GREEN);
    delay(1000);
    
    currentState = CONNECTED;
  } else {
    Serial.println("\n❌ WiFi bağlantısı başarısız!");
    showSystemState("WiFi Hatası!", RED);
    
    currentState = ERROR_STATE;
  }
}

void fetchGoalsFromServer() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi bağlantısı yok!");
    currentState = ERROR_STATE;
    return;
  }
  
  currentState = FETCHING_DATA;
  showSystemState("Veriler Çekiliyor...", CYAN);
  
  HTTPClient http;
  String url = serverURL + "/api/goals/user/" + userID;
  
  Serial.println("🌐 API çağrısı: " + url);
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-ESP32-Secret", deviceSecret);
  
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String payload = http.getString();
    Serial.println("📦 Veri alındı: " + payload.substring(0, 100) + "...");
    
    // JSON parse
    DynamicJsonDocument doc(2048);
    if (deserializeJson(doc, payload) == DeserializationError::Ok) {
      
      goalCount = 0;
      JsonArray goalsArray = doc["goals"];
      uint16_t colors[] = {KUMBARA_BLUE, GREEN, ORANGE, PURPLE, CYAN};
      
      for (JsonObject goalObj : goalsArray) {
        if (goalCount >= 5) break;
        
        goals[goalCount].title = goalObj["name"].as<String>();
        goals[goalCount].current = goalObj["currentAmount"].as<int>();
        goals[goalCount].target = goalObj["targetAmount"].as<int>();
        goals[goalCount].color = colors[goalCount % 5];
        
        Serial.println("🎯 " + goals[goalCount].title + 
                      " (" + String(goals[goalCount].current) + 
                      "/" + String(goals[goalCount].target) + ")");
        
        goalCount++;
      }
      
      Serial.println("✅ " + String(goalCount) + " hedef yüklendi");
      
      currentGoalIndex = 0;
      currentState = DISPLAYING;
      
      tft.fillScreen(BLACK);
      if (goalCount > 0) {
        drawCompleteDisplay();
      } else {
        showSystemState("Hedef Bulunamadı", ORANGE);
      }
      
    } else {
      Serial.println("❌ JSON parse hatası");
      currentState = ERROR_STATE;
    }
    
  } else {
    Serial.println("❌ HTTP Error: " + String(httpCode));
    currentState = ERROR_STATE;
  }
  
  http.end();
}

void drawWaitingScreen() {
  tft.fillScreen(BLACK);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Config", CENTER_X, CENTER_Y - 20);
  tft.drawString("Bekleniyor...", CENTER_X, CENTER_Y + 10);
  
  tft.setTextSize(1);
  tft.drawString("BLE: Kumbara_IoT", CENTER_X, CENTER_Y + 40);
}

void showSystemState(String message, uint16_t color) {
  // Alt kısımda durum mesajı
  tft.fillRect(0, 200, 240, 40, BLACK);
  tft.setTextColor(color);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(message, CENTER_X, 220);
}

void drawCompleteDisplay() {
  if (goalCount == 0) return;
  
  Goal currentGoal = goals[currentGoalIndex];
  int progress = (currentGoal.target > 0) ? (currentGoal.current * 100) / currentGoal.target : 0;
  
  // Gauge tabanı
  drawGaugeBase();
  
  // Progress arc
  drawProgressArc(progress);
  
  // Hedef bilgisi
  drawGoalInfo();
  
  // Needle
  float angle = map(progress, 0, 100, -135, 135);
  drawNeedle(angle);
  
  // Durum çubuğu
  drawStatusBar();
}

void drawGaugeBase() {
  // Dış çerçeve
  for(int i = 0; i < 3; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, OUTER_RADIUS - i, LIGHT_GRAY);
  }
  
  // İç çerçeve  
  for(int i = 0; i < 2; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, INNER_RADIUS + i, DARK_GRAY);
  }
  
  // Değer işaretleri
  for(int value = 0; value <= 100; value += 25) {
    float angle = map(value, 0, 100, -135, 135);
    float radian = angle * PI / 180.0;
    
    int outerR = OUTER_RADIUS - 5;
    int innerR = OUTER_RADIUS - 15;
    
    int x1 = CENTER_X + outerR * cos(radian);
    int y1 = CENTER_Y + outerR * sin(radian);
    int x2 = CENTER_X + innerR * cos(radian);
    int y2 = CENTER_Y + innerR * sin(radian);
    
    tft.drawLine(x1, y1, x2, y2, WHITE);
    
    // Yüzde yazısı
    int textR = OUTER_RADIUS - 25;
    int textX = CENTER_X + textR * cos(radian);
    int textY = CENTER_Y + textR * sin(radian);
    
    tft.setTextColor(WHITE);
    tft.setTextSize(1);
    tft.setTextDatum(MC_DATUM);
    tft.drawString(String(value) + "%", textX, textY);
  }
  
  // Merkez daire
  tft.fillCircle(CENTER_X, CENTER_Y, 15, DARK_GRAY);
  tft.drawCircle(CENTER_X, CENTER_Y, 15, WHITE);
}

void drawProgressArc(int progress) {
  Goal currentGoal = goals[currentGoalIndex];
  
  float startAngle = -135.0;
  float endAngle = map(progress, 0, 100, -135, 135);
  
  // Progress yay çiz
  for(float angle = startAngle; angle <= endAngle; angle += 2.0) {
    float radian = angle * PI / 180.0;
    
    for(int r = INNER_RADIUS + 5; r < OUTER_RADIUS - 5; r += 2) {
      int x = CENTER_X + r * cos(radian);
      int y = CENTER_Y + r * sin(radian);
      tft.drawPixel(x, y, currentGoal.color);
    }
  }
}

void drawGoalInfo() {
  Goal currentGoal = goals[currentGoalIndex];
  int progress = (currentGoal.target > 0) ? (currentGoal.current * 100) / currentGoal.target : 0;
  
  // Hedef adı (üst)
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  
  String title = currentGoal.title;
  if (title.length() > 12) {
    title = title.substring(0, 12) + "...";
  }
  tft.drawString(title, CENTER_X, 40);
  
  // Para miktarı (merkez)
  tft.setTextColor(currentGoal.color);
  tft.setTextSize(2);
  tft.drawString(String(currentGoal.current), CENTER_X, CENTER_Y - 5);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(1);
  tft.drawString("/" + String(currentGoal.target) + " TL", CENTER_X, CENTER_Y + 15);
  
  // Yüzde (alt)
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.drawString("%" + String(progress), CENTER_X, 180);
  
  // Hedef sayacı
  if (goalCount > 1) {
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString(String(currentGoalIndex + 1) + "/" + String(goalCount), CENTER_X, 200);
  }
}

void drawNeedle(float angle) {
  float radian = angle * PI / 180.0;
  
  int endX = CENTER_X + NEEDLE_LENGTH * cos(radian);
  int endY = CENTER_Y + NEEDLE_LENGTH * sin(radian);
  
  // Needle gölgesi
  tft.drawLine(CENTER_X + 1, CENTER_Y + 1, endX + 1, endY + 1, DARK_GRAY);
  
  // Ana needle
  tft.drawLine(CENTER_X, CENTER_Y, endX, endY, RED);
  tft.drawLine(CENTER_X, CENTER_Y - 1, endX, endY - 1, RED);
  tft.drawLine(CENTER_X, CENTER_Y + 1, endX, endY + 1, RED);
  
  // Merkez nokta
  tft.fillCircle(CENTER_X, CENTER_Y, 3, WHITE);
}

void drawStatusBar() {
  // WiFi durumu (üst sağ)
  uint16_t wifiColor = (WiFi.status() == WL_CONNECTED) ? GREEN : RED;
  tft.fillCircle(220, 15, 6, wifiColor);
  
  // BLE durumu (üst sol)  
  uint16_t bleColor = deviceConnected ? BLUE : DARK_GRAY;
  tft.fillCircle(20, 15, 6, bleColor);
  
  // Signal strength
  if (WiFi.status() == WL_CONNECTED) {
    int rssi = WiFi.RSSI();
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString(String(rssi) + "dB", 190, 30);
  }
}

void switchToNextGoal() {
  if (goalCount <= 1) return;
  
  currentGoalIndex = (currentGoalIndex + 1) % goalCount;
  
  // Geçiş efekti
  tft.fillRect(0, 160, 240, 80, BLACK);
  
  // Yeni hedefi göster
  drawCompleteDisplay();
  
  Serial.println("🔄 Hedef değişti: " + goals[currentGoalIndex].title);
} 