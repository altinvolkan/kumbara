// ESP32-C3 Mini + GC9A01 240x240 Yuvarlak OLED Ekran Konfigürasyonu
// ÇALIŞAN KONFİGÜRASYON! - MOSI=5, SCK=4

#define USER_SETUP_INFO "C3 WORKING PINS - MOSI=5, SCK=4"

// Driver seçimi
#define GC9A01_DRIVER

// Ekran boyutları
#define TFT_WIDTH  240
#define TFT_HEIGHT 240

// ESP32-C3 Mini pin tanımlamaları - ÇALIŞAN PİNLER!
#define TFT_MOSI 5     // SDA - SPI Data (MOSI)
#define TFT_SCLK 4     // SCL - SPI Clock  
#define TFT_CS   3     // CS  - Chip Select
#define TFT_DC   2     // DC  - Data/Command  
#define TFT_RST  1     // RST - Reset

// DMA devre dışı
#define TFT_SPI_DMA_DISABLED

// SPI frekansı - Çalışan değerler
#define SPI_FREQUENCY 13500000  // 13.5MHz

// Font desteği
#define LOAD_GLCD   // Font 1. Original Adafruit 8 pixel font needs ~1820 bytes in FLASH
#define LOAD_FONT2  // Font 2. Small 16 pixel high font, needs ~3534 bytes in FLASH, 96 characters
// #define LOAD_FONT4  // Font 4. Medium 26 pixel high font, needs ~5848 bytes in FLASH, 96 characters
// #define LOAD_FONT6  // Font 6. Large 48 pixel high font, needs ~2666 bytes in FLASH, only characters 1234567890:-.apm
// #define LOAD_FONT7  // Font 7. 7 segment 48 pixel high font, needs ~2438 bytes in FLASH, only characters 1234567890:.
// #define LOAD_FONT8  // Font 8. Large 75 pixel high font needs ~3256 bytes in FLASH, only characters 1234567890:-.
// #define LOAD_GFXFF  // FreeFonts. Include access to the 48 Adafruit_GFX free fonts FF1 to FF48 and custom fonts
// #define SMOOTH_FONT 