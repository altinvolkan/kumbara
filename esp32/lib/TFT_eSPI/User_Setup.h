// ESP32-C3 Mini + GC9A01 240x240 Yuvarlak OLED Ekran Konfigürasyonu

#define USER_SETUP_ID 201

// Driver seçimi
#define GC9A01_DRIVER

// ESP32-C3 Mini pin tanımlamaları
#define TFT_CS   10    // CS  - Chip Select
#define TFT_DC   2     // DC  - Data/Command  
#define TFT_RST  1     // RST - Reset
#define TFT_MOSI 7     // SDA - SPI Data (MOSI)
#define TFT_SCLK 6     // SCL - SPI Clock

// SPI frekansı
#define SPI_FREQUENCY  27000000  // 27MHz
#define SPI_READ_FREQUENCY  20000000
#define SPI_TOUCH_FREQUENCY  2500000

// Ekran boyutları
#define TFT_WIDTH  240
#define TFT_HEIGHT 240

// Renk derinliği
#define TFT_RGB_ORDER TFT_BGR  // Set to TFT_BGR if colours are inverted

// Font desteği
#define LOAD_GLCD   // Font 1. Original Adafruit 8 pixel font needs ~1820 bytes in FLASH
#define LOAD_FONT2  // Font 2. Small 16 pixel high font, needs ~3534 bytes in FLASH, 96 characters
#define LOAD_FONT4  // Font 4. Medium 26 pixel high font, needs ~5848 bytes in FLASH, 96 characters
#define LOAD_FONT6  // Font 6. Large 48 pixel high font, needs ~2666 bytes in FLASH, only characters 1234567890:-.apm
#define LOAD_FONT7  // Font 7. 7 segment 48 pixel high font, needs ~2438 bytes in FLASH, only characters 1234567890:-.
#define LOAD_FONT8  // Font 8. Large 75 pixel high font needs ~3256 bytes in FLASH, only characters 1234567890:-.
#define LOAD_GFXFF  // FreeFonts. Include access to the 48 Adafruit_GFX free fonts FF1 to FF48 and custom fonts

// Smooth font desteği
#define SMOOTH_FONT

// SPIFFS desteği
//#define FS_NO_GLOBALS
//#define USE_SPIFFS 