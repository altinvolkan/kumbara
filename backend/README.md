# Kumbara Kontrol Backend

Bu proje, Kumbara Kontrol ve Ana Bank uygulamaları için backend servisini içerir.

## Özellikler

- Kullanıcı yönetimi (kayıt, giriş, profil)
- Cihaz yönetimi (eşleştirme, durum takibi)
- İşlem yönetimi (para yatırma, çekme, transfer)
- Hedef yönetimi (hedef oluşturma, takip)
- Gerçek zamanlı güncellemeler (WebSocket)
- Güvenli kimlik doğrulama (JWT)
- Hata yönetimi ve loglama

## Teknolojiler

- Node.js
- Express.js
- MongoDB (Mongoose)
- Socket.IO
- JWT
- Winston (Loglama)

## Kurulum

1. Gerekli paketleri yükleyin:
```bash
npm install
```

2. `.env` dosyasını oluşturun:
```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/kumbara
JWT_SECRET=your-secret-key
ESP32_SECRET=your-esp32-secret
NODE_ENV=development
```

3. MongoDB'yi başlatın:
```bash
mongod
```

4. Sunucuyu başlatın:
```bash
# Geliştirme modu
npm run dev

# Üretim modu
npm start
```

## API Endpoints

### Kimlik Doğrulama

- `POST /api/auth/register` - Yeni kullanıcı kaydı
- `POST /api/auth/login` - Kullanıcı girişi
- `PATCH /api/auth/profile` - Profil güncelleme

### Cihazlar

- `POST /api/devices` - Yeni cihaz oluşturma
- `GET /api/devices` - Cihazları listeleme
- `GET /api/devices/:id` - Cihaz detayları
- `POST /api/devices/:id/pair` - Cihaz eşleştirme
- `PATCH /api/devices/:id/settings` - Cihaz ayarlarını güncelleme
- `POST /api/devices/:deviceId/status` - Cihaz durumunu güncelleme (ESP32)

### İşlemler

- `POST /api/transactions` - Yeni işlem oluşturma
- `GET /api/transactions/:deviceId` - İşlem geçmişi
- `GET /api/transactions/:deviceId/stats` - İşlem istatistikleri

### Hedefler

- `POST /api/goals` - Yeni hedef oluşturma
- `GET /api/goals/:deviceId` - Hedefleri listeleme
- `GET /api/goals/:deviceId/:id` - Hedef detayları
- `PATCH /api/goals/:deviceId/:id` - Hedef güncelleme
- `PATCH /api/goals/:deviceId/:id/status` - Hedef durumunu güncelleme

## WebSocket Events

### Client -> Server

- `join-device` - Cihaz odasına katılma
- `balance-update` - Bakiye güncelleme
- `goal-update` - Hedef ilerleme güncelleme

### Server -> Client

- `balance-changed` - Bakiye değişikliği bildirimi
- `goal-progress` - Hedef ilerleme bildirimi

## Güvenlik

- JWT tabanlı kimlik doğrulama
- Şifre hashleme (bcrypt)
- ESP32 için özel güvenlik anahtarı
- CORS yapılandırması
- Rate limiting (gelecek sürümde)

## Geliştirme

1. Kod formatı:
```bash
npm run format
```

2. Lint kontrolü:
```bash
npm run lint
```

3. Test (gelecek sürümde):
```bash
npm test
```

## Lisans

MIT 