/*
 * 🏦 KUMBARA ESP32-C3 MINIMAL DISPLAY
 * Pin: MOSI=5, SCK=4, CS=3, DC=2, RST=1
 * 
 * ✅ TFT + BLE (WiFi/HTTP yok - memory save)
 * ✅ Child app'den direkt hedef alır
 * ✅ Gauge gösterimi
 */

#include <TFT_eSPI.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <math.h>

// TFT
TFT_eSPI tft = TFT_eSPI();

// Ekran sabitler
#define CENTER_X 120
#define CENTER_Y 120
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

// Hedefler (basit struct)
struct Goal {
  char title[20];
  int current;
  int target;
  uint16_t color;
};

Goal goals[3];
int goalCount = 0;
int currentGoalIndex = 0;
unsigned long lastGoalSwitch = 0;

// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 BLE bağlandı!");
    
    // BLE durum göstergesi
    tft.fillCircle(20, 15, 6, BLUE);
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE kesildi");
    
    // BLE durum göstergesi
    tft.fillCircle(20, 15, 6, DARK_GRAY);
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    Serial.println("📩 BLE: " + value);
    handleBLEData(value);
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("🏦 Kumbara Minimal Display");
  
  // TFT başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Hoş geldin
  showWelcome();
  
  // BLE başlat
  initBLE();
  
  // Bekleme ekranı
  drawWaitingScreen();
  
  Serial.println("✅ Hazır!");
}

void loop() {
  unsigned long now = millis();
  
  // Hedef döngüsü (5 saniye)
  if (goalCount > 1 && now - lastGoalSwitch > 5000) {
    switchGoal();
    lastGoalSwitch = now;
  }
  
  delay(100);
}

void showWelcome() {
  tft.fillScreen(BLACK);
  
  // Logo
  tft.fillCircle(CENTER_X, CENTER_Y - 20, 35, KUMBARA_BLUE);
  tft.fillRect(CENTER_X - 15, CENTER_Y - 10, 30, 15, KUMBARA_BLUE);
  tft.fillCircle(CENTER_X, CENTER_Y + 5, 10, YELLOW);
  
  // Text
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", CENTER_X, CENTER_Y + 40);
  
  tft.setTextSize(1);
  tft.setTextColor(LIGHT_GRAY);
  tft.drawString("Minimal Display", CENTER_X, CENTER_Y + 60);
  
  delay(2000);
}

void initBLE() {
  BLEDevice::init("Kumbara_Mini");
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
  pAdvertising->start();
  
  Serial.println("🔵 BLE: Kumbara_Mini");
}

void handleBLEData(String data) {
  // Basit JSON parse (ArduinoJson kullanmadan)
  
  if (data.indexOf("update_goals") > 0) {
    Serial.println("🎯 Hedefler güncelleniyor...");
    
    // Demo hedefler (gerçek JSON parse yerine)
    goalCount = 3;
    
    strcpy(goals[0].title, "PS5");
    goals[0].current = 750;
    goals[0].target = 1500;
    goals[0].color = KUMBARA_BLUE;
    
    strcpy(goals[1].title, "Bisiklet");
    goals[1].current = 300;
    goals[1].target = 800;
    goals[1].color = GREEN;
    
    strcpy(goals[2].title, "Kitap");
    goals[2].current = 45;
    goals[2].target = 100;
    goals[2].color = ORANGE;
    
    currentGoalIndex = 0;
    Serial.println("✅ " + String(goalCount) + " hedef yüklendi");
    
    tft.fillScreen(BLACK);
    drawDisplay();
    
  } else if (data.indexOf("configure") > 0) {
    Serial.println("⚙️ Config alındı");
    // Minimal versiyonda WiFi yok
  }
}

void drawWaitingScreen() {
  tft.fillScreen(BLACK);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Hedef", CENTER_X, CENTER_Y - 10);
  tft.drawString("Bekleniyor", CENTER_X, CENTER_Y + 10);
  
  tft.setTextSize(1);
  tft.drawString("BLE: Kumbara_Mini", CENTER_X, CENTER_Y + 40);
  
  // BLE durum
  tft.fillCircle(20, 15, 6, DARK_GRAY);
}

