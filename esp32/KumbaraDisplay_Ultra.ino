/*
 * 🏦 KUMBARA ESP32-C3 ULTRA MINIMAL WITH BLE CONFIG
 * Pin: MOSI=5, SCK=4, CS=3, DC=2, RST=1
 * 
 * ⚡ ULTRA OPTIMIZED - BLE Config + WiFi + HTTP
 * ✅ BLE configuration from child app
 * ✅ TFT Display
 * ✅ WiFi + HTTP  
 * ✅ Dynamic user ID and WiFi
 */

 #include <TFT_eSPI.h>
 #include <WiFi.h>
 #include <HTTPClient.h>
 #include <BLEDevice.h>
 #include <BLEServer.h>
 #include <BLEUtils.h>
 #include <BLE2902.h>
 #include <ArduinoJson.h>
 #include <Preferences.h>
 #include <ArduinoWebsockets.h> // WebSocket client
 using namespace websockets;
 
 // *** TFT_eSPI Unicode/Turkish Font Support ***
 // User_Setup.h dosyasına şunları ekle:
 // #define LOAD_GLCD   // Font 1. Original Adafruit 8 pixel font needs ~1820 bytes in FLASH
 // #define LOAD_FONT2  // Font 2. Small 16 pixel high font, needs ~3534 bytes in FLASH, 96 characters
 // #define LOAD_FONT4  // Font 4. Medium 26 pixel high font, needs ~5848 bytes in FLASH, 96 characters
 // #define LOAD_FONT6  // Font 6. Large 48 pixel high font, needs ~2666 bytes in FLASH, only characters 1234567890:-.apm
 // #define LOAD_FONT7  // Font 7. 7 segment 48 pixel high font, needs ~2438 bytes in FLASH, only characters 1234567890:.
 // #define LOAD_FONT8  // Font 8. Large 75 pixel high font needs ~3256 bytes in FLASH, only characters 1234567890:-.
 // #define LOAD_GFXFF  // FreeFonts. Include access to the 48 Adafruit_GFX free fonts FF1 to FF48 and custom fonts
 
 
 
 TFT_eSPI tft = TFT_eSPI();
 Preferences preferences;
 
 // BLE Configuration
 #define BLE_SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
 #define BLE_CONFIG_CHAR_UUID    "12345678-1234-1234-1234-123456789abd"
 #define BLE_STATUS_CHAR_UUID    "12345678-1234-1234-1234-123456789abe"
 
 BLEServer* pServer = NULL;
 BLECharacteristic* pConfigCharacteristic = NULL;
 BLECharacteristic* pStatusCharacteristic = NULL;
 bool deviceConnected = false;
 bool configReceived = false;
 
 // Config data (will be set via BLE)
 String WIFI_SSID = "";
 String WIFI_PASS = "";
 String SERVER_URL = "http://192.168.1.21:3000";
 String USER_ID = "6876b53f2c921b00d04b6b12"; // ELLE SABİTLENDİ
 String DEVICE_NAME = "e469eb41"; // HER ZAMAN SABİT
 
 // Colors
 #define BLACK 0x0000
 #define WHITE 0xFFFF
 #define RED 0xF800
 #define GREEN 0x07E0
 #define BLUE 0x001F
 #define YELLOW 0xFFE0
 #define ORANGE 0xFD20
  #define CYAN 0x07FF
 #define KUMBARA_BLUE 0x1E9F
 #define LIGHT_GRAY 0xC618
 #define DARK_GRAY 0x7BEF
 #define BROWN 0x9A60 // Added for Ayıcık icon
 
 // Goal data
 struct Goal {
   char name[32]; // Türkçe karakterler için daha fazla yer
   int current;
   int target;
   uint16_t color;
   char icon[16]; // Icon name
 };
 
 Goal goals[15]; // Max 15 hedef desteği (memory efficient)
 int goalCount = 0;
 int totalGoalCount = 0; // Toplam hedef sayısı (backend'ten)
 int currentGoal = 0;
 unsigned long lastSwitch = 0;
 unsigned long lastFetch = 0;
 bool needsDisplayUpdate = true;
 String lastStatus = "";
 int lastDisplayedGoal = -1;
 
 // --- YENİ PIN TANIMLARI ---
 #define PIN_BANKNOTE_SENSOR 7   // Para sensörü (input)
 #define PIN_SAFE_OPEN      9    // Kasa açma diyot kontrolü (output)
 #define PIN_SAFE_DOOR_SW   0    // Kasa kapağı switch (input, A0)
 
 // Function declarations
 void saveConfig();
 void loadConfig();
 void clearConfig();
 void showStatus(String title, String message, uint16_t color);
 void showStatusOnce(String title, String message, uint16_t color);
 void setupBLE();
 void drawIcon(String iconName, int x, int y, uint16_t color);
 void drawIconLarge(String iconName, int x, int y, uint16_t color);
 void drawGoalCardBigLogo(String iconName, String goalName, int percent, int currentAmount, int totalAmount, String goalCount);
 
 
 // BLE Server Callbacks
 class MyServerCallbacks: public BLEServerCallbacks {
     void onConnect(BLEServer* pServer) {
       deviceConnected = true;
       Serial.println("BLE Client connected");
     };
 
     void onDisconnect(BLEServer* pServer) {
       deviceConnected = false;
       Serial.println("BLE Client disconnected");
       // Restart advertising
       BLEDevice::startAdvertising();
     }
 };
 
 // BLE Characteristic Callbacks
 class MyConfigCallbacks: public BLECharacteristicCallbacks {
     void onWrite(BLECharacteristic* pCharacteristic) {
       String data = pCharacteristic->getValue().c_str();
       Serial.println("BLE Config received: " + data);
       
       // Parse JSON config
       DynamicJsonDocument doc(1024);
       DeserializationError error = deserializeJson(doc, data);
       
       if (!error) {
         if (doc["action"] == "configure") {
           WIFI_SSID = doc["ssid"].as<String>();
           WIFI_PASS = doc["password"].as<String>();
           SERVER_URL = doc["server"].as<String>();
           USER_ID = doc["userId"].as<String>();
           DEVICE_NAME = doc["deviceName"].as<String>();
           
           Serial.println("Config parsed successfully:");
           Serial.println("SSID: " + WIFI_SSID);
           Serial.println("Server: " + SERVER_URL);
           Serial.println("User ID: " + USER_ID);
           
           configReceived = true;
           
           // Save config to persistent storage
           saveConfig();
           
           // Send status back
           pStatusCharacteristic->setValue("CONFIG_OK");
           pStatusCharacteristic->notify();
         }
       } else {
         Serial.println("JSON parse error");
         pStatusCharacteristic->setValue("CONFIG_ERROR");
         pStatusCharacteristic->notify();
       }
     }
 };
 
 WebsocketsClient wsClient;
 bool wsConnected = false;

 void onWebSocketMessageCallback(WebsocketsMessage message) {
   Serial.print("[WS] Mesaj alındı: ");
   Serial.println(message.data());
   // Unlock komutu kontrolü
   if (message.data() == "unlock") {
     Serial.println("[WS] UNLOCK KOMUTU ALGILANDI!");
     digitalWrite(PIN_SAFE_OPEN, LOW);
     drawSafeOpeningScreen();
     delay(5000);
     digitalWrite(PIN_SAFE_OPEN, HIGH);
     needsDisplayUpdate = true;
     Serial.println("[WS] Unlock işlemi tamamlandı, pin HIGH.");
   }
 }

 void connectWebSocket() {
   String wsUrl = SERVER_URL;
   wsUrl.replace("http://", "ws://");
   wsUrl += "/unlock/" + DEVICE_NAME;
   Serial.print("[WS] Bağlanıyor: ");
   Serial.println(wsUrl);
   wsClient.onMessage(onWebSocketMessageCallback);
   wsConnected = wsClient.connect(wsUrl.c_str());
   if (wsConnected) {
     Serial.println("[WS] Saf WebSocket bağlantısı başarılı!");
   } else {
     Serial.println("[WS] WebSocket bağlantısı başarısız!");
   }
 }
 
 void setup() {
   Serial.begin(115200);
   delay(1000);
   
   // UTF-8 encoding desteği
   Serial.println("🏦 KUMBARA ESP32-C3 Starting...");
   Serial.print("Sabit USER_ID: "); Serial.println(USER_ID);
   
   // Initialize TFT with UTF-8 support
   tft.init();
   tft.setRotation(0);
   tft.setTextDatum(MC_DATUM); // Text ortalama için
   tft.setTextWrap(false, false); // Text wrap kapalı
   tft.setTextFont(2); // Font 2 - UTF-8 support
   tft.setTextColor(WHITE);
   
   // UTF-8 encoding support
   tft.setTextPadding(0);
   
   tft.fillScreen(BLACK);
   
   // Show startup message with Turkish characters
   showStatus("Konfigürasyon", "Bağlantı bekleniyor...", YELLOW);
   
   // Load saved config from memory
   loadConfig();
   
   // Initialize BLE
   setupBLE();
   
   pinMode(PIN_BANKNOTE_SENSOR, INPUT_PULLUP); // Para sensörü
   pinMode(PIN_SAFE_OPEN, OUTPUT);             // Kasa açma
   digitalWrite(PIN_SAFE_OPEN, HIGH);          // Normalde HIGH (açık devre)
   pinMode(PIN_SAFE_DOOR_SW, INPUT_PULLUP);    // Kasa kapağı switch
   
   Serial.println("Setup complete, waiting for BLE config...");
   // WiFi bağlantısı sonrası WebSocket'e bağlan
   if (WiFi.status() == WL_CONNECTED) {
     connectWebSocket();
   }
 }
 
 void setupBLE() {
   Serial.println("Setting up BLE...");
   
   BLEDevice::init("Kumbara-ESP32");
   pServer = BLEDevice::createServer();
   pServer->setCallbacks(new MyServerCallbacks());
 
   BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
 
   // Config characteristic
   pConfigCharacteristic = pService->createCharacteristic(
                       BLE_CONFIG_CHAR_UUID,
                       BLECharacteristic::PROPERTY_READ |
                       BLECharacteristic::PROPERTY_WRITE
                     );
   pConfigCharacteristic->setCallbacks(new MyConfigCallbacks());
 
   // Status characteristic
   pStatusCharacteristic = pService->createCharacteristic(
                       BLE_STATUS_CHAR_UUID,
                       BLECharacteristic::PROPERTY_READ |
                       BLECharacteristic::PROPERTY_NOTIFY
                     );
   pStatusCharacteristic->addDescriptor(new BLE2902());
 
   pService->start();
 
   BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
   pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
   pAdvertising->setScanResponse(false);
   pAdvertising->setMinPreferred(0x0);
   BLEDevice::startAdvertising();
   
   Serial.println("BLE advertising started");
 }
 
 // --- POLLING FONKSİYONUNU TAMAMEN KALDIRIYORUM ---
// void checkUnlockCommand() { /* kaldırıldı */ }

void loop() {
  // WebSocket bağlantısı varsa mesajları dinle
  if (wsConnected) {
    wsClient.poll();
  }

  // Eğer unlock ekranı aktifse başka hiçbir şey çizme
  static bool unlockActive = false;
  if (digitalRead(PIN_SAFE_OPEN) == LOW) {
    unlockActive = true;
  } else if (unlockActive) {
    unlockActive = false;
  }
  if (unlockActive) {
    delay(100);
    return;
  }

   // Wait for BLE configuration
   if (!configReceived) {
     static unsigned long lastBlink = 0;
     static String lastMsg = "";
     String currentMsg = deviceConnected ? "Bağlandı" : "Bekleniyor...";
     
     if (millis() - lastBlink > 1000 || lastMsg != currentMsg) {
       showStatusOnce("Config", currentMsg, deviceConnected ? BLUE : YELLOW);
       lastMsg = currentMsg;
       lastBlink = millis();
     }
     delay(100);
     return;
   }
   
   // Try WiFi connection
   if (WiFi.status() != WL_CONNECTED) {
     if (WIFI_SSID.length() > 0) {
       connectWiFi();
     }
     delay(1000);
     return;
   }
   
   // Update goals from server
   if (millis() - lastFetch > 30000) { // 30 seconds
     fetchGoals();
     lastFetch = millis();
   }
   
   // Check if goal needs switching
   bool goalSwitched = false;
   if (goalCount > 1 && millis() - lastSwitch > 5000) {
     currentGoal = (currentGoal + 1) % goalCount;
     lastSwitch = millis();
     goalSwitched = true;
   }
   
   // Display goals only when needed
   if (goalCount > 0) {
     if (needsDisplayUpdate || goalSwitched || lastDisplayedGoal != currentGoal) {
       displayGoal();
       lastDisplayedGoal = currentGoal;
       needsDisplayUpdate = false;
     }
   } else {
     static bool noGoalsShown = false;
     if (!noGoalsShown) {
       showStatusOnce("Hedef Yok", "Uygulama ile hedef oluşturunuz", WHITE);
       noGoalsShown = true;
     }
   }
   
   // --- PARA SENSÖRÜ ---
   static unsigned long lastBanknote = 0;
   if (digitalRead(PIN_BANKNOTE_SENSOR) == LOW && millis() - lastBanknote > 1000) {
     drawBanknoteScreen();
     delay(1500);
     lastBanknote = millis();
     needsDisplayUpdate = true;
   }

   // --- KASA KAPAĞI SWITCH ---
   static unsigned long lastDoorOpen = 0;
   if (digitalRead(PIN_SAFE_DOOR_SW) == LOW && millis() - lastDoorOpen > 1000) {
     drawSafeDoorOpenScreen();
     delay(1000);
     lastDoorOpen = millis();
     needsDisplayUpdate = true;
   }
   
   delay(100);
}
 
 void connectWiFi() {
   showStatusOnce("WiFi", "Baglanıyor...", BLUE);
   
   WiFi.begin(WIFI_SSID.c_str(), WIFI_PASS.c_str());
   
   int attempts = 0;
   while (WiFi.status() != WL_CONNECTED && attempts < 20) {
     delay(500);
     attempts++;
     Serial.print(".");
   }
   
   if (WiFi.status() == WL_CONNECTED) {
     showStatusOnce("WiFi", "Bağlandı!", GREEN);
     Serial.println("\nWiFi connected!");
     Serial.println("IP: " + WiFi.localIP().toString());
     needsDisplayUpdate = true; // Ready to show goals
     
     // Send WiFi status via BLE
     if (deviceConnected) {
       pStatusCharacteristic->setValue("WIFI_CONNECTED");
       pStatusCharacteristic->notify();
     }
     // --- WebSocket bağlantısını burada kur ---
     connectWebSocket();
   } else {
     showStatusOnce("WiFi", "Hata!", RED);
     Serial.println("\nWiFi connection failed!");
     
     if (deviceConnected) {
       pStatusCharacteristic->setValue("WIFI_ERROR");
       pStatusCharacteristic->notify();
     }
   }
 }
 
 void fetchGoals() {
   if (USER_ID.length() == 0) {
     Serial.println("No user ID configured");
     return;
   }
   
   showStatusOnce("Sunucu", "Bağlanıyor...", BLUE);
   
   HTTPClient http;
   String url = SERVER_URL + "/api/esp32/goals/user/" + USER_ID;
   
   http.begin(url);
   http.setTimeout(10000);
   
   int httpCode = http.GET();
   
   if (httpCode == 200) {
     String response = http.getString();
     Serial.println("API Response: " + response);
     
          if (parseGoalsJSON(response)) {
        showStatusOnce("Sunucu", "Başarılı!", GREEN);
        needsDisplayUpdate = true; // Trigger display update
        
        if (deviceConnected) {
          pStatusCharacteristic->setValue("DATA_OK");
          pStatusCharacteristic->notify();
        }
      } else {
        showStatusOnce("Sunucu", "Parse Error", RED);
      }
   } else {
     showStatus("Sunucu", "Hata!", RED);
     Serial.println("HTTP Error: " + String(httpCode));
     
     if (deviceConnected) {
       pStatusCharacteristic->setValue("SERVER_ERROR");
       pStatusCharacteristic->notify();
     }
   }
   
   http.end();
 }
 
 bool parseGoalsJSON(String json) {
   DynamicJsonDocument doc(5120); // Daha da büyük buffer (15 goal için)
   DeserializationError error = deserializeJson(doc, json);
   
   if (error) {
     Serial.println("JSON parse error: " + String(error.c_str()));
     return false;
   }
   
   if (!doc["success"]) {
     Serial.println("API returned error");
     return false;
   }
   
   JsonArray goalsArray = doc["goals"];
   goalCount = min((int)goalsArray.size(), 15); // 15 goal limit
   totalGoalCount = doc["totalCount"] | goalCount; // Backend'ten total count
   
   uint16_t colors[] = {GREEN, BLUE, YELLOW, ORANGE, RED, KUMBARA_BLUE, WHITE, 
                       0xF81F, 0x07FF, 0xFFE0, 0xFD20, 0x8410, 0xA514, 0xFC00, 0x8000};
   
   for (int i = 0; i < goalCount; i++) {
     JsonObject goal = goalsArray[i];
     
     String name = goal["name"];
     // UTF-8 string'i direkt copy et, daha fazla alan var
     strncpy(goals[i].name, name.c_str(), 31);
     goals[i].name[31] = '\0';
     
     goals[i].current = goal["current"];
     goals[i].target = goal["target"];
     goals[i].color = colors[i % 15]; // 15 farklı renk
     
     // Icon parse et
     String icon = goal["icon"] | "default";
     strncpy(goals[i].icon, icon.c_str(), 15);
     goals[i].icon[15] = '\0';
     
     Serial.println("Goal " + String(i) + ": " + String(goals[i].name) + " | Icon: " + String(goals[i].icon));
   }
   
   Serial.println("Parsed " + String(goalCount) + "/" + String(totalGoalCount) + " goals");
   return true;
 }
 
 void displayGoal() {
   if (goalCount == 0) return;
 
   Goal& goal = goals[currentGoal];
   int percent = (goal.target > 0) ? (goal.current * 100) / goal.target : 0;
   String goalCountStr = "Hedef " + String(currentGoal + 1) + "/" + String(totalGoalCount);
 
   tft.fillScreen(BLACK);
 
   // BÜYÜK LOGO ve yeni sıralama ile çiz
   drawGoalCardBigLogo(
     String(goal.icon),         // iconName
     String(goal.name),         // goalName
     percent,                   // percent
     goal.current,              // currentAmount
     goal.target,               // totalAmount
     goalCountStr               // goalCount
   );
 }
 
 void showStatus(String title, String message, uint16_t color) {
   tft.fillScreen(BLACK);
   tft.setTextColor(color, BLACK);
   tft.setTextSize(2); // Makul boyut
   
   // Title - Türkçe karakterleri dönüştür
   title.replace("ğ", "g");
   title.replace("Ğ", "G");
   title.replace("ü", "u");
   title.replace("Ü", "U");
   title.replace("ş", "s");
   title.replace("Ş", "S");
   title.replace("ı", "i");
   title.replace("İ", "I");
   title.replace("ö", "o");
   title.replace("Ö", "O");
   title.replace("ç", "c");
   title.replace("Ç", "C");
   
   tft.setTextDatum(MC_DATUM);
   tft.drawString(title, 120, 100);
   
   // Message - Türkçe karakterleri dönüştür
   message.replace("ğ", "g");
   message.replace("Ğ", "G");
   message.replace("ü", "u");
   message.replace("Ü", "U");
   message.replace("ş", "s");
   message.replace("Ş", "S");
   message.replace("ı", "i");
   message.replace("İ", "I");
   message.replace("ö", "o");
   message.replace("Ö", "O");
   message.replace("ç", "c");
   message.replace("Ç", "C");
   
   tft.setTextSize(1); // Normal boyut
   tft.setTextDatum(MC_DATUM);
   tft.drawString(message, 120, 130);
 }
 
 void showStatusOnce(String title, String message, uint16_t color) {
   String newStatus = title + ":" + message;
   if (lastStatus != newStatus) {
     showStatus(title, message, color);
     lastStatus = newStatus;
   }
 }
 
 void drawCircle(int x, int y, int r, uint16_t color) {
   for (int i = 0; i < 360; i += 5) {
     float rad = i * PI / 180;
     int x1 = x + cos(rad) * r;
     int y1 = y + sin(rad) * r;
     tft.drawPixel(x1, y1, color);
   }
 }
 
 void drawProgressArc(int x, int y, int r, float progress, uint16_t color) {
   int maxAngle = progress * 360;
   for (int i = 0; i < maxAngle; i += 2) {
     float rad = (i - 90) * PI / 180; // Start from top
     int x1 = x + cos(rad) * r;
     int y1 = y + sin(rad) * r;
     tft.drawPixel(x1, y1, color);
   }
 }
 
 // Yatay progress bar çizimi
 void drawProgressBar(int x, int y, int width, int height, int percent, uint16_t color, uint16_t bgColor) {
   // Arka plan (boş bar)
   tft.fillRoundRect(x, y, width, height, height/2, bgColor);
   // Dolu kısım
   int filled = (width * percent) / 100;
   tft.fillRoundRect(x, y, filled, height, height/2, color);
   // Kenarlık
   tft.drawRoundRect(x, y, width, height, height/2, WHITE);
 }
 
 
 // Load config from persistent storage
 void loadConfig() {
   Serial.println("Loading config from memory...");
   
   preferences.begin("kumbara", false);
   
   WIFI_SSID = preferences.getString("wifi_ssid", "");
   WIFI_PASS = preferences.getString("wifi_pass", "");
   SERVER_URL = preferences.getString("server_url", "http://192.168.1.21:3000");
   USER_ID = preferences.getString("user_id", "");
   // DEVICE_NAME = preferences.getString("device_name", "e469eb41"); // ARTIK DEĞİŞMEYECEK
   
   preferences.end();
   
   if (WIFI_SSID.length() > 0 && USER_ID.length() > 0) {
     Serial.println("Config loaded from memory:");
     Serial.println("SSID: " + WIFI_SSID);
     Serial.println("User ID: " + USER_ID);
     Serial.println("Device: " + DEVICE_NAME);
     configReceived = true;
     showStatusOnce("Ayarlar", "Yuklendy!", GREEN);
     delay(1000);
   } else {
     Serial.println("No saved config found");
     showStatusOnce("Config", "Bekleniyor...", YELLOW);
   }
 }
 
 // Save config to persistent storage
 void saveConfig() {
   Serial.println("Saving config to memory...");
   
   preferences.begin("kumbara", false);
   
   preferences.putString("wifi_ssid", WIFI_SSID);
   preferences.putString("wifi_pass", WIFI_PASS);
   preferences.putString("server_url", SERVER_URL);
   preferences.putString("user_id", USER_ID);
   preferences.putString("device_name", DEVICE_NAME);
   
   preferences.end();
   
   Serial.println("Config saved successfully!");
   showStatusOnce("Ayarlar", "Kaydedildi!", GREEN);
   delay(1000);
 }
 
 // Clear saved config (for factory reset)
 void clearConfig() {
   Serial.println("Clearing saved config...");
   
   preferences.begin("kumbara", false);
   preferences.clear();
   preferences.end();
   
   WIFI_SSID = "";
   WIFI_PASS = "";
   USER_ID = "";
   configReceived = false;
   
   Serial.println("Config cleared!");
   showStatusOnce("Reset", "Tamamlandi!", YELLOW);
   delay(1000);
 }
 
 // Icon çizim fonksiyonu - Tüm popüler iconlar
 void drawIcon(String iconName, int x, int y, uint16_t color) {
   y += 20; // 20 piksel aşağı kaydır (daha fazla boşluk için)
 
   // TOY
   if (iconName == "toy" || iconName == "oyuncak" || iconName == "🧸") {
     tft.fillCircle(x+10, y+10, 8, ORANGE); // Kafa
     tft.fillCircle(x+3, y+4, 3, ORANGE);   // Sol kulak
     tft.fillCircle(x+17, y+4, 3, ORANGE);  // Sağ kulak
     tft.fillCircle(x+7, y+12, 2, WHITE);   // Sol göz beyazı
     tft.fillCircle(x+13, y+12, 2, WHITE);  // Sağ göz beyazı
     tft.fillCircle(x+7, y+12, 1, BLACK);   // Sol göz
     tft.fillCircle(x+13, y+12, 1, BLACK);  // Sağ göz
     tft.fillCircle(x+10, y+15, 1, BROWN);  // Burun
     tft.drawLine(x+9, y+17, x+11, y+17, BLACK); // Ağız
   }
   // BOOK
   else if (iconName == "book" || iconName == "kitap" || iconName == "education" || iconName == "📚" || iconName == "books") {
     tft.fillRect(x+2, y+8, 8, 12, 0x1976D2);      // Sol kapak (mavi)
     tft.fillRect(x+14, y+8, 8, 12, 0x43A047);     // Sağ kapak (yeşil)
     tft.fillRect(x+7, y+10, 10, 10, WHITE);        // İç sayfa
     tft.drawLine(x+12, y+8, x+12, y+20, 0x795548); // Kahverengi cilt
     tft.drawLine(x+9, y+12, x+15, y+12, LIGHT_GRAY); // Üst çizgi
     tft.drawLine(x+9, y+16, x+15, y+16, LIGHT_GRAY); // Alt çizgi
   }
   // ELECTRONICS
   else if (iconName == "electronics" || iconName == "elektronik" || iconName == "phone" || iconName == "📱" || iconName == "💻" || iconName == "laptop") {
     tft.fillRect(x+4, y+8, 12, 8, color);          // Laptop gövde
     tft.fillRect(x+5, y+9, 10, 5, BLACK);          // Ekran
     tft.fillRect(x+6, y+14, 8, 2, LIGHT_GRAY);     // Klavye
   }
   // SPORTS
   else if (iconName == "sports" || iconName == "sport" || iconName == "spor" || iconName == "⚽" || iconName == "ball") {
     tft.fillCircle(x+10, y+10, 8, WHITE);           // Top
     tft.drawLine(x+2, y+10, x+18, y+10, BLACK);     // Orta çizgi
     tft.drawCircle(x+10, y+10, 5, BLACK);           // İç daire
   }
   // CLOTHES
   else if (iconName == "clothes" || iconName == "kiyafet" || iconName == "shirt" || iconName == "👕") {
     tft.fillRect(x+7, y+6, 6, 12, color);           // Gövde
     tft.fillRect(x+4, y+8, 3, 6, color);            // Sol kol
     tft.fillRect(x+13, y+8, 3, 6, color);           // Sağ kol
     tft.fillRect(x+8, y+4, 4, 4, color);            // Yaka
   }
   // GAMES
   else if (iconName == "games" || iconName == "game" || iconName == "oyun" || iconName == "gamepad" || iconName == "🎮" || iconName == "game_controller" || iconName == "controller" || iconName == "joystick") {
     tft.fillRoundRect(x+4, y+8, 16, 10, 4, 0x424242); // Gri gövde
     tft.fillCircle(x+6, y+18, 4, 0x212121); // Sol kol
     tft.fillCircle(x+18, y+18, 4, 0x212121); // Sağ kol
     tft.fillRect(x+8, y+12, 2, 4, 0xBDBDBD); // Dikey
     tft.fillRect(x+7, y+13, 4, 2, 0xBDBDBD); // Yatay
     tft.fillCircle(x+16, y+13, 1, RED);
     tft.fillCircle(x+19, y+13, 1, YELLOW);
     tft.fillCircle(x+16, y+16, 1, GREEN);
     tft.fillCircle(x+19, y+16, 1, BLUE);
   }
   // ART
   else if (iconName == "art" || iconName == "sanat" || iconName == "🎨") {
     tft.fillCircle(x+10, y+10, 8, 0xFFE0); // Palet
     tft.fillCircle(x+15, y+8, 2, RED);
     tft.fillCircle(x+7, y+13, 2, BLUE);
     tft.fillCircle(x+13, y+15, 2, GREEN);
     tft.fillCircle(x+5, y+8, 2, ORANGE);
   }
   // MUSIC
   else if (iconName == "music" || iconName == "muzik" || iconName == "müzik" || iconName == "🎵") {
     tft.drawLine(x+8, y+4, x+8, y+16, WHITE); // Kalın sap
     tft.drawLine(x+9, y+4, x+9, y+16, WHITE); // Kalınlaştır
     tft.drawLine(x+14, y+6, x+14, y+14, WHITE);
     tft.drawLine(x+15, y+6, x+15, y+14, WHITE);
     tft.fillCircle(x+8, y+16, 3, WHITE); // Büyük baş
     tft.fillCircle(x+14, y+14, 2, WHITE); // Küçük baş
     tft.fillCircle(x+8, y+16, 3, DARK_GRAY);
     tft.fillCircle(x+14, y+14, 2, DARK_GRAY);
     tft.fillCircle(x+8, y+16, 2, WHITE);
     tft.fillCircle(x+14, y+14, 1, WHITE);
     tft.drawLine(x+8, y+7, x+14, y+9, WHITE);
   }
   // FOOD
   else if (iconName == "food" || iconName == "yemek" || iconName == "🍕") {
     tft.fillTriangle(x+10, y+6, x+2, y+18, x+18, y+18, 0xFFE0); // Sarımsı taban
     tft.fillCircle(x+10, y+6, 4, BROWN); // Kalın kenar
     tft.drawTriangle(x+10, y+6, x+2, y+18, x+18, y+18, BROWN); // Kenar çizgisi
     tft.fillCircle(x+10, y+12, 2, RED);    // Sucuk
     tft.fillCircle(x+6, y+15, 1, GREEN);  // Biber
     tft.fillCircle(x+14, y+16, 1, YELLOW); // Mısır
     tft.fillCircle(x+12, y+14, 1, RED);    // Sucuk
     tft.fillCircle(x+8, y+15, 1, YELLOW); // Mısır
     tft.fillCircle(x+16, y+17, 1, WHITE);  // Peynir
   }
   // MONEY
   else if (iconName == "money" || iconName == "para" || iconName == "coin" || iconName == "💰") {
     tft.fillCircle(x+10, y+10, 8, YELLOW); // Para
     tft.drawCircle(x+10, y+10, 8, ORANGE); // Kenar
     tft.setTextColor(BLACK);
     tft.setTextSize(1);
     tft.setCursor(x+6, y+8);
     tft.print("₺");
   }
   // HOUSE
   else if (iconName == "house" || iconName == "ev" || iconName == "🏠") {
     tft.fillTriangle(x+10, y+2, x+2, y+10, x+18, y+10, color); // Çatı
     tft.fillRect(x+4, y+10, 12, 8, color);                     // Gövde
     tft.fillRect(x+8, y+14, 4, 4, BLACK);                      // Kapı
     tft.fillRect(x+6, y+12, 2, 2, BLACK);                      // Sol cam
     tft.fillRect(x+12, y+12, 2, 2, BLACK);                     // Sağ cam
   }
   // CAR
   else if (iconName == "car" || iconName == "araba" || iconName == "🚗") {
     tft.fillRect(x+2, y+7, 14, 5, color);           // Gövde
     tft.fillRect(x+5, y+4, 8, 3, color);            // Üst
     tft.fillCircle(x+4, y+14, 1, WHITE);            // Sol tekerlek
     tft.fillCircle(x+14, y+14, 1, WHITE);           // Sağ tekerlek
     tft.fillRect(x+7, y+5, 2, 2, BLACK);            // Cam
     tft.fillRect(x+11, y+5, 2, 2, BLACK);           // Cam
   }
   // TRAVEL
   else if (iconName == "travel" || iconName == "tatil" || iconName == "plane" || iconName == "✈️") {
     tft.fillRect(x+8, y+6, 8, 2, color);            // Gövde
     tft.fillRect(x+12, y+8, 4, 1, color);           // Kuyruk
     tft.fillRect(x+4, y+5, 6, 4, color);            // Kanat
     tft.fillRect(x+2, y+12, 4, 2, color);           // Alt kanat
   }
   // DEFAULT/OTHER
   else if (iconName == "other" || iconName == "diger" || iconName == "diğer" || iconName == "default" || iconName == "⭐") {
     tft.fillTriangle(x+10, y+2, x+6, y+8, x+14, y+8, color);    // Üst
     tft.fillTriangle(x+10, y+18, x+6, y+12, x+14, y+12, color); // Alt
     tft.fillTriangle(x+2, y+10, x+8, y+6, x+8, y+14, color);    // Sol
     tft.fillTriangle(x+18, y+10, x+12, y+6, x+12, y+14, color); // Sağ
   } else {
     tft.setTextColor(RED, BLACK);
     tft.setTextSize(3);
     tft.setCursor(x+7, y+7);
     tft.print("?");
   }
 }
 
 // Hedef adı çizimini aşağıya al
 void drawGoalName(String name, int x, int y) {
   y += 10; // 10 piksel daha aşağıda başlasın
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(2);
   tft.setCursor(x, y);
   tft.print(name);
 }
 
 // Yeni: Hedef kartı çizimi
 void drawGoalCard(String iconName, String goalName, String goalCount, int progress, int amount, int x, int y) {
   // 1. En üstte büyük logo
   drawIconLarge(iconName, x + 20, y, WHITE); // 2x büyük, en üstte
 
   // 2. Hedef adı (logo altı)
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(2);
   tft.setCursor(x, y + 48); // Logo altı (logo yüksekliği 40px)
   tft.print(goalName);
 
   // 3. Hedef sayısı (hedef adı altı)
   tft.setTextSize(1);
   tft.setCursor(x, y + 68);
   tft.print(goalCount); // "Hedef 1/2" gibi
 
   // 4. Progress bar (daha aşağıda)
   drawProgressBar(x, y + 80, 80, 12, progress, 0x43A047, 0xBDBDBD);
 
   // 5. Tutar (en altta)
   tft.setTextSize(2);
   tft.setCursor(x, y + 100);
   tft.print(amount);
   tft.print(" ₺");
 }
 
 // 2x büyük icon çizimi
 void drawIconLarge(String iconName, int x, int y, uint16_t color) {
   // TOY
   if (iconName == "toy" || iconName == "oyuncak" || iconName == "🧸") {
     // Kafa
     tft.fillCircle(x+40, y+40, 28, ORANGE); // Kafa
     tft.fillCircle(x+20, y+25, 10, ORANGE); // Sol kulak
     tft.fillCircle(x+60, y+25, 10, ORANGE); // Sağ kulak
     // Gözler
     tft.fillCircle(x+32, y+45, 4, WHITE);   // Sol göz beyazı
     tft.fillCircle(x+48, y+45, 4, WHITE);   // Sağ göz beyazı
     tft.fillCircle(x+32, y+45, 2, BLACK);   // Sol göz
     tft.fillCircle(x+48, y+45, 2, BLACK);   // Sağ göz
     // Burun
     tft.fillCircle(x+40, y+55, 4, BROWN);   // Burun
     // Ağız
     tft.drawLine(x+38, y+60, x+42, y+60, BLACK);
     tft.drawLine(x+38, y+60, x+36, y+62, BLACK);
     tft.drawLine(x+42, y+60, x+44, y+62, BLACK);
   }
   // BOOK
   else if (iconName == "book" || iconName == "kitap" || iconName == "education" || iconName == "📚" || iconName == "books") {
     tft.fillRect(x+6, y+16, 22, 48, 0x1976D2);      // Sol kapak (mavi)
     tft.fillRect(x+38, y+16, 22, 48, 0x43A047);     // Sağ kapak (yeşil)
     tft.fillRect(x+20, y+22, 28, 36, WHITE);        // İç sayfa
     tft.drawLine(x+34, y+16, x+34, y+64, 0x795548); // Kahverengi cilt
     tft.drawLine(x+24, y+28, x+44, y+28, LIGHT_GRAY); // Üst çizgi
     tft.drawLine(x+24, y+54, x+44, y+54, LIGHT_GRAY); // Alt çizgi
   }
   // ELECTRONICS
   else if (iconName == "electronics" || iconName == "elektronik" || iconName == "phone" || iconName == "📱" || iconName == "💻" || iconName == "laptop") {
     tft.fillRect(x+20, y+30, 40, 28, color);         // Laptop gövde
     tft.fillRect(x+24, y+34, 32, 16, BLACK);         // Ekran
     tft.fillRect(x+28, y+52, 24, 4, LIGHT_GRAY);     // Klavye
   }
   // SPORTS
   else if (iconName == "sports" || iconName == "sport" || iconName == "spor" || iconName == "⚽" || iconName == "ball") {
     tft.fillCircle(x+40, y+40, 24, WHITE);           // Top
     tft.drawLine(x+16, y+40, x+64, y+40, BLACK);     // Orta çizgi
     tft.drawCircle(x+40, y+40, 12, BLACK);           // İç daire
   }
   // CLOTHES
   else if (iconName == "clothes" || iconName == "kiyafet" || iconName == "shirt" || iconName == "👕") {
     tft.fillRect(x+30, y+30, 20, 32, color);         // Gövde
     tft.fillRect(x+20, y+36, 10, 12, color);         // Sol kol
     tft.fillRect(x+50, y+36, 10, 12, color);         // Sağ kol
     tft.fillRect(x+34, y+24, 12, 8, color);          // Yaka
   }
   // GAMES
   else if (iconName == "games" || iconName == "game" || iconName == "oyun" || iconName == "gamepad" || iconName == "🎮" || iconName == "game_controller" || iconName == "controller" || iconName == "joystick") {
     tft.fillRoundRect(x+14, y+24, 52, 32, 12, 0x424242); // Gri gövde
     tft.fillCircle(x+22, y+56, 12, 0x212121); // Sol kol
     tft.fillCircle(x+58, y+56, 12, 0x212121); // Sağ kol
     tft.fillRect(x+30, y+38, 6, 12, 0xBDBDBD); // Dikey D-pad
     tft.fillRect(x+26, y+42, 12, 6, 0xBDBDBD); // Yatay D-pad
     tft.fillCircle(x+50, y+38, 3, RED);
     tft.fillCircle(x+66, y+38, 3, YELLOW);
     tft.fillCircle(x+50, y+50, 3, GREEN);
     tft.fillCircle(x+66, y+50, 3, BLUE);
   }
   // ART
   else if (iconName == "art" || iconName == "sanat" || iconName == "🎨") {
     tft.fillCircle(x+40, y+40, 20, 0xFFE0); // Palet
     tft.fillCircle(x+50, y+35, 3, RED);
     tft.fillCircle(x+35, y+45, 3, BLUE);
     tft.fillCircle(x+45, y+50, 3, GREEN);
     tft.fillCircle(x+30, y+35, 3, ORANGE);
   }
   // MUSIC
   else if (iconName == "music" || iconName == "muzik" || iconName == "müzik" || iconName == "🎵") {
     // Çift nota, kalın sap, gölge
     tft.drawLine(x+32, y+30, x+32, y+60, WHITE); // Kalın sap
     tft.drawLine(x+33, y+30, x+33, y+60, WHITE); // Kalınlaştır
     tft.drawLine(x+48, y+36, x+48, y+56, WHITE);
     tft.drawLine(x+49, y+36, x+49, y+56, WHITE);
     tft.fillCircle(x+32, y+60, 7, WHITE); // Büyük baş
     tft.fillCircle(x+48, y+56, 6, WHITE); // Küçük baş
     tft.fillCircle(x+32, y+60, 7, DARK_GRAY);
     tft.fillCircle(x+48, y+56, 6, DARK_GRAY);
     tft.fillCircle(x+32, y+60, 5, WHITE);
     tft.fillCircle(x+48, y+56, 4, WHITE);
     tft.drawLine(x+32, y+35, x+48, y+41, WHITE);
   }
   // FOOD
   else if (iconName == "food" || iconName == "yemek" || iconName == "🍕") {
     tft.fillTriangle(x+40, y+32, x+24, y+72, x+56, y+72, 0xFFE0); // Sarımsı taban
     tft.fillCircle(x+40, y+32, 10, BROWN); // Kalın kenar
     tft.drawTriangle(x+40, y+32, x+24, y+72, x+56, y+72, BROWN); // Kenar çizgisi
     tft.fillCircle(x+40, y+50, 5, RED);    // Sucuk
     tft.fillCircle(x+34, y+60, 4, GREEN);  // Biber
     tft.fillCircle(x+46, y+62, 3, YELLOW); // Mısır
     tft.fillCircle(x+48, y+56, 3, RED);    // Sucuk
     tft.fillCircle(x+36, y+58, 3, YELLOW); // Mısır
     tft.fillCircle(x+44, y+66, 2, WHITE);  // Peynir
     tft.fillCircle(x+30, y+68, 2, RED);    // Sucuk
     tft.fillCircle(x+52, y+68, 2, GREEN);  // Biber
     tft.fillTriangle(x+40, y+72, x+24, y+72, x+56, y+72, DARK_GRAY);
   }
   // MONEY
   else if (iconName == "money" || iconName == "para" || iconName == "coin" || iconName == "💰") {
     tft.fillCircle(x+40, y+40, 28, YELLOW); // Para
     tft.drawCircle(x+40, y+40, 28, ORANGE); // Kenar
     tft.setTextColor(BLACK);
     tft.setTextSize(3);
     tft.setCursor(x+28, y+32);
     tft.print("₺");
   }
   // HOUSE
   else if (iconName == "house" || iconName == "ev" || iconName == "🏠") {
     tft.fillTriangle(x+40, y+20, x+20, y+50, x+60, y+50, color); // Çatı
     tft.fillRect(x+25, y+50, 30, 30, color);                     // Gövde
     tft.fillRect(x+38, y+65, 4, 15, BLACK);                      // Kapı
     tft.fillRect(x+28, y+55, 6, 6, BLACK);                       // Sol cam
     tft.fillRect(x+46, y+55, 6, 6, BLACK);                       // Sağ cam
   }
   // CAR
   else if (iconName == "car" || iconName == "araba" || iconName == "🚗") {
     tft.fillRect(x+20, y+60, 40, 16, color);           // Gövde
     tft.fillRect(x+28, y+52, 24, 12, color);           // Üst
     tft.fillCircle(x+28, y+76, 6, BLACK);              // Sol tekerlek
     tft.fillCircle(x+52, y+76, 6, BLACK);              // Sağ tekerlek
     tft.fillRect(x+36, y+56, 8, 6, WHITE);             // Cam
     tft.fillRect(x+44, y+56, 8, 6, WHITE);             // Cam
   }
   // TRAVEL
   else if (iconName == "travel" || iconName == "tatil" || iconName == "plane" || iconName == "✈️") {
     tft.fillRect(x+36, y+40, 28, 6, color);            // Gövde
     tft.fillRect(x+58, y+44, 8, 2, color);             // Kuyruk
     tft.fillRect(x+24, y+38, 16, 8, color);            // Kanat
     tft.fillRect(x+16, y+60, 16, 4, color);            // Alt kanat
   }
   // DEFAULT/OTHER
   else if (iconName == "other" || iconName == "diger" || iconName == "diğer" || iconName == "default" || iconName == "⭐") {
     // Yıldız
     tft.fillTriangle(x+40, y+20, x+30, y+60, x+50, y+60, color);    // Üst
     tft.fillTriangle(x+40, y+80, x+30, y+40, x+50, y+40, color);    // Alt
     tft.fillTriangle(x+20, y+40, x+36, y+32, x+36, y+48, color);    // Sol
     tft.fillTriangle(x+60, y+40, x+44, y+32, x+44, y+48, color);    // Sağ
   } else {
     tft.setTextColor(RED, BLACK);
     tft.setTextSize(5);
     tft.setCursor(x+28, y+28);
     tft.print("?");
   }
 }
 
 // Aynı mappingleri drawIcon fonksiyonuna da ekle (daha küçük boyutlarla)
 
 // Yuvarlak ekran için optimize büyük logolu hedef kartı çizimi
 void drawGoalCardBigLogo(String iconName, String goalName, int percent, int currentAmount, int totalAmount, String goalCount) {
   // 1. Logo: ekranın üst kısmında, ortada, daireye göre hizalı
   int logoSize = 70;
   int logoX = 120 - logoSize/2;
   int logoY = 25; // Dairenin üstünde, kenardan uzak
   drawIconLarge(iconName, logoX, logoY, WHITE);
 
   // 2. Hedef adı: logonun hemen altında, ortada (küçük font)
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(1);
   tft.setTextDatum(MC_DATUM);
   tft.drawString(goalName, 120, 100);
 
   // 3. Yüzde: hedef adının altında, ortada (küçük font)
   tft.setTextColor(YELLOW, BLACK);
   tft.setTextSize(1);
   tft.setTextDatum(MC_DATUM);
   tft.drawString("% " + String(percent), 120, 115);
 
   // 4. Progress bar: dairenin tam ortasında, kenardan uzak
   int barWidth = 120;
   int barHeight = 14;
   int barX = 120 - barWidth/2;
   int barY = 135;
   drawProgressBar(barX, barY, barWidth, barHeight, percent, GREEN, DARK_GRAY);
 
   // 5. Tutar: progress bar'ın hemen bir satır altında, ortada (küçük font)
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(1);
   tft.setTextDatum(MC_DATUM);
   tft.drawString(String(currentAmount) + " / " + String(totalAmount) + " ₺", 120, barY + barHeight + 12);
 
   // 6. Hedef sayısı: en altta, ortada
   tft.setTextColor(LIGHT_GRAY, BLACK);
   tft.setTextSize(1);
   tft.setTextDatum(MC_DATUM);
   tft.drawString(goalCount, 120, 200);
 }
 
 // --- YENİ EKRAN FONKSİYONLARI ---
 void drawBanknoteScreen() {
   tft.fillScreen(BLACK);
   // Daha gerçekçi banknot görseli
   tft.fillRect(70, 100, 100, 40, GREEN); // Banknot ana gövde
   tft.drawRect(70, 100, 100, 40, WHITE); // Kenar
   tft.drawRect(80, 110, 80, 20, WHITE); // İç çerçeve
   tft.fillCircle(120, 120, 10, WHITE); // Orta yuvarlak
   tft.setTextColor(GREEN, WHITE);
   tft.setTextSize(2);
   tft.setTextDatum(MC_DATUM);
   tft.drawString("$", 120, 120);
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(2);
   tft.drawString("Banknote Inserted", 120, 170);
 }

 void drawSafeOpeningScreen() {
   tft.fillScreen(BLACK);
   // Kasa kilidi açıldı görseli
   tft.fillRect(90, 80, 60, 60, CYAN);
   tft.drawRect(90, 80, 60, 60, WHITE);
   tft.fillCircle(120, 110, 10, DARK_GRAY); // Kasa kilidi
   tft.drawCircle(120, 110, 10, WHITE);
   tft.setTextColor(BLACK, CYAN);
   tft.setTextSize(2);
   tft.setTextDatum(MC_DATUM);
   tft.drawString("Safe Unlocked", 120, 110);
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(1);
   tft.drawString("Lock Opened", 120, 150);
 }

 void drawSafeDoorOpenScreen() {
   tft.fillScreen(BLACK);
   // Daha belirgin açık kasa görseli
   // Kasa gövdesi
   tft.fillRect(80, 90, 60, 60, ORANGE); // Ana gövde
   tft.drawRect(80, 90, 60, 60, WHITE);
   // Açık kapak (yana açılmış)
   tft.fillRect(140, 90, 20, 60, LIGHT_GRAY); // Kapak
   tft.drawRect(140, 90, 20, 60, WHITE);
   // Kapak menteşe çizgisi
   tft.drawLine(140, 90, 140, 150, DARK_GRAY);
   // Kasa içi gölge
   tft.fillRect(85, 95, 50, 50, DARK_GRAY);
   tft.setTextColor(BLACK, ORANGE);
   tft.setTextSize(2);
   tft.setTextDatum(MC_DATUM);
   tft.drawString("Safe Door Open", 110, 110);
   tft.setTextColor(WHITE, BLACK);
   tft.setTextSize(1);
   tft.drawString("Door is Open", 110, 150);
 }
 
 
  