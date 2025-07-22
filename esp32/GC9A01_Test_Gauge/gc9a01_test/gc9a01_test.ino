#include <Arduino_GFX_Library.h>

#define TFT_CS    10
#define TFT_DC     9
#define TFT_RST    8
#define TFT_SCLK   6
#define TFT_MOSI   7
#define TFT_BLK   11  // Eğer bağlıysa

Arduino_DataBus *bus = new Arduino_SWSPI(TFT_DC, TFT_CS, TFT_SCLK, TFT_MOSI);
Arduino_GFX *gfx = new Arduino_GC9A01(bus, TFT_RST, 0 /*rotation*/, true /*IPS*/);

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Eğer BLK bağlıysa backlight'ı aç
  pinMode(TFT_BLK, OUTPUT);
  digitalWrite(TFT_BLK, HIGH);

  Serial.println("GC9A01 ekran başlatılıyor...");
  if (!gfx->begin()) {
    Serial.println("Ekran başlatılamadı!");
    while (1); // Don
  }

  Serial.println("Ekran tamam, ekran temizleniyor...");
  gfx->fillScreen(BLACK);
  gfx->setCursor(30, 30);
  gfx->setTextColor(WHITE);
  gfx->setTextSize(2);
  gfx->println("Calisiyor!");
}

void loop() {
  gfx->drawCircle(random(240), random(240), 20, random(0xFFFF));
  delay(200);
}
