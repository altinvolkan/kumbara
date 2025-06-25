const mongoose = require('mongoose');

// MongoDB connection
mongoose.connect('mongodb://localhost:27017/kumbara', {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

const clearDemo = async () => {
  try {
    console.log('MongoDB bağlantısı bekleniyor...');
    await new Promise((resolve) => {
      mongoose.connection.once('open', resolve);
    });
    
    console.log('Demo hedefler siliniyor...');
    
    // Çocuk kullanıcısının ID'si
    const childUserId = '685bbdee3d73bef485bd2791';
    
    // MongoDB'de direkt sil
    const db = mongoose.connection.db;
    const result = await db.collection('goals').deleteMany({
      owner: new mongoose.Types.ObjectId(childUserId)
    });
    
    console.log(`${result.deletedCount} hedef silindi!`);
    console.log('Artık çocuk uygulamasında boş liste göreceksiniz.');
    
    process.exit(0);
  } catch (error) {
    console.error('Hata:', error);
    process.exit(1);
  }
};

clearDemo(); 