#pragma once

// ÇALIŞAN KONFİGÜRASYON! - MOSI=5, SCK=4
#define GC9A01_DRIVER

#define TFT_WIDTH 240
#define TFT_HEIGHT 240

// ESP32-C3 çalışan pin bağlantıları
#define TFT_MOSI 5
#define TFT_SCLK 4
#define TFT_CS 3
#define TFT_DC 2
#define TFT_RST 1

// Çalışan SPI ayarları
#define TFT_SPI_DMA_DISABLED
#define SPI_FREQUENCY 13500000  // 13.5 MHz

// Font desteği
#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF
#define SMOOTH_FONT
