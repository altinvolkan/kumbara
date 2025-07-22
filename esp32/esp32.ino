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
String USER_ID = "";
String DEVICE_NAME = "Kumbara";

// Colors
#define BLACK 0x0000
#define WHITE 0xFFFF
#define RED 0xF800
#define GREEN 0x07E0
#define BLUE 0x001F
#define YELLOW 0xFFE0
#define ORANGE 0xFD20
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

// Function declarations
void saveConfig();
void loadConfig();
void clearConfig();
void showStatus(String title, String message, uint16_t color);
void showStatusOnce(String title, String message, uint16_t color);
void setupBLE();
void drawIcon(String iconName, int x, int y, uint16_t color);

// ... (devamı KumbaraDisplay_Ultra.ino'daki gibi, eksiksiz şekilde buraya kopyalanacak) ... 