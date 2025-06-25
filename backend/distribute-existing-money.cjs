const { MongoClient, ObjectId } = require('mongodb');

const url = 'mongodb://localhost:27017';
const client = new MongoClient(url);

async function distributeExistingMoney() {
  try {
    await client.connect();
    console.log('MongoDB bağlantısı başarılı');
    
    const db = client.db('kumbara');
    
    // Hesabı bul
    const account = await db.collection('accounts').findOne({
      _id: new ObjectId('685bba3aadcfbbf856613ed3')
    });
    
    if (!account) {
      console.log('Hesap bulunamadı');
      return;
    }
    
    console.log(`Mevcut bakiye: ${account.balance}₺`);
    
    // Aktif hedefleri bul
    const goals = await db.collection('goals').find({
      owner: new ObjectId('685bb786f97eee0396b2b089'),
      status: 'active',
      isVisible: true
    }).sort({ priority: 1, createdAt: 1 }).toArray();
    
    console.log(`Bulunan hedefler: ${goals.length}`);
    goals.forEach(goal => {
      console.log(`- ${goal.name}: ${goal.currentAmount}/${goal.targetAmount}₺ (Öncelik: ${goal.priority || 'belirsiz'})`);
    });
    
    if (goals.length === 0) {
      console.log('Dağıtım yapılacak hedef yok');
      return;
    }
    
    // Toplam ihtiyaç hesapla
    const totalNeed = goals.reduce((sum, goal) => {
      return sum + Math.max(0, goal.targetAmount - goal.currentAmount);
    }, 0);
    
    console.log(`Toplam hedef ihtiyacı: ${totalNeed}₺`);
    
    const availableMoney = account.balance;
    
    if (availableMoney <= 0) {
      console.log('Dağıtılacak para yok');
      return;
    }
    
    // Para dağıtımı yap
    console.log(`\n${availableMoney}₺ dağıtılıyor...`);
    
    let remainingMoney = availableMoney;
    const distributions = [];
    
    // Öncelik gruplarına ayır
    const priorityGroups = {};
    goals.forEach(goal => {
      const priority = goal.priority || 5; // Varsayılan öncelik
      if (!priorityGroups[priority]) {
        priorityGroups[priority] = [];
      }
      priorityGroups[priority].push(goal);
    });
    
    // Öncelik sırasına göre dağıt
    const priorities = Object.keys(priorityGroups).map(Number).sort();
    
    for (const priority of priorities) {
      if (remainingMoney <= 0) break;
      
      const groupGoals = priorityGroups[priority];
      
      // Bu gruptaki toplam ihtiyaç
      const groupNeed = groupGoals.reduce((sum, goal) => {
        return sum + Math.max(0, goal.targetAmount - goal.currentAmount);
      }, 0);
      
      if (groupNeed === 0) continue;
      
      // Bu gruba verilecek miktar
      const amountForGroup = Math.min(remainingMoney, groupNeed);
      
      console.log(`\nÖncelik ${priority} grubu: ${groupGoals.length} hedef, ${amountForGroup}₺ dağıtılacak`);
      
      // Grup içinde eşit oranda dağıt
      for (const goal of groupGoals) {
        const goalNeed = Math.max(0, goal.targetAmount - goal.currentAmount);
        
        if (goalNeed > 0) {
          const goalRatio = goalNeed / groupNeed;
          const goalAmount = Math.min(
            Math.floor(amountForGroup * goalRatio),
            goalNeed,
            remainingMoney
          );
          
          if (goalAmount > 0) {
            // Hedefi güncelle
            await db.collection('goals').updateOne(
              { _id: goal._id },
              { 
                $inc: { currentAmount: goalAmount },
                $set: { 
                  updatedAt: new Date(),
                  status: (goal.currentAmount + goalAmount) >= goal.targetAmount ? 'completed' : 'active'
                }
              }
            );
            
            remainingMoney -= goalAmount;
            distributions.push({
              goalName: goal.name,
              amount: goalAmount,
              newTotal: goal.currentAmount + goalAmount,
              targetAmount: goal.targetAmount
            });
            
            console.log(`  ${goal.name}: +${goalAmount}₺ → ${goal.currentAmount + goalAmount}/${goal.targetAmount}₺`);
          }
        }
      }
    }
    
    // Hesap bakiyesini güncelle (0'a çek)
    await db.collection('accounts').updateOne(
      { _id: account._id },
      { 
        $set: { 
          balance: remainingMoney,
          updatedAt: new Date()
        }
      }
    );
    
    console.log(`\n✅ DAĞITIM TAMAMLANDI:`);
    console.log(`- Dağıtılan toplam: ${availableMoney - remainingMoney}₺`);
    console.log(`- Kalan bakiye: ${remainingMoney}₺`);
    
    distributions.forEach(d => {
      const percentage = ((d.newTotal / d.targetAmount) * 100).toFixed(1);
      console.log(`- ${d.goalName}: +${d.amount}₺ (${d.newTotal}/${d.targetAmount}₺ - %${percentage})`);
    });
    
  } catch (error) {
    console.error('Hata:', error);
  } finally {
    await client.close();
  }
}

distributeExistingMoney(); 