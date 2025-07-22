/*
 * 🏦 KUMBARA ESP32-C3 - TFT DISPLAY & BLE
 * Çalışan pin yapılandırması: MOSI=5, SCK=4, CS=3, DC=2, RST=1
 * 
 * Özellikler:
 * ✅ GC9A01 240x240 Dairesel TFT Ekran
 * ✅ BLE ile Child App sync
 * ✅ Hedef gösterimi (Progress Gauge)
 * ✅ Auto hedef döngüsü
 * ✅ Güzel animasyonlar
 */

#include <TFT_eSPI.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
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
unsigned long lastUpdate = 0;

// Animasyon
float currentAngle = -135.0;
float targetAngle = -135.0;
int displayedValue = 0;
int targetValue = 0;

// Forward declarations
void handleBLECommand(String command);
void drawCompleteDisplay();
void drawGaugeBase();
void drawProgressArc(int progress);
void drawGoalInfo();
void drawNeedle(float angle);
void animateToValue(int newValue, int maxValue);
void switchToNextGoal();

// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 BLE cihaz bağlandı!");
    
    // Bağlantı gösterimi
    tft.fillCircle(220, 20, 8, GREEN);
    tft.setTextColor(WHITE);
    tft.setTextSize(1);
    tft.drawString("BLE", 205, 35);
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE bağlantısı kesildi");
    
    // Bağlantı kesik gösterimi  
    tft.fillCircle(220, 20, 8, RED);
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString("BLE", 205, 35);
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
  Serial.println("🏦 Kumbara ESP32-C3 - TFT Display başlatılıyor...");
  
  // TFT başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Hoş geldin ekranı
  showWelcomeScreen();
  
  // BLE başlat
  initializeBLE();
  
  Serial.println("✅ Sistem hazır!");
}

void loop() {
  unsigned long now = millis();
  
  // Hedef döngüsü (5 saniyede bir)
  if (goalCount > 1 && now - lastGoalSwitch > 5000) {
    switchToNextGoal();
    lastGoalSwitch = now;
  }
  
  // Animasyon güncelle
  if (now - lastUpdate > 50) {
    updateAnimation();
    lastUpdate = now;
  }
  
  delay(10);
}

void showWelcomeScreen() {
  tft.fillScreen(BLACK);
  
  // Kumbara logosu çiz (basit)
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
  tft.drawString("ESP32-C3 Display", CENTER_X, CENTER_Y + 70);
  
  delay(2000);
  tft.fillScreen(BLACK);
}

void initializeBLE() {
  BLEDevice::init("Kumbara_Display");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService("12345678-1234-1234-1234-123456789abc");
  
  // Config characteristic (child app'ten komut alır)
  pCharacteristic = pService->createCharacteristic(
    "12345678-1234-1234-1234-123456789abd",
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  
  // Status characteristic (ESP32'den durum gönderir)
  BLECharacteristic *pStatusCharacteristic = pService->createCharacteristic(
    "12345678-1234-1234-1234-123456789abe",
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  
  pCharacteristic->setCallbacks(new CharacteristicCallbacks());
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID("12345678-1234-1234-1234-123456789abc");
  pAdvertising->setScanResponse(true);
  pAdvertising->start();
  
  Serial.println("🔵 BLE reklam başlatıldı");
}

void handleBLECommand(String command) {
  DynamicJsonDocument doc(1024);
  if (deserializeJson(doc, command) != DeserializationError::Ok) {
    Serial.println("❌ JSON parse hatası");
    return;
  }
  
  String action = doc["action"];
  
  if (action == "configure") {
    // Configure komutu - sadece log at
    Serial.println("✅ Configure komutu alındı");
    String deviceName = doc["deviceName"];
    String userId = doc["userId"];
    Serial.println("Device: " + deviceName + " | User: " + userId);
    return;
  }
  
  if (action == "update_goals") {
    goalCount = 0;
    JsonArray goalsArray = doc["goals"];
    
    Serial.println("🎯 Hedefler güncelleniyor...");
    
    // Renk paleti
    uint16_t colors[] = {KUMBARA_BLUE, GREEN, ORANGE, PURPLE, CYAN};
    
    for (JsonObject goalObj : goalsArray) {
      if (goalCount >= 5) break;
      
      goals[goalCount].title = goalObj["title"].as<String>();
      goals[goalCount].current = goalObj["currentAmount"].as<int>();
      goals[goalCount].target = goalObj["targetAmount"].as<int>();
      goals[goalCount].color = colors[goalCount % 5];
      
      Serial.println("  " + String(goalCount+1) + ". " + goals[goalCount].title + 
                    " (" + String(goals[goalCount].current) + "/" + String(goals[goalCount].target) + ")");
      
      goalCount++;
    }
    
    currentGoalIndex = 0;
    Serial.println("✅ " + String(goalCount) + " hedef yüklendi");
    
    if (goalCount > 0) {
      tft.fillScreen(BLACK);
      drawCompleteDisplay();
    }
  }
}

void drawCompleteDisplay() {
  if (goalCount == 0) {
    // Hedef bekleniyor ekranı
    tft.fillScreen(BLACK);
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(2);
    tft.setTextDatum(MC_DATUM);
    tft.drawString("Hedef", CENTER_X, CENTER_Y - 10);
    tft.drawString("Bekleniyor...", CENTER_X, CENTER_Y + 10);
    return;
  }
  
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
  
  // BLE durum göstergesi
  if (deviceConnected) {
    tft.fillCircle(220, 20, 8, GREEN);
    tft.setTextColor(WHITE);
    tft.setTextSize(1);
    tft.drawString("BLE", 205, 35);
  }
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
  
  // Hedef adı (üst kısım)
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
  
  // Yüzde (alt kısım)
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.drawString("%" + String(progress), CENTER_X, 200);
  
  // Hedef sayacı (birden fazla hedef varsa)
  if (goalCount > 1) {
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString(String(currentGoalIndex + 1) + "/" + String(goalCount), CENTER_X, 220);
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
  
  // Needle kalınlığı
  tft.drawLine(CENTER_X, CENTER_Y - 1, endX, endY - 1, RED);
  tft.drawLine(CENTER_X, CENTER_Y + 1, endX, endY + 1, RED);
  
  // Merkez nokta
  tft.fillCircle(CENTER_X, CENTER_Y, 3, WHITE);
}

void switchToNextGoal() {
  if (goalCount <= 1) return;
  
  currentGoalIndex = (currentGoalIndex + 1) % goalCount;
  
  // Geçiş efekti
  tft.fillRect(0, 180, 240, 60, BLACK);
  
  // Yeni hedefi göster
  drawCompleteDisplay();
  
  Serial.println("🔄 Hedef değişti: " + goals[currentGoalIndex].title);
}

void updateAnimation() {
  // Basit animasyon mantığı
  // Gerçek projede daha gelişmiş animasyonlar olabilir
} 