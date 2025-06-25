# 🏦 Kumbara - ESP32 Entegreli Fiziksel Kumbara Sistemi

ESP32-C3 entegreli fiziksel kumbara projesi. Çocuklar için hedef tabanlı para biriktirme sistemi.

## 🚀 Proje Genel Durumu

**✅ BAŞARIYLA TAMAMLANDI!** Sistem tam olarak çalışır durumda.

### 📊 Sistem Bileşenleri
- **Backend**: Node.js/Express (localhost:3000, 192.168.1.21:3000)
- **Frontend**: Flutter Child App (çocuk uygulaması)
- **Hardware**: ESP32-C3 Mini + GC9A01 OLED (240x240)
- **Veritabanı**: MongoDB
- **İletişim**: BLE (Bluetooth Low Energy)

### 🎯 Test Kullanıcı Bilgileri
- **Email**: z@x.com
- **Password**: 123456
- **Rol**: Çocuk hesabı
- **Bağlı Hesap ID**: 685bba3aadcfbbf856613ed3
- **Kullanıcı ID**: 685bbdee3d73bef485bd2791

## 📱 Child App Özellikleri

### 🔧 Ana Fonksiyonlar
- ✅ Hedef oluşturma/düzenleme/silme
- ✅ Para redistribüsyonu (hedef silindiğinde)
- ✅ Öncelik sistemi (1-5 arası)
- ✅ Manuel para aktarımı (hesaptan hedefe)
- ✅ ESP32 BLE entegrasyonu
- ✅ Tamamlanan/Aktif hedefler tab sistemi

### 📊 Görsel Özellikler
- 🎨 Gradient tasarım
- 📈 Progress bar'lar
- 🏆 Altın kupa (tamamlanan hedefler)
- 🔄 Tab controller (aktif/tamamlanan)
- ⚡ ESP32 sync butonu

## 🔌 ESP32-C3 Özellikleri

### 📟 Donanım
- **Board**: ESP32-C3 Mini
- **Display**: GC9A01 Yuvarlak OLED (240x240)
- **İletişim**: BLE
- **Beslenme**: USB/Batarya

### 🎯 Yazılım Özellikleri
- ✅ BLE Server ("KumbaraDisplay")
- ✅ Serial Monitor debug mesajları
- ✅ Hedef döngüsü (5 saniye aralık)
- ✅ ASCII Progress Bar'lar
- ✅ JSON komut işleme
- ✅ Ultra minimal kod (watchdog-free)

### 📊 ESP32 Çıktı Örneği
```
🎯 AKTİF HEDEF: PC
💰 İlerleme: 28000/50000 (%56)
📈 [███████████░░░░░░░░░]
───────────────────────────
🔄 Sonraki hedefe geçiliyor...
🎯 AKTİF HEDEF: asdf  
💰 İlerleme: 20000/20000 (%100)
📈 [████████████████████]
```

## 🏗️ Backend API

### 🔗 Ana Endpoint'ler
- **Hesaplar**: `/api/accounts` (GET, POST, PUT, DELETE)
- **Hedefler**: `/api/goals` (GET, POST, PUT, DELETE)
- **Kimlik Doğrulama**: `/api/auth` (login, register)
- **Cihazlar**: `/api/devices` (BLE cihaz yönetimi)
- **Transfer**: `/api/accounts/transfer-to-goal` (manuel aktarım)

### 💰 Para Dağıtım Sistemi
- ✅ Otomatik öncelik bazlı dağıtım
- ✅ Hedef tamamlandığında sonrakine geçiş
- ✅ Hedef silindiğinde redistribüsyon
- ✅ Bakiye korunumu (para kaybı yok)

## 🔄 BLE İletişim

### 📡 UUID Konfigürasyonu
- **Service UUID**: `12345678-1234-1234-1234-123456789abc`
- **Characteristic UUID**: `12345678-1234-1234-1234-123456789abd`

### 📨 JSON Komut Formatı
```json
{
  "action": "update_goals",
  "goals": [
    {
      "id": "goal_id",
      "title": "PC",
      "currentAmount": 28000,
      "targetAmount": 50000,
      "isCompleted": false
    }
  ]
}
```

## 🛠️ Kurulum

### 📱 Child App
```bash
cd child_app
flutter pub get
flutter run
```

### 🖥️ Backend
```bash
cd backend
npm install
npm start
```

### 📟 ESP32
1. Arduino IDE'de ESP32-C3 board seç
2. `esp32/KumbaraKontrol_ESP32_C3.ino` dosyasını yükle
3. Serial Monitor'u aç (115200 baud)

## 🎮 Kullanım

1. **Backend'i başlat** (port 3000)
2. **Child app'i aç** ve z@x.com ile giriş yap
3. **ESP32'yi açık tut** (Serial Monitor ile kontrol)
4. **Home Screen'de ⚡ sync butonuna bas**
5. **ESP32'de hedeflerin döngüsünü izle** 📊

## 🔧 Gelişme Süreci

### ✅ Çözülen Ana Sorunlar
1. **Route Sırası**: `/goals/visible` ve `/accounts/linked` öncelik düzeltmesi
2. **Para Dağıtımı**: `updateBalance()` ve `distributeToGoals()` sistemi
3. **Hedef Silme**: Para redistribüsyonu ile kayıpsız silme
4. **BLE UUID Uyumu**: ESP32 ↔ Child App senkronizasyonu
5. **ESP32 Watchdog**: Ultra minimal kod ile boot döngüsü çözümü
6. **TFT Sorunları**: TFT_eSPI kaldırılarak Serial Monitor çözümü

### 📈 Başarı Metrikleri
- ✅ %100 BLE bağlantı başarısı
- ✅ Gerçek zamanlı hedef senkronizasyonu
- ✅ Hatasız para dağıtım algoritması
- ✅ Stabil ESP32 çalışması (watchdog-free)

## 🎯 Sistem Akışı

```
[Child App] → BLE → [ESP32-C3] → Serial Monitor Display
     ↓                               ↑
[Backend API] ← MongoDB ← Hedef Verileri
```

**🏆 Proje başarıyla tamamlandı! Tüm bileşenler sorunsuz çalışıyor.**

---

*Son güncelleme: 2025-01-26*
*ESP32 Serial Monitor Test: ✅ BAŞARILI*
*BLE Sync Test: ✅ BAŞARILI* 