// ESP32 Transaction Test (CommonJS)
const https = require('https');
const http = require('http');

const serverUrl = 'http://localhost:3000';
const esp32Secret = 'esp32-super-secret-key-2024';

async function testESP32Transaction() {
  console.log('🚀 ESP32 Transaction Test Başlatılıyor...\n');
  
  const deviceId = 'test-esp32-c3-device';
  
  const postData = JSON.stringify({
    deviceId: deviceId,
    type: 'deposit',
    amount: 5.0,
    description: 'ESP32-C3 Test Para Yatırma'
  });
  
  const options = {
    hostname: '192.168.1.21',
    port: 3000,
    path: '/api/esp32/transaction',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-ESP32-Secret': esp32Secret,
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  
  const req = http.request(options, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('📡 Status Code:', res.statusCode);
      try {
        const result = JSON.parse(data);
        if (res.statusCode === 200) {
          console.log('✅ Transaction başarılı!');
          console.log('📊 Sonuç:', JSON.stringify(result, null, 2));
        } else {
          console.log('❌ Transaction hatası:', result.error);
          
          if (result.error === 'Cihaz bulunamadı') {
            console.log('\n💡 İpucu: Önce bir device oluşturup linkedAccount set etmelisiniz');
            console.log('Test için gerçek device ID kullanın veya yeni device oluşturun');
          }
        }
      } catch (error) {
        console.log('📄 Raw Response:', data);
      }
    });
  });
  
  req.on('error', (error) => {
    console.error('🔥 Request hatası:', error.message);
  });
  
  req.write(postData);
  req.end();
  
  console.log('\n🏁 Test tamamlandı');
}

// Test çalıştır
testESP32Transaction(); 