#include <TFT_eSPI.h>

TFT_eSPI tft = TFT_eSPI();

// Ekran parametreleri
#define SCREEN_CENTER_X 120
#define SCREEN_CENTER_Y 120
#define GAUGE_OUTER_RADIUS 100
#define GAUGE_INNER_RADIUS 80
#define GAUGE_THICKNESS 20

// Renkler
#define COLOR_BLACK 0x0000
#define COLOR_WHITE 0xFFFF
#define COLOR_GREEN 0x07E0
#define COLOR_RED 0xF800
#define COLOR_YELLOW 0xFFE0
#define COLOR_ORANGE 0xFD20
#define COLOR_BLUE 0x001F
#define COLOR_GRAY 0x7BEF
#define COLOR_DARK_GRAY 0x39E7

// Test değişkenleri
int gauge_value = 0;
bool auto_mode = true;
int direction = 1;
unsigned long last_update = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("🔥 ESP32-C3 + GC9A01 Gauge Test Başlıyor!");
  Serial.println("📌 Pin Bağlantıları:");
  Serial.println("   GPIO 6  -> SCK");
  Serial.println("   GPIO 7  -> SDA");
  Serial.println("   GPIO 10 -> CS");
  Serial.println("   GPIO 2  -> DC");
  Serial.println("   GPIO 1  -> RST");
  
  // TFT ekranı başlat
  tft.init();
  tft.setRotation(0);
  tft.fillScreen(COLOR_BLACK);
  
  Serial.println("✅ Ekran başlatıldı!");
  
  // Hoşgeldin animasyonu
  welcome_animation();
  
  // Gauge tabanını çiz
  draw_gauge_base();
  
  Serial.println("🎯 Test başladı!");
  Serial.println("📱 Komutlar:");
  Serial.println("   0-100: Değer ayarla");
  Serial.println("   'auto': Otomatik mod aç/kapat");
}

void loop() {
  // Serial komut kontrolü
  check_serial_commands();
  
  // Otomatik test modu
  if (auto_mode && millis() - last_update > 50) {
    gauge_value += direction;
    
    if (gauge_value >= 100) {
      direction = -1;
      Serial.println("🔄 100% -> Geri dönüyor");
    }
    if (gauge_value <= 0) {
      direction = 1;  
      Serial.println("🔄 0% -> İleri gidiyor");
    }
    
    update_gauge(gauge_value);
    last_update = millis();
  }
  
  delay(10);
}

void welcome_animation() {
  tft.fillScreen(COLOR_BLACK);
  
  // Başlık
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(3);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("KUMBARA", SCREEN_CENTER_X, 70);
  
  tft.setTextColor(COLOR_GREEN);
  tft.setTextSize(2);
  tft.drawString("GAUGE TEST", SCREEN_CENTER_X, 100);
  
  tft.setTextColor(COLOR_GRAY);
  tft.setTextSize(1);
  tft.drawString("ESP32-C3 + GC9A01", SCREEN_CENTER_X, 125);
  
  // Loading bar
  int bar_y = 160;
  int bar_width = 140;
  int bar_height = 8;
  int bar_x = SCREEN_CENTER_X - bar_width/2;
  
  // Bar çerçevesi
  tft.drawRect(bar_x-1, bar_y-1, bar_width+2, bar_height+2, COLOR_WHITE);
  
  // Loading animasyonu
  for (int i = 0; i <= bar_width; i += 3) {
    tft.fillRect(bar_x, bar_y, i, bar_height, COLOR_GREEN);
    delay(20);
  }
  
  delay(1000);
  tft.fillScreen(COLOR_BLACK);
}

void draw_gauge_base() {
  // Başlık
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(2);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("GAUGE TEST", SCREEN_CENTER_X, 30);
  
  // Dış çerçeve çemberi
  tft.drawCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, GAUGE_OUTER_RADIUS + 3, COLOR_WHITE);
  tft.drawCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, GAUGE_OUTER_RADIUS + 2, COLOR_WHITE);
  
  // İç çerçeve çemberi  
  tft.drawCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, GAUGE_INNER_RADIUS - 2, COLOR_GRAY);
  tft.drawCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, GAUGE_INNER_RADIUS - 3, COLOR_GRAY);
  
  // Derece çizgileri ve sayılar
  for (int value = 0; value <= 100; value += 10) {
    float angle_deg = map(value, 0, 100, -135, 135); // 270° yay
    float angle_rad = angle_deg * PI / 180.0;
    
    // Çizgi koordinatları
    int x1 = SCREEN_CENTER_X + (GAUGE_OUTER_RADIUS - 5) * cos(angle_rad);
    int y1 = SCREEN_CENTER_Y + (GAUGE_OUTER_RADIUS - 5) * sin(angle_rad);
    int x2 = SCREEN_CENTER_X + (GAUGE_INNER_RADIUS + 5) * cos(angle_rad);
    int y2 = SCREEN_CENTER_Y + (GAUGE_INNER_RADIUS + 5) * sin(angle_rad);
    
    // Büyük çizgiler (20'nin katları)
    if (value % 20 == 0) {
      tft.drawLine(x1, y1, x2, y2, COLOR_WHITE);
      tft.drawLine(x1+1, y1, x2+1, y2, COLOR_WHITE); // Kalın çizgi
      
      // Sayı etiketi
      int text_x = SCREEN_CENTER_X + (GAUGE_INNER_RADIUS - 15) * cos(angle_rad);
      int text_y = SCREEN_CENTER_Y + (GAUGE_INNER_RADIUS - 15) * sin(angle_rad);
      
      tft.setTextColor(COLOR_WHITE);
      tft.setTextSize(1);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(String(value), text_x, text_y);
    }
    // Küçük çizgiler
    else {
      tft.drawLine(x1, y1, x2, y2, COLOR_GRAY);
    }
  }
  
  // Merkez daire
  tft.fillCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, 6, COLOR_WHITE);
  tft.fillCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, 4, COLOR_BLACK);
}

