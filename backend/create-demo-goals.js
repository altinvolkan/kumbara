import mongoose from 'mongoose';
import { Goal } from './src/models/Goal.js';

// MongoDB bağlantısı
mongoose.connect('mongodb://localhost:27017/kumbara', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});

const childUserId = '685bbdee3d73bef485bd2791'; // zx kullanıcısının ID'si

const demoGoals = [
  {
    name: 'Yeni Bisiklet',
    description: 'Kırmızı dağ bisikleti almak istiyorum!',
    targetAmount: 2000,
    currentAmount: 750,
    icon: 'directions_bike',
    color: '#4CAF50',
    category: 'sport',
    priority: 1,
    isVisible: true,
    isParallel: false,
    status: 'active',
    owner: childUserId,
  },
  {
    name: 'Nintendo Switch',
    description: 'Arkadaşlarımla oyun oynamak için',
    targetAmount: 3500,
    currentAmount: 1200,
    icon: 'videogame_asset',
    color: '#FF5722',
    category: 'electronics',
    priority: 2,
    isVisible: true,
    isParallel: true,
    status: 'active',
    owner: childUserId,
  },
  {
    name: 'Matematik Kitabı Seti',
    description: 'Matematik derslerim için özel kitaplar',
    targetAmount: 500,
    currentAmount: 350,
    icon: 'calculate',
    color: '#2196F3',
    category: 'education',
    priority: 3,
    isVisible: true,
    isParallel: true,
    status: 'active',
    owner: childUserId,
  },
  {
    name: 'Futbol Topu',
    description: 'Profesyonel futbol topu',
    targetAmount: 300,
    currentAmount: 300,
    icon: 'sports_soccer',
    color: '#8BC34A',
    category: 'sport',
    priority: 4,
    isVisible: true,
    isParallel: false,
    status: 'completed',
    owner: childUserId,
  },
  {
    name: 'Lego Castle Set',
    description: 'Büyük lego kalesi seti',
    targetAmount: 1500,
    currentAmount: 450,
    icon: 'castle',
    color: '#FF9800',
    category: 'toy',
    priority: 5,
    isVisible: true,
    isParallel: false,
    status: 'active',
    owner: childUserId,
  },
];

async function createDemoGoals() {
  try {
    console.log('Demo hedefler oluşturuluyor...');
    
    // Önce mevcut hedefleri temizle
    await Goal.deleteMany({ owner: childUserId });
    console.log('Mevcut hedefler temizlendi');
    
    // Yeni hedefleri oluştur
    for (const goalData of demoGoals) {
      const goal = new Goal(goalData);
      await goal.save();
      console.log(`Hedef oluşturuldu: ${goal.name} - ${goal.currentAmount}₺/${goal.targetAmount}₺`);
    }
    
    console.log('Tüm demo hedefler başarıyla oluşturuldu!');
    console.log('Çocuk uygulamasında hot reload yapın.');
    
  } catch (error) {
    console.error('Hata:', error);
  } finally {
    mongoose.connection.close();
  }
}

createDemoGoals(); 