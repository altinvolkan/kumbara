#define GC9A01_DRIVER

#define TFT_CS   10
#define TFT_DC    2
#define TFT_RST   8

#define TFT_MOSI  7
#define TFT_SCLK  6

#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF

#define SPI_FREQUENCY  27000000  // GC9A01 için ideal hız
#define SPI_READ_FREQUENCY  20000000
