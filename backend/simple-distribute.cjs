const { MongoClient, ObjectId } = require('mongodb');

const url = 'mongodb://localhost:27017';
const client = new MongoClient(url);

async function simpleDistribute() {
  try {
    await client.connect();
    
    const db = client.db('kumbara');
    
    // Direkt hedefleri bul ve güncelle
    const goals = await db.collection('goals').find({
      name: { $in: ['abc', 'patates'] }
    }).toArray();
    
    console.log('Bulunan hedefler:', goals.length);
    
    for (const goal of goals) {
      console.log(`- ${goal.name}: ${goal.currentAmount}/${goal.targetAmount}₺`);
      
      // abc'ye 500₺, patates'e 4500₺ ver
      let amount = 0;
      if (goal.name === 'abc') {
        amount = 500; // Tamamını ver
      } else if (goal.name === 'patates') {
        amount = 4500; // Bir kısmını ver
      }
      
      if (amount > 0) {
        await db.collection('goals').updateOne(
          { _id: goal._id },
          { 
            $set: { 
              currentAmount: amount,
              updatedAt: new Date(),
              status: amount >= goal.targetAmount ? 'completed' : 'active'
            }
          }
        );
        console.log(`  ✅ ${goal.name} güncellendi: ${amount}₺`);
      }
    }
    
    // Hesap bakiyesini düşür
    await db.collection('accounts').updateOne(
      { _id: new ObjectId('685bba3aadcfbbf856613ed3') },
      { 
        $set: { 
          balance: 3000, // 8000 - 5000 = 3000₺ kalan
          updatedAt: new Date()
        }
      }
    );
    
    console.log('\n✅ Para dağıtımı tamamlandı!');
    console.log('- abc: 500/500₺ (Tamamlandı!)');
    console.log('- patates: 4500/5000₺ (%90)');
    console.log('- Kalan bakiye: 3000₺');
    
  } catch (error) {
    console.error('Hata:', error);
  } finally {
    await client.close();
  }
}

simpleDistribute(); 