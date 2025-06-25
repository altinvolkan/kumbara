const mongoose = require('mongoose');
const Goal = require('./src/models/Goal');

// MongoDB connection
mongoose.connect('mongodb://localhost:27017/kumbara', {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

const deleteDemo = async () => {
  try {
    console.log('Demo hedefler siliniyor...');
    
    // Çocuk kullanıcısının ID'si
    const childUserId = '685bbdee3d73bef485bd2791';
    
    // Bu kullanıcının tüm hedeflerini sil
    const result = await Goal.deleteMany({ owner: childUserId });
    
    console.log(`${result.deletedCount} hedef silindi!`);
    console.log('Çocuk uygulamasında hot reload yapın.');
    
    process.exit(0);
  } catch (error) {
    console.error('Hata:', error);
    process.exit(1);
  }
};

deleteDemo(); 