void update_gauge(int value) {
  // Gauge alanını temizle
  clear_gauge_area();
  
  // Yeni dolguyu çiz
  draw_gauge_fill(value);
  
  // Merkez değerini göster
  draw_center_value(value);
  
  // İğneyi çiz
  draw_needle(value);
  
  // Alt progress bar
  draw_bottom_progress(value);
  
  // Her 10% değişimde log
  if (value % 10 == 0) {
    Serial.printf("📊 Gauge: %d%% | Renk: %s\n", 
                  value, get_color_name(value).c_str());
  }
}

void clear_gauge_area() {
  // Gauge dolgu alanını temizle (yuvarlak halka)
  for (int r = GAUGE_INNER_RADIUS; r <= GAUGE_OUTER_RADIUS; r++) {
    tft.drawCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, r, COLOR_BLACK);
  }
  
  // Merkez alanı temizle
  tft.fillCircle(SCREEN_CENTER_X, SCREEN_CENTER_Y, GAUGE_INNER_RADIUS - 10, COLOR_BLACK);
}

void draw_gauge_fill(int value) {
  uint16_t fill_color = get_gauge_color(value);
  
  // 270° yay boyunca dolgu çiz
  float max_angle = 270.0;
  float fill_angle = (value / 100.0) * max_angle;
  
  // 2° adımlarla çiz
  for (float angle = 0; angle < fill_angle; angle += 2) {
    float actual_angle = -135 + angle; // -135°'den başla
    float rad = actual_angle * PI / 180.0;
    
    // Gauge kalınlığı boyunca çiz
    for (int r = GAUGE_INNER_RADIUS + 2; r < GAUGE_OUTER_RADIUS - 2; r++) {
      int x = SCREEN_CENTER_X + r * cos(rad);
      int y = SCREEN_CENTER_Y + r * sin(rad);
      tft.drawPixel(x, y, fill_color);
    }
  }
}

void draw_center_value(int value) {
  // Merkez değer gösterimi
  tft.setTextColor(get_gauge_color(value));
  tft.setTextSize(4);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(String(value), SCREEN_CENTER_X, SCREEN_CENTER_Y - 8);
  
  // % sembolü
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(2);
  tft.drawString("%", SCREEN_CENTER_X, SCREEN_CENTER_Y + 15);
}

void draw_needle(int value) {
  float angle_deg = map(value, 0, 100, -135, 135);
  float angle_rad = angle_deg * PI / 180.0;
  
  // İğne uzunluğu
  int needle_length = GAUGE_INNER_RADIUS - 15;
  int needle_x = SCREEN_CENTER_X + needle_length * cos(angle_rad);
  int needle_y = SCREEN_CENTER_Y + needle_length * sin(angle_rad);
  
  // Kalın iğne çiz
  tft.drawLine(SCREEN_CENTER_X, SCREEN_CENTER_Y, needle_x, needle_y, COLOR_WHITE);
  tft.drawLine(SCREEN_CENTER_X+1, SCREEN_CENTER_Y, needle_x+1, needle_y, COLOR_WHITE);
  tft.drawLine(SCREEN_CENTER_X, SCREEN_CENTER_Y+1, needle_x, needle_y+1, COLOR_WHITE);
}

void draw_bottom_progress(int value) {
  // Alt progress bar
  int bar_y = 210;
  int bar_width = 160;
  int bar_height = 10;
  int bar_x = SCREEN_CENTER_X - bar_width/2;
  
  // Arka plan
  tft.fillRect(bar_x, bar_y, bar_width, bar_height, COLOR_DARK_GRAY);
  
  // Dolgu
  int fill_width = map(value, 0, 100, 0, bar_width);
  tft.fillRect(bar_x, bar_y, fill_width, bar_height, get_gauge_color(value));
  
  // Çerçeve
  tft.drawRect(bar_x-1, bar_y-1, bar_width+2, bar_height+2, COLOR_WHITE);
  
  // Etiket
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(1);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("PROGRESS", SCREEN_CENTER_X, bar_y - 8);
}

uint16_t get_gauge_color(int value) {
  if (value < 20) return COLOR_RED;
  else if (value < 40) return COLOR_ORANGE;  
  else if (value < 60) return COLOR_YELLOW;
  else if (value < 80) return tft.color565(150, 255, 150); // Açık yeşil
  else return COLOR_GREEN;
}

String get_color_name(int value) {
  if (value < 20) return "Kırmızı";
  else if (value < 40) return "Turuncu";
  else if (value < 60) return "Sarı";
  else if (value < 80) return "Açık Yeşil";
  else return "Yeşil";
}

void check_serial_commands() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    
    if (command.equalsIgnoreCase("auto")) {
      auto_mode = !auto_mode;
      Serial.println(auto_mode ? "🔄 Otomatik mod AÇIK" : "⏸️ Otomatik mod KAPALI");
    }
    else {
      int value = command.toInt();
      if (value >= 0 && value <= 100) {
        auto_mode = false;
        gauge_value = value;
        update_gauge(gauge_value);
        Serial.printf("📊 Değer ayarlandı: %d%%\n", value);
      }
      else {
        Serial.println("❌ Hatalı komut! 0-100 arası sayı veya 'auto' yazın");
      }
    }
  }
} 