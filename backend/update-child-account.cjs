const mongoose = require('mongoose');

// MongoDB connection
mongoose.connect('mongodb://localhost:27017/kumbara', {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

const updateChild = async () => {
  try {
    console.log('MongoDB bağlantısı bekleniyor...');
    await new Promise((resolve) => {
      mongoose.connection.once('open', resolve);
    });
    
    console.log('Çocuk kullanıcısının linkedAccount field\'ı ekleniyor...');
    
    // Çocuk kullanıcısının ID ve hesap ID'si
    const childUserId = '685bbdee3d73bef485bd2791';
    const linkedAccountId = '685bba3aadcfbbf856613ed3';
    
    // MongoDB'de direkt güncelle
    const db = mongoose.connection.db;
    const result = await db.collection('users').updateOne(
      { _id: new mongoose.Types.ObjectId(childUserId) },
      { $set: { linkedAccount: new mongoose.Types.ObjectId(linkedAccountId) } }
    );
    
    console.log(`${result.modifiedCount} kullanıcı güncellendi!`);
    console.log('Çocuk uygulamasını yeniden başlatın.');
    
    // Kontrol et
    const user = await db.collection('users').findOne({ _id: new mongoose.Types.ObjectId(childUserId) });
    console.log('Güncel kullanıcı:', user);
    
    process.exit(0);
  } catch (error) {
    console.error('Hata:', error);
    process.exit(1);
  }
};

updateChild(); 