const { MongoClient, ObjectId } = require('mongodb');

const url = 'mongodb://localhost:27017';
const client = new MongoClient(url);

async function checkGoals() {
  try {
    await client.connect();
    console.log('MongoDB bağlantısı başarılı');
    
    const db = client.db('kumbara');
    
    // Tüm kullanıcıları listele
    console.log('\n=== KULLANICILAR ===');
    const users = await db.collection('users').find({}).toArray();
    users.forEach(user => {
      console.log(`- ${user.name} (${user.email}) - ID: ${user._id} - Role: ${user.role}`);
    });
    
    // Tüm hesapları listele
    console.log('\n=== HESAPLAR ===');
    const accounts = await db.collection('accounts').find({}).toArray();
    accounts.forEach(account => {
      console.log(`- ${account.name}: ${account.balance}₺ - Owner: ${account.owner}`);
    });
    
    // Tüm hedefleri listele
    console.log('\n=== TÜM HEDEFLER ===');
    const allGoals = await db.collection('goals').find({}).toArray();
    allGoals.forEach(goal => {
      console.log(`- ${goal.name}: ${goal.currentAmount}/${goal.targetAmount}₺ - Owner: ${goal.owner} - Status: ${goal.status} - Visible: ${goal.isVisible}`);
    });
    
    // Çocuk kullanıcı ID'si
    const childUserId = new ObjectId('685bbdee3d73bef485bd2791');
    const childUser = await db.collection('users').findOne({ _id: childUserId });
    
    if (childUser) {
      console.log(`\n=== ÇOCUK KULLANICI: ${childUser.name} ===`);
      console.log(`Parent ID: ${childUser.parent}`);
      console.log(`Linked Account: ${childUser.linkedAccount}`);
      
      // Bu çocuk için hedefler (parent owner olarak)
      const parentGoals = await db.collection('goals').find({
        owner: childUser.parent,
        status: 'active',
        isVisible: true
      }).toArray();
      
      console.log(`\nParent ID ile hedefler (${childUser.parent}):`);
      parentGoals.forEach(goal => {
        console.log(`- ${goal.name}: ${goal.currentAmount}/${goal.targetAmount}₺ - Öncelik: ${goal.priority || 'yok'}`);
      });
    }
    
  } catch (error) {
    console.error('Hata:', error);
  } finally {
    await client.close();
  }
}

checkGoals(); 