// ESP32 Transaction Test Script
// Node.js 18+ built-in fetch kullanıyoruz

const serverUrl = 'http://localhost:3000';
const esp32Secret = 'esp32-super-secret-key-2024';

// Test ESP32 cihazı oluşturmak için önce bir device oluşturalım
async function testESP32Transaction() {
  console.log('🚀 ESP32 Transaction Test Başlatılıyor...\n');
  
  // 1. Test için ESP32 device transaction gönder
  console.log('📡 ESP32 Transaction gönderiliyor...');
  
  const deviceId = 'test-esp32-c3-device'; // Test device ID
  
  try {
    const response = await fetch(`${serverUrl}/api/devices/transaction`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-ESP32-Secret': esp32Secret
      },
      body: JSON.stringify({
        deviceId: deviceId,
        type: 'deposit',
        amount: 5.0,
        description: 'ESP32-C3 Test Para Yatırma'
      })
    });
    
    const result = await response.json();
    
    if (response.ok) {
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
    console.error('🔥 Network hatası:', error.message);
  }
  
  console.log('\n🏁 Test tamamlandı');
}

// Test çalıştır
testESP32Transaction(); 