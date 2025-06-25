# ESP32-C3 Mini Kumbara Kontrol Sistemi

## Donanım Özellikleri
- **Mikrodenetleyici**: ESP32-C3 Mini (WiFi + Bluetooth 5.0)
- **Ekran**: GC9A01 240x240 Yuvarlak OLED Ekran
- **Sensör**: Para algılama sensörü
- **Bağlantı**: BLE + WiFi
- **Güç**: 3.3V (USB veya batarya)

## Pin Bağlantı Şeması

### GC9A01 Yuvarlak OLED Ekran (240x240)
```
ESP32-C3 Mini    <->    GC9A01 Ekran
GPIO 1           <->    RST (Reset)
GPIO 10          <->    CS  (Chip Select)  
GPIO 2           <->    DC  (Data/Command)
GPIO 7           <->    SDA (SPI Data/MOSI)
GPIO 6           <->    SCL (SPI Clock)
3.3V             <->    VCC (Power)
GND              <->    GND (Ground)
```

### Diğer Bileşenler
```
ESP32-C3 Mini    <->    Bileşen
GPIO 4           <->    Para Sensörü (Digital Input)
GPIO 9           <->    Reset Butonu (Pull-up)
GPIO 8           <->    Durum LED'i (Active Low)
GPIO 0 (A0)      <->    Batarya Seviyesi (ADC)
```

## Yazılım Özellikleri

### BLE Pairing
- Device ID: Otomatik oluşturulur
- Pairing Code: 6 haneli rastgele kod
- QR Kod: Child app ile hızlı eşleştirme
- JSON komut protokolü

### WiFi Konfigürasyonu
Child app'ten BLE ile gönderilen ayarlar:
```json
{
  "action": "configure",
  "ssid": "WiFi_Network_Name",
  "password": "wifi_password",
  "server": "http://192.168.1.21:3000",
  "userId": "user_id_from_backend",
  "deviceName": "Odamdaki Kumbara"
}
```

### Ekran Arayüzü

#### 1. Başlangıç Ekranı
- Kumbara logosu
- Device ID (son 8 karakter)
- BLE bekleme durumu

#### 2. QR Kod Ekranı
- Eşleştirme QR kodu
- Pairing code gösterimi
- Child app tarama beklentisi

#### 3. Durum Ekranı
- WiFi bağlantı durumu
- Server bağlantı durumu  
- Batarya seviyesi
- Account ID (son 8 karakter)
- Para atma hazırlık mesajı

### Para İşlem Sistemi

#### Coin Detection
- Optik/manyetik sensör
- Debounce koruması (500ms)
- LED feedback

#### Backend İletişimi
```json
POST /api/esp32/transaction
{
  "deviceId": "esp32_device_id",
  "type": "deposit", 
  "amount": 1.0,
  "description": "Kumbaraya para atıldı"
}
```

#### Otomatik Hedef Dağıtımı
- Backend'e para gönderilir
- Öncelik sistemine göre dağıtılır
- Child app real-time güncelenir

## Kurulum

### 1. PlatformIO Kurulumu
```bash
pio run --target upload
pio device monitor
```

### 2. Child App Eşleştirme
1. Child app'te bluetooth ikonuna bas
2. "Cihaz Eşleştir" butonuna bas
3. ESP32'yi listede bul ve eşleştir
4. WiFi bilgilerini gir
5. Eşleştirme tamamlanır

### 3. Test
```bash
# ESP32 transaction test
curl -X POST http://192.168.1.21:3000/api/esp32/transaction \
  -H "Content-Type: application/json" \
  -H "X-ESP32-Secret: esp32-secret-key-2025" \
  -d '{"deviceId":"test-device","type":"deposit","amount":5}'
```

## Sistem Durumları

### STATE_INIT
- Başlangıç ekranı
- Device ID gösterimi
- BLE server başlatma

### STATE_WAITING_PAIR  
- QR kod gösterimi
- BLE eşleştirme bekleme
- Pairing code display

### STATE_WIFI_SETUP
- WiFi bağlantı deneme
- Progress gösterimi
- Hata durumu yönetimi

### STATE_CONNECTED
- Normal çalışma modu
- Para algılama aktif
- Periyodik status update
- Battery monitoring

### STATE_ERROR
- Hata mesajı gösterimi
- Reset butonu bekleme
- Recovery seçenekleri

## Troubleshooting

### BLE Bağlantı Problemi
- ESP32'yi reset edin
- Child app bluetooth ayarlarını kontrol edin
- Cihazları yakın mesafede tutun

### WiFi Bağlantı Problemi  
- SSID ve şifre kontrolü
- Router 2.4GHz desteği
- IP adresi çakışması

### Display Problemi
- Pin bağlantılarını kontrol edin
- 3.3V güç beslemesi
- SPI bus paylaşımı

### Backend İletişim Problemi
- Server IP adresini kontrol edin  
- Port 3000 açık olmalı
- ESP32 secret key doğruluğu

## Geliştirme Notları

### Memory Usage
- PSRAM: Kullanılabilir
- Flash: ~1.5MB kullanım
- SRAM: ~200KB kullanım

### Power Management
- Deep sleep desteği
- Battery monitoring
- Low power WiFi modu

### Security
- BLE pairing encryption
- Backend secret key
- Device ID benzersizliği 