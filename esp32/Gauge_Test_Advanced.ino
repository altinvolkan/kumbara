#include <TFT_eSPI.h>
#include <math.h>

TFT_eSPI tft = TFT_eSPI();

// Ekran ve gauge parametreleri
#define CENTER_X 120
#define CENTER_Y 120
#define GAUGE_RADIUS 100
#define GAUGE_WIDTH 15

// Renkler
#define BLACK 0x0000
#define WHITE 0xFFFF
#define GREEN 0x07E0
#define RED 0xF800
#define BLUE 0x001F
#define YELLOW 0xFFE0
#define ORANGE 0xFD20
#define PURPLE 0x780F
#define GRAY 0x7BEF

// Test değişkenleri
int currentValue = 0;
int targetValue = 0;
bool autoTest = true;
unsigned long lastUpdate = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("🎯 ESP32-C3 GC9A01 Gauge Test");
  
  // TFT başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Hoşgeldin ekranı
  showWelcome();
  delay(2000);
  
  // İlk gauge çiz
  drawGaugeBase();
  updateGauge(0);
  
  Serial.println("✅ Test başladı!");
  Serial.println("📱 0-100 arası değer gönderin veya 'auto' yazın");
}

void loop() {
  // Serial input kontrolü
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    
    if (input == "auto") {
      autoTest = !autoTest;
      Serial.println(autoTest ? "🔄 Otomatik test AÇIK" : "⏸️ Otomatik test KAPALI");
    } else {
      int value = input.toInt();
      if (value >= 0 && value <= 100) {
        autoTest = false;
        setGaugeValue(value);
      }
    }
  }
  
  // Otomatik test
  if (autoTest && millis() - lastUpdate > 50) {
    static int direction = 1;
    currentValue += direction;
    
    if (currentValue >= 100) direction = -1;
    if (currentValue <= 0) direction = 1;
    
    updateGauge(currentValue);
    lastUpdate = millis();
    
    // Her %10'da log
    if (currentValue % 10 == 0) {
      Serial.printf("📊 Gauge: %d%%\n", currentValue);
    }
  }
}

void showWelcome() {
  tft.fillScreen(BLACK);
  
  // Başlık
  tft.setTextColor(WHITE);
  tft.setTextSize(3);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", CENTER_X, 80);
  
  tft.setTextColor(GREEN);
  tft.setTextSize(2);
  tft.drawString("GAUGE TEST", CENTER_X, 110);
  
  tft.setTextColor(GRAY);
  tft.setTextSize(1);
  tft.drawString("v1.0 - ESP32-C3", CENTER_X, 140);
  
  // Loading animasyonu
  for (int i = 0; i <= 100; i += 5) {
    int barWidth = map(i, 0, 100, 0, 120);
    tft.fillRect(CENTER_X - 60, 170, barWidth, 6, GREEN);
    delay(50);
  }
}

void drawGaugeBase() {
  tft.fillScreen(BLACK);
  
  // Dış çerçeve
  tft.drawCircle(CENTER_X, CENTER_Y, GAUGE_RADIUS + 5, WHITE);
  tft.drawCircle(CENTER_X, CENTER_Y, GAUGE_RADIUS + 4, WHITE);
  
  // İç çerçeve
  tft.drawCircle(CENTER_X, CENTER_Y, GAUGE_RADIUS - GAUGE_WIDTH - 2, GRAY);
  
  // Derece işaretleri (0-100%)
  for (int i = 0; i <= 100; i += 10) {
    float angle = map(i, 0, 100, 225, 315); // 270° yay (225° -> 315°)
    float radian = angle * PI / 180.0;
    
    int x1 = CENTER_X + (GAUGE_RADIUS - 2) * cos(radian);
    int y1 = CENTER_Y + (GAUGE_RADIUS - 2) * sin(radian);
    int x2 = CENTER_X + (GAUGE_RADIUS - 12) * cos(radian);
    int y2 = CENTER_Y + (GAUGE_RADIUS - 12) * sin(radian);
    
    uint16_t color = (i % 20 == 0) ? WHITE : GRAY;
    tft.drawLine(x1, y1, x2, y2, color);
    
    // Sayılar
    if (i % 20 == 0) {
      int textX = CENTER_X + (GAUGE_RADIUS - 25) * cos(radian);
      int textY = CENTER_Y + (GAUGE_RADIUS - 25) * sin(radian);
      tft.setTextColor(WHITE);
      tft.setTextSize(1);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(String(i), textX, textY);
    }
  }
  
  // Merkez daire
  tft.fillCircle(CENTER_X, CENTER_Y, 8, WHITE);
  tft.fillCircle(CENTER_X, CENTER_Y, 6, BLACK);
}

void updateGauge(int value) {
  // Önceki gauge dolgusu temizle
  clearGaugeFill();
  
  // Yeni dolgu çiz
  drawGaugeFill(value);
  
  // Merkez değeri göster
  showCenterValue(value);
  
  // İğne çiz
  drawNeedle(value);
  
  // Alt progress bar
  drawProgressBar(value);
}

void clearGaugeFill() {
  // Gauge alanını temizle
  for (int r = GAUGE_RADIUS - GAUGE_WIDTH; r < GAUGE_RADIUS; r++) {
    tft.drawCircle(CENTER_X, CENTER_Y, r, BLACK);
  }
}

void drawGaugeFill(int value) {
  // Değere göre renk seç
  uint16_t fillColor = getGaugeColor(value);
  
  // 270° yay boyunca dolgu
  float maxAngle = 270.0;
  float fillAngle = (value / 100.0) * maxAngle;
  
  for (float angle = 0; angle < fillAngle; angle += 2) {
    float actualAngle = 225 + angle; // 225°'den başla
    float radian = actualAngle * PI / 180.0;
    
    // Gauge kalınlığı boyunca çiz
    for (int r = GAUGE_RADIUS - GAUGE_WIDTH + 2; r < GAUGE_RADIUS - 2; r++) {
      int x = CENTER_X + r * cos(radian);
      int y = CENTER_Y + r * sin(radian);
      tft.drawPixel(x, y, fillColor);
    }
  }
}

void drawNeedle(int value) {
  float angle = map(value, 0, 100, 225, 315); // 225° -> 315°
  float radian = angle * PI / 180.0;
  
  // İğne uzunluğu
  int needleLength = GAUGE_RADIUS - 20;
  int needleX = CENTER_X + needleLength * cos(radian);
  int needleY = CENTER_Y + needleLength * sin(radian);
  
  // İğne çiz (kalın)
  tft.drawLine(CENTER_X, CENTER_Y, needleX, needleY, WHITE);
  tft.drawLine(CENTER_X + 1, CENTER_Y, needleX + 1, needleY, WHITE);
  tft.drawLine(CENTER_X, CENTER_Y + 1, needleX, needleY + 1, WHITE);
  
  // İğne merkezi
  tft.fillCircle(CENTER_X, CENTER_Y, 4, WHITE);
}

void showCenterValue(int value) {
  // Merkez alanını temizle
  tft.fillCircle(CENTER_X, CENTER_Y, 35, BLACK);
  
  // Değer metni
  tft.setTextColor(getGaugeColor(value));
  tft.setTextSize(3);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(String(value), CENTER_X, CENTER_Y - 8);
  
  // % sembolü
  tft.setTextSize(1);
  tft.setTextColor(WHITE);
  tft.drawString("%", CENTER_X, CENTER_Y + 15);
}

void drawProgressBar(int value) {
  // Alt kısımda horizontal progress bar
  int barY = 200;
  int barWidth = 180;
  int barHeight = 12;
  int barX = CENTER_X - barWidth / 2;
  
  // Arka plan
  tft.fillRect(barX, barY, barWidth, barHeight, GRAY);
  
  // Dolgu
  int fillWidth = map(value, 0, 100, 0, barWidth);
  uint16_t barColor = getGaugeColor(value);
  tft.fillRect(barX, barY, fillWidth, barHeight, barColor);
  
  // Çerçeve
  tft.drawRect(barX - 1, barY - 1, barWidth + 2, barHeight + 2, WHITE);
  
  // Metin
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("PROGRESS", CENTER_X, barY - 10);
}

uint16_t getGaugeColor(int value) {
  if (value < 20) return RED;
  else if (value < 40) return ORANGE;
  else if (value < 60) return YELLOW;
  else if (value < 80) return tft.color565(100, 255, 100); // Açık yeşil
  else return GREEN;
}

void setGaugeValue(int value) {
  value = constrain(value, 0, 100);
  updateGauge(value);
  Serial.printf("📊 Gauge değeri: %d%%\n", value);
} 