#include <TFT_eSPI.h>
#include <math.h>

TFT_eSPI tft = TFT_eSPI();

// Ekran boyutları
#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 240
#define CENTER_X 120
#define CENTER_Y 120

// Gauge parametreleri
#define OUTER_RADIUS 115
#define INNER_RADIUS 85
#define NEEDLE_LENGTH 80

// Renkler (RGB565 format)
#define BLACK      0x0000
#define WHITE      0xFFFF
#define RED        0xF800
#define GREEN      0x07E0
#define BLUE       0x001F
#define YELLOW     0xFFE0
#define ORANGE     0xFD20
#define PURPLE     0x780F
#define CYAN       0x07FF
#define MAGENTA    0xF81F
#define DARK_GREEN 0x03E0
#define LIGHT_GRAY 0xC618
#define DARK_GRAY  0x7BEF

// Animasyon değişkenleri
float currentAngle = -135.0;  // Başlangıç açısı
float targetAngle = -135.0;   // Hedef açı
int currentValue = 0;
int targetValue = 0;
bool autoMode = true;
unsigned long lastUpdate = 0;
unsigned long lastAutoUpdate = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("🎯 GC9A01 Gelişmiş Gauge Test");
  
  // TFT başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(BLACK);
  
  // Başlangıç animasyonu
  showWelcomeScreen();
  
  // İlk gauge çiz
  drawCompleteGauge();
  
  Serial.println("✅ Test başladı! Serial Monitor'dan 0-100 arası değer gönderebilirsiniz.");
  Serial.println("📝 'auto' yazarak otomatik modu açabilirsiniz.");
}

void loop() {
  // Serial input kontrolü
  checkSerialInput();
  
  // Otomatik mod
  if (autoMode && millis() - lastAutoUpdate > 100) {
    updateAutoMode();
    lastAutoUpdate = millis();
  }
  
  // Smooth animasyon
  if (millis() - lastUpdate > 16) { // ~60 FPS
    updateAnimation();
    lastUpdate = millis();
  }
  
  delay(1);
}

void showWelcomeScreen() {
  tft.fillScreen(BLACK);
  
  // Başlık
  tft.setTextColor(CYAN);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", CENTER_X, 60);
  
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.drawString("Gauge Test v2.0", CENTER_X, 85);
  
  // Loading bar animasyonu
  int barWidth = 160;
  int barHeight = 8;
  int barX = CENTER_X - barWidth/2;
  int barY = 150;
  
  tft.drawRect(barX-1, barY-1, barWidth+2, barHeight+2, WHITE);
  
  for(int i = 0; i <= barWidth; i += 4) {
    tft.fillRect(barX, barY, i, barHeight, GREEN);
    delay(20);
  }
  
  delay(500);
  tft.fillScreen(BLACK);
}

void drawCompleteGauge() {
  // Arka plan gradient
  drawBackground();
  
  // Gauge çerçevesi
  drawGaugeFrame();
  
  // Değer işaretleri
  drawValueMarkers();
  
  // Merkez daire
  drawCenterCircle();
  
  // Değer gösterimi
  drawValueDisplay();
  
  // Needle
  drawNeedle();
  
  // Progress arc
  drawProgressArc();
}

void drawBackground() {
  // Radial gradient efekti (basit)
  for(int r = 0; r < 120; r += 5) {
    uint16_t color = tft.color565(r/8, r/12, r/6);
    tft.drawCircle(CENTER_X, CENTER_Y, 120-r, color);
  }
}

void drawGaugeFrame() {
  // Dış çember
  for(int i = 0; i < 5; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, OUTER_RADIUS - i, LIGHT_GRAY);
  }
  
  // İç çember
  for(int i = 0; i < 3; i++) {
    tft.drawCircle(CENTER_X, CENTER_Y, INNER_RADIUS + i, DARK_GRAY);
  }
}

void drawValueMarkers() {
  // 0-100 arası işaretler
  for(int value = 0; value <= 100; value += 10) {
    float angle = map(value, 0, 100, -135, 135);
    float radian = angle * PI / 180.0;
    
    // Büyük işaretler (10'un katları)
    int outerR = OUTER_RADIUS - 8;
    int innerR = (value % 20 == 0) ? OUTER_RADIUS - 20 : OUTER_RADIUS - 15;
    
    int x1 = CENTER_X + outerR * cos(radian);
    int y1 = CENTER_Y + outerR * sin(radian);
    int x2 = CENTER_X + innerR * cos(radian);
    int y2 = CENTER_Y + innerR * sin(radian);
    
    uint16_t color = (value % 20 == 0) ? WHITE : LIGHT_GRAY;
    tft.drawLine(x1, y1, x2, y2, color);
    
    // Sayılar (20'nin katları)
    if(value % 20 == 0) {
      int textR = OUTER_RADIUS - 30;
      int textX = CENTER_X + textR * cos(radian);
      int textY = CENTER_Y + textR * sin(radian);
      
      tft.setTextColor(WHITE);
      tft.setTextSize(1);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(String(value), textX, textY);
    }
  }
}

void drawCenterCircle() {
  // Merkez daire (gradient)
  for(int r = 25; r >= 0; r--) {
    uint16_t color = tft.color565(30 + r, 30 + r, 30 + r);
    tft.fillCircle(CENTER_X, CENTER_Y, r, color);
  }
  
  // Merkez nokta
  tft.fillCircle(CENTER_X, CENTER_Y, 3, WHITE);
}