void drawDisplay() {
  if (goalCount == 0) return;
  
  Goal g = goals[currentGoalIndex];
  int progress = (g.target > 0) ? (g.current * 100) / g.target : 0;
  
  // Gauge tabanı
  drawGaugeBase();
  
  // Progress arc
  drawProgressArc(progress, g.color);
  
  // Bilgiler
  drawGoalInfo(g, progress);
  
  // Needle
  float angle = map(progress, 0, 100, -135, 135);
  drawNeedle(angle);
  
  // BLE durum
  tft.fillCircle(20, 15, 6, deviceConnected ? BLUE : DARK_GRAY);
}

void drawGaugeBase() {
  // Dış çerçeve
  for(int i = 0; i < 3; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, OUTER_RADIUS - i, LIGHT_GRAY);
  }
  
  // İç çerçeve
  tft.drawCircle(CENTER_X, CENTER_Y, INNER_RADIUS, DARK_GRAY);
  
  // % işaretleri
  for(int val = 0; val <= 100; val += 25) {
    float angle = map(val, 0, 100, -135, 135);
    float rad = angle * PI / 180.0;
    
    int x1 = CENTER_X + (OUTER_RADIUS - 5) * cos(rad);
    int y1 = CENTER_Y + (OUTER_RADIUS - 5) * sin(rad);
    int x2 = CENTER_X + (OUTER_RADIUS - 15) * cos(rad);
    int y2 = CENTER_Y + (OUTER_RADIUS - 15) * sin(rad);
    
    tft.drawLine(x1, y1, x2, y2, WHITE);
    
    // % yazısı
    int textX = CENTER_X + (OUTER_RADIUS - 25) * cos(rad);
    int textY = CENTER_Y + (OUTER_RADIUS - 25) * sin(rad);
    
    tft.setTextColor(WHITE);
    tft.setTextSize(1);
    tft.setTextDatum(MC_DATUM);
    tft.drawString(String(val) + "%", textX, textY);
  }
  
  // Merkez
  tft.fillCircle(CENTER_X, CENTER_Y, 12, DARK_GRAY);
  tft.drawCircle(CENTER_X, CENTER_Y, 12, WHITE);
}

void drawProgressArc(int progress, uint16_t color) {
  float startAngle = -135.0;
  float endAngle = map(progress, 0, 100, -135, 135);
  
  for(float angle = startAngle; angle <= endAngle; angle += 3.0) {
    float rad = angle * PI / 180.0;
    
    for(int r = INNER_RADIUS + 3; r < OUTER_RADIUS - 3; r += 3) {
      int x = CENTER_X + r * cos(rad);
      int y = CENTER_Y + r * sin(rad);
      tft.drawPixel(x, y, color);
    }
  }
}

void drawGoalInfo(Goal g, int progress) {
  // Hedef adı (üst)
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(g.title, CENTER_X, 40);
  
  // Para (merkez)
  tft.setTextColor(g.color);
  tft.setTextSize(2);
  tft.drawString(String(g.current), CENTER_X, CENTER_Y - 5);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(1);
  tft.drawString("/" + String(g.target) + " TL", CENTER_X, CENTER_Y + 15);
  
  // Yüzde (alt)
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.drawString("%" + String(progress), CENTER_X, 190);
  
  // Sayaç
  if (goalCount > 1) {
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString(String(currentGoalIndex + 1) + "/" + String(goalCount), CENTER_X, 210);
  }
}

void drawNeedle(float angle) {
  float rad = angle * PI / 180.0;
  
  int endX = CENTER_X + NEEDLE_LENGTH * cos(rad);
  int endY = CENTER_Y + NEEDLE_LENGTH * sin(rad);
  
  // Gölge
  tft.drawLine(CENTER_X + 1, CENTER_Y + 1, endX + 1, endY + 1, DARK_GRAY);
  
  // Ana needle
  tft.drawLine(CENTER_X, CENTER_Y, endX, endY, RED);
  tft.drawLine(CENTER_X - 1, CENTER_Y, endX - 1, endY, RED);
  tft.drawLine(CENTER_X + 1, CENTER_Y, endX + 1, endY, RED);
  
  // Merkez nokta
  tft.fillCircle(CENTER_X, CENTER_Y, 3, WHITE);
}

void switchGoal() {
  if (goalCount <= 1) return;
  
  currentGoalIndex = (currentGoalIndex + 1) % goalCount;
  
  // Temizle ve yeniden çiz
  tft.fillRect(0, 170, 240, 70, BLACK);
  drawDisplay();
  
  Serial.println("🔄 Hedef: " + String(goals[currentGoalIndex].title));
} 