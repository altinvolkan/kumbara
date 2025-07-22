/*
 * 🏦 KUMBARA ESP32-C3 OPTIMIZED DISPLAY
 * Pin: MOSI=5, SCK=4, CS=3, DC=2, RST=1
 * 
 * ✅ Memory Optimized (Custom JSON parser)
 * ✅ WiFi + HTTP (Backend data)
 * ✅ BLE Config
 * ✅ TFT Gauge Display
 */

#include <TFT_eSPI.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>

// TFT
TFT_eSPI tft = TFT_eSPI();

// Constants
#define CENTER_X 120
#define CENTER_Y 120
#define OUTER_RADIUS 110
#define INNER_RADIUS 80

// Colors
#define BLACK 0x0000
#define WHITE 0xFFFF  
#define RED 0xF800
#define GREEN 0x07E0
#define BLUE 0x001F
#define YELLOW 0xFFE0
#define ORANGE 0xFD20
#define PURPLE 0x780F
#define CYAN 0x07FF
#define KUMBARA_BLUE 0x1E9F
#define LIGHT_GRAY 0xC618
#define DARK_GRAY 0x7BEF

// System State
enum State {
  WAIT_CONFIG,
  CONNECTING,
  CONNECTED,
  FETCHING,
  DISPLAY_GOALS,
  ERROR_STATE
};

State currentState = WAIT_CONFIG;

// Config
char wifiSSID[32] = "";
char wifiPassword[64] = "";
char serverURL[100] = "";
char userID[32] = "";

// BLE
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// Goals (minimal struct)
struct Goal {
  char name[20];
  int current;
  int target;
  uint16_t color;
};

Goal goals[3];
int goalCount = 0;
int currentGoal = 0;
unsigned long lastSwitch = 0;
unsigned long lastFetch = 0;

// Forward declarations
void handleBLE(String data);
void connectWiFi();
void fetchGoals();
void drawState(String msg, uint16_t color = WHITE);
void drawGoalDisplay();
void parseGoalsJSON(String json);
String extractJSONValue(String json, String key);

// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 BLE ON");
    tft.fillCircle(20, 15, 5, BLUE);
  }
  
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE OFF");
    tft.fillCircle(20, 15, 5, DARK_GRAY);
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    Serial.println("📩 " + value.substring(0, 50) + "...");
    handleBLE(value);
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("🏦 Kumbara Optimized");
  
  // TFT
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Welcome
  showWelcome();
  
  // BLE
  initBLE();
  
  // Wait screen
  drawWaitScreen();
  
  Serial.println("✅ Ready - Waiting WiFi config");
}

void loop() {
  unsigned long now = millis();
  
  switch(currentState) {
    case WAIT_CONFIG:
      // Blink status
      if (now % 2000 < 1000) {
        drawState("Config Bekleniyor", YELLOW);
      }
      break;
      
    case CONNECTING:
      // WiFi connecting
      break;
      
    case CONNECTED:
      // First fetch
      currentState = FETCHING;
      fetchGoals();
      lastFetch = now;
      break;
      
    case FETCHING:
      // Fetching in progress
      break;
      
    case DISPLAY_GOALS:
      // Auto refresh (30s)
      if (now - lastFetch > 30000) {
        Serial.println("🔄 Auto refresh");
        fetchGoals();
        lastFetch = now;
      }
      
      // Goal cycling (5s)
      if (goalCount > 1 && now - lastSwitch > 5000) {
        switchGoal();
        lastSwitch = now;
      }
      break;
      
    case ERROR_STATE:
      // Auto retry (10s)
      if (now % 10000 < 100) {
        currentState = WAIT_CONFIG;
        drawWaitScreen();
      }
      break;
  }
  
  delay(50);
}

void showWelcome() {
  tft.fillScreen(BLACK);
  
  // Simple logo
  tft.fillCircle(CENTER_X, CENTER_Y - 15, 30, KUMBARA_BLUE);
  tft.fillRect(CENTER_X - 12, CENTER_Y - 5, 24, 12, KUMBARA_BLUE);
  tft.fillCircle(CENTER_X, CENTER_Y + 7, 8, YELLOW);
  
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", CENTER_X, CENTER_Y + 35);
  
  tft.setTextSize(1);
  tft.setTextColor(LIGHT_GRAY);
  tft.drawString("Optimized IoT", CENTER_X, CENTER_Y + 55);
  
  delay(2000);
}

void initBLE() {
  BLEDevice::init("Kumbara_Opt");
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
  
  Serial.println("🔵 BLE: Kumbara_Opt");
}

void handleBLE(String data) {
  if (data.indexOf("configure") > 0) {
    Serial.println("⚙️ WiFi config");
    
    // Simple JSON extraction
    String ssid = extractJSONValue(data, "ssid");
    String password = extractJSONValue(data, "password");
    String server = extractJSONValue(data, "server");
    String userId = extractJSONValue(data, "userId");
    
    ssid.toCharArray(wifiSSID, sizeof(wifiSSID));
    password.toCharArray(wifiPassword, sizeof(wifiPassword));
    server.toCharArray(serverURL, sizeof(serverURL));
    userId.toCharArray(userID, sizeof(userID));
    
    Serial.println("📶 SSID: " + ssid);
    Serial.println("🌐 Server: " + server);
    
    currentState = CONNECTING;
    connectWiFi();
    
  } else if (data.indexOf("update_goals") > 0) {
    Serial.println("🎯 Direct goals update");
    
    // Demo goals for direct BLE mode
    goalCount = 2;
    strcpy(goals[0].name, "PlayStation 5");
    goals[0].current = 850;
    goals[0].target = 1500;
    goals[0].color = KUMBARA_BLUE;
    
    strcpy(goals[1].name, "Bisiklet");
    goals[1].current = 420;
    goals[1].target = 800;
    goals[1].color = GREEN;
    
    currentGoal = 0;
    currentState = DISPLAY_GOALS;
    drawGoalDisplay();
  }
}

void connectWiFi() {
  Serial.println("📡 WiFi connecting: " + String(wifiSSID));
  drawState("WiFi Bağlanıyor", YELLOW);
  
  WiFi.begin(wifiSSID, wifiPassword);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi OK: " + WiFi.localIP().toString());
    drawState("WiFi Bağlandı", GREEN);
    delay(1000);
    currentState = CONNECTED;
  } else {
    Serial.println("\n❌ WiFi Failed");
    drawState("WiFi Hatası", RED);
    currentState = ERROR_STATE;
  }
}

void fetchGoals() {
  if (WiFi.status() != WL_CONNECTED) {
    currentState = ERROR_STATE;
    return;
  }
  
  currentState = FETCHING;
  drawState("Veri Çekiliyor", CYAN);
  
  HTTPClient http;
  String url = String(serverURL) + "/api/goals/user/" + String(userID);
  
  Serial.println("🌐 GET: " + url);
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String payload = http.getString();
    Serial.println("📦 Data: " + payload.substring(0, 80) + "...");
    
    parseGoalsJSON(payload);
    
    if (goalCount > 0) {
      currentState = DISPLAY_GOALS;
      currentGoal = 0;
      drawGoalDisplay();
    } else {
      drawState("Hedef Yok", ORANGE);
    }
    
  } else {
    Serial.println("❌ HTTP Error: " + String(httpCode));
    drawState("Sunucu Hatası", RED);
    currentState = ERROR_STATE;
  }
  
  http.end();
}

void parseGoalsJSON(String json) {
  // Ultra-lightweight JSON parser
  goalCount = 0;
  
  int goalsStart = json.indexOf("\"goals\":[");
  if (goalsStart < 0) return;
  
  int pos = goalsStart + 9; // Start after "goals":[
  uint16_t colors[] = {KUMBARA_BLUE, GREEN, ORANGE, PURPLE, CYAN};
  
  while (goalCount < 3 && pos < json.length()) {
    int objStart = json.indexOf('{', pos);
    if (objStart < 0) break;
    
    int objEnd = json.indexOf('}', objStart);
    if (objEnd < 0) break;
    
    String goalObj = json.substring(objStart, objEnd + 1);
    
    String name = extractJSONValue(goalObj, "name");
    if (name.length() == 0) name = extractJSONValue(goalObj, "title");
    
    String currentStr = extractJSONValue(goalObj, "currentAmount");
    String targetStr = extractJSONValue(goalObj, "targetAmount");
    
    if (name.length() > 0 && currentStr.length() > 0 && targetStr.length() > 0) {
      name.toCharArray(goals[goalCount].name, sizeof(goals[goalCount].name));
      goals[goalCount].current = currentStr.toInt();
      goals[goalCount].target = targetStr.toInt();
      goals[goalCount].color = colors[goalCount % 5];
      
      Serial.println("🎯 " + name + " (" + currentStr + "/" + targetStr + ")");
      goalCount++;
    }
    
    pos = objEnd + 1;
  }
  
  Serial.println("✅ " + String(goalCount) + " goals loaded");
}

String extractJSONValue(String json, String key) {
  String searchKey = "\"" + key + "\":";
  int keyPos = json.indexOf(searchKey);
  if (keyPos < 0) return "";
  
  int valueStart = keyPos + searchKey.length();
  
  // Skip whitespace
  while (valueStart < json.length() && json.charAt(valueStart) == ' ') {
    valueStart++;
  }
  
  if (valueStart >= json.length()) return "";
  
  char firstChar = json.charAt(valueStart);
  int valueEnd;
  
  if (firstChar == '"') {
    // String value
    valueStart++; // Skip opening quote
    valueEnd = json.indexOf('"', valueStart);
    if (valueEnd < 0) return "";
    return json.substring(valueStart, valueEnd);
  } else {
    // Number value
    valueEnd = valueStart;
    while (valueEnd < json.length()) {
      char c = json.charAt(valueEnd);
      if (c == ',' || c == '}' || c == ']' || c == ' ' || c == '\n') {
        break;
      }
      valueEnd++;
    }
    return json.substring(valueStart, valueEnd);
  }
}

void drawWaitScreen() {
  tft.fillScreen(BLACK);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("WiFi Config", CENTER_X, CENTER_Y - 10);
  tft.drawString("Bekleniyor", CENTER_X, CENTER_Y + 15);
  
  tft.setTextSize(1);
  tft.drawString("BLE: Kumbara_Opt", CENTER_X, CENTER_Y + 40);
  
  // BLE status
  tft.fillCircle(20, 15, 5, DARK_GRAY);
}

void drawState(String msg, uint16_t color) {
  // Status message at bottom
  tft.fillRect(0, 200, 240, 40, BLACK);
  tft.setTextColor(color);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(msg, CENTER_X, 220);
}

void drawGoalDisplay() {
  if (goalCount == 0) return;
  
  Goal g = goals[currentGoal];
  int progress = (g.target > 0) ? (g.current * 100) / g.target : 0;
  
  tft.fillScreen(BLACK);
  
  // Gauge base
  drawGaugeBase();
  
  // Progress arc
  drawProgressArc(progress, g.color);
  
  // Goal info
  drawGoalInfo(g, progress);
  
  // Needle
  drawNeedle(progress);
  
  // Status indicators
  drawStatus();
}

void drawGaugeBase() {
  // Outer ring
  for(int i = 0; i < 2; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, OUTER_RADIUS - i, LIGHT_GRAY);
  }
  
  // Inner ring
  tft.drawCircle(CENTER_X, CENTER_Y, INNER_RADIUS, DARK_GRAY);
  
  // Tick marks
  for(int val = 0; val <= 100; val += 25) {
    float angle = map(val, 0, 100, -135, 135);
    float rad = angle * PI / 180.0;
    
    int x1 = CENTER_X + (OUTER_RADIUS - 3) * cos(rad);
    int y1 = CENTER_Y + (OUTER_RADIUS - 3) * sin(rad);
    int x2 = CENTER_X + (OUTER_RADIUS - 12) * cos(rad);
    int y2 = CENTER_Y + (OUTER_RADIUS - 12) * sin(rad);
    
    tft.drawLine(x1, y1, x2, y2, WHITE);
    
    if (val % 50 == 0) {
      int textX = CENTER_X + (OUTER_RADIUS - 20) * cos(rad);
      int textY = CENTER_Y + (OUTER_RADIUS - 20) * sin(rad);
      
      tft.setTextColor(WHITE);
      tft.setTextSize(1);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(String(val), textX, textY);
    }
  }
  
  // Center
  tft.fillCircle(CENTER_X, CENTER_Y, 10, DARK_GRAY);
  tft.drawCircle(CENTER_X, CENTER_Y, 10, WHITE);
}

void drawProgressArc(int progress, uint16_t color) {
  float startAngle = -135.0;
  float endAngle = map(progress, 0, 100, -135, 135);
  
  for(float angle = startAngle; angle <= endAngle; angle += 3.0) {
    float rad = angle * PI / 180.0;
    
    for(int r = INNER_RADIUS + 2; r < OUTER_RADIUS - 2; r += 2) {
      int x = CENTER_X + r * cos(rad);
      int y = CENTER_Y + r * sin(rad);
      tft.drawPixel(x, y, color);
    }
  }
}

void drawGoalInfo(Goal g, int progress) {
  // Goal name
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  
  String name = String(g.name);
  if (name.length() > 12) name = name.substring(0, 12) + "..";
  tft.drawString(name, CENTER_X, 35);
  
  // Amount
  tft.setTextColor(g.color);
  tft.setTextSize(2);
  tft.drawString(String(g.current), CENTER_X, CENTER_Y - 5);
  
  tft.setTextColor(LIGHT_GRAY);
  tft.setTextSize(1);
  tft.drawString("/" + String(g.target) + " TL", CENTER_X, CENTER_Y + 15);
  
  // Percentage
  tft.setTextColor(WHITE);
  tft.setTextSize(2);
  tft.drawString("%" + String(progress), CENTER_X, 185);
  
  // Counter
  if (goalCount > 1) {
    tft.setTextColor(LIGHT_GRAY);
    tft.setTextSize(1);
    tft.drawString(String(currentGoal + 1) + "/" + String(goalCount), CENTER_X, 205);
  }
}

void drawNeedle(int progress) {
  float angle = map(progress, 0, 100, -135, 135);
  float rad = angle * PI / 180.0;
  
  int endX = CENTER_X + 70 * cos(rad);
  int endY = CENTER_Y + 70 * sin(rad);
  
  // Shadow
  tft.drawLine(CENTER_X + 1, CENTER_Y + 1, endX + 1, endY + 1, DARK_GRAY);
  
  // Main needle
  tft.drawLine(CENTER_X, CENTER_Y, endX, endY, RED);
  tft.drawLine(CENTER_X, CENTER_Y - 1, endX, endY - 1, RED);
  
  // Center dot
  tft.fillCircle(CENTER_X, CENTER_Y, 3, WHITE);
}

void drawStatus() {
  // WiFi status
  uint16_t wifiColor = (WiFi.status() == WL_CONNECTED) ? GREEN : RED;
  tft.fillCircle(220, 15, 5, wifiColor);
  
  // BLE status
  uint16_t bleColor = deviceConnected ? BLUE : DARK_GRAY;
  tft.fillCircle(20, 15, 5, bleColor);
}

void switchGoal() {
  if (goalCount <= 1) return;
  
  currentGoal = (currentGoal + 1) % goalCount;
  drawGoalDisplay();
  
  Serial.println("🔄 Goal: " + String(goals[currentGoal].name));
} 