void drawValueDisplay() {
  // Değer kutucuğu
  int boxW = 80;
  int boxH = 35;
  int boxX = CENTER_X - boxW/2;
  int boxY = CENTER_Y + 40;
  
  // Kutu arka planı
  tft.fillRoundRect(boxX, boxY, boxW, boxH, 8, DARK_GRAY);
  tft.drawRoundRect(boxX, boxY, boxW, boxH, 8, WHITE);
  
  // Değer metni
  tft.setTextColor(getValueColor(currentValue));
  tft.setTextSize(3);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(String(currentValue), CENTER_X, boxY + boxH/2 - 3);
  
  // % sembolü
  tft.setTextColor(WHITE);
  tft.setTextSize(1);
  tft.drawString("%", CENTER_X + 25, boxY + boxH/2 + 8);
}

void drawNeedle() {
  // Needle gölgesi
  drawNeedleAtAngle(currentAngle + 2, DARK_GRAY, false);
  
  // Ana needle
  drawNeedleAtAngle(currentAngle, getValueColor(currentValue), true);
}

void drawNeedleAtAngle(float angle, uint16_t color, bool withTip) {
  float radian = angle * PI / 180.0;
  
  // Needle gövdesi
  int tipX = CENTER_X + NEEDLE_LENGTH * cos(radian);
  int tipY = CENTER_Y + NEEDLE_LENGTH * sin(radian);
  
  // Kalın çizgi efekti
  for(int offset = -2; offset <= 2; offset++) {
    int offsetX = offset * sin(radian);
    int offsetY = -offset * cos(radian);
    tft.drawLine(CENTER_X + offsetX, CENTER_Y + offsetY, 
                 tipX + offsetX, tipY + offsetY, color);
  }
  
  // Needle ucu (ok)
  if(withTip) {
    float tipAngle1 = angle - 15;
    float tipAngle2 = angle + 15;
    float tipRadian1 = tipAngle1 * PI / 180.0;
    float tipRadian2 = tipAngle2 * PI / 180.0;
    
    int tip1X = tipX - 15 * cos(tipRadian1);
    int tip1Y = tipY - 15 * sin(tipRadian1);
    int tip2X = tipX - 15 * cos(tipRadian2);
    int tip2Y = tipY - 15 * sin(tipRadian2);
    
    tft.fillTriangle(tipX, tipY, tip1X, tip1Y, tip2X, tip2Y, color);
  }
}

void drawProgressArc() {
  // Progress yayı
  float progressAngle = map(currentValue, 0, 100, -135, 135);
  
  // Çoklu renk segments
  for(float angle = -135; angle <= progressAngle; angle += 2) {
    float radian = angle * PI / 180.0;
    int progress = map(angle, -135, 135, 0, 100);
    uint16_t color = getProgressColor(progress);
    
    // Kalın arc çizimi
    for(int thickness = 0; thickness < 8; thickness++) {
      int radius = INNER_RADIUS + 5 + thickness;
      int x = CENTER_X + radius * cos(radian);
      int y = CENTER_Y + radius * sin(radian);
      tft.drawPixel(x, y, color);
    }
  }
}

void updateAnimation() {
  // Smooth needle hareketi
  float angleDiff = targetAngle - currentAngle;
  if(abs(angleDiff) > 1) {
    currentAngle += angleDiff * 0.1; // Smooth interpolation
    drawCompleteGauge();
  }
  
  // Değer animasyonu
  if(currentValue != targetValue) {
    int valueDiff = targetValue - currentValue;
    if(abs(valueDiff) > 1) {
      currentValue += (valueDiff > 0) ? 1 : -1;
    } else {
      currentValue = targetValue;
    }
  }
}

void updateAutoMode() {
  static int autoDirection = 1;
  static int autoTarget = 0;
  
  if(autoTarget <= 0) {
    autoDirection = 1;
    autoTarget = random(20, 100);
  } else if(autoTarget >= 100) {
    autoDirection = -1;
    autoTarget = random(0, 80);
  } else {
    autoTarget += autoDirection * random(1, 3);
  }
  
  setValue(autoTarget);
}

void checkSerialInput() {
  if(Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    
    if(input.equals("auto")) {
      autoMode = !autoMode;
      Serial.println(autoMode ? "🔄 Otomatik mod AÇIK" : "⏸️ Otomatik mod KAPALI");
    } else {
      int value = input.toInt();
      if(value >= 0 && value <= 100) {
        autoMode = false;
        setValue(value);
        Serial.printf("📊 Değer ayarlandı: %d%%\n", value);
      } else {
        Serial.println("❌ Hata: 0-100 arası değer girin veya 'auto' yazın");
      }
    }
  }
}

void setValue(int value) {
  value = constrain(value, 0, 100);
  targetValue = value;
  targetAngle = map(value, 0, 100, -135, 135);
}

uint16_t getValueColor(int value) {
  if(value < 25) return RED;
  else if(value < 50) return ORANGE;
  else if(value < 75) return YELLOW;
  else return GREEN;
}

uint16_t getProgressColor(int progress) {
  // Rainbow gradient
  if(progress < 20) return RED;
  else if(progress < 40) return ORANGE;
  else if(progress < 60) return YELLOW;
  else if(progress < 80) return tft.color565(100, 255, 100);
  else return GREEN;
} 