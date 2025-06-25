import mongoose from 'mongoose';

const accountSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  type: {
    type: String,
    enum: ['main', 'savings', 'piggy'],
    default: 'piggy',
  },
  balance: {
    type: Number,
    default: 0,
  },
  currency: {
    type: String,
    default: 'TRY',
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  description: {
    type: String,
    trim: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  parentAccount: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    default: null,
  },
  targetAmount: {
    type: Number,
    default: 0,
  },
  savingsRate: {
    type: Number,
    default: 0, // Yüzde olarak (örn: 10 = %10)
  },
  icon: {
    type: String,
    default: 'wallet',
  },
  color: {
    type: String,
    default: '#000000',
  },
  linkedUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

// Bakiye güncelleme metodu
accountSchema.methods.updateBalance = async function (amount) {
  this.balance += amount;
  this.updatedAt = new Date();
  await this.save();
  
  // Eğer bu hesap bir çocuk kullanıcısının bağlı hesabıysa ve para eklendiyse
  // otomatik olarak hedeflere dağıt
  if (amount > 0 && this.linkedUserId) {
    try {
      await this.distributeToGoals(amount);
    } catch (error) {
      console.error('Hedef dağıtımı hatası:', error.message);
      // Hata olsa bile ana işlem devam etsin
    }
  }
  
  return this.balance;
};

// Otomatik hedef dağıtımı metodu (gelişmiş öncelik sistemi ile)
accountSchema.methods.distributeToGoals = async function (amount) {
  const { Goal } = await import('./Goal.js');
  
  console.log(`Distributing ${amount}₺ to goals for user ${this.linkedUserId}`);
  
  // Çocuk kullanıcısının aktif hedeflerini getir
  const goals = await Goal.find({
    owner: this.linkedUserId,
    status: 'active',
    isVisible: true
  }).sort({ priority: 1, createdAt: 1 });
  
  if (goals.length === 0) {
    console.log('No active goals found for distribution');
    return;
  }
  
  console.log(`Found ${goals.length} active goals`);
  
  // Gelişmiş öncelik sistemi ile dağıtım
  return await this.distributeByAdvancedPriority(amount, goals);
};

// Gelişmiş öncelik sistemi ile para dağıtımı
accountSchema.methods.distributeByAdvancedPriority = async function(totalAmount, goals) {
  // Öncelik gruplarına ayır (1=en yüksek öncelik)
  const priorityGroups = {};
  goals.forEach(goal => {
    if (!priorityGroups[goal.priority]) {
      priorityGroups[goal.priority] = [];
    }
    priorityGroups[goal.priority].push(goal);
  });

  // Öncelik sırasını al (1, 2, 3, ...)
  const priorities = Object.keys(priorityGroups).map(Number).sort();
  
  let remainingAmount = totalAmount;
  const distributions = [];

  console.log(`Öncelik seviyeleri: ${priorities.join(', ')}`);

  // Her öncelik seviyesini işle
  for (const priority of priorities) {
    if (remainingAmount <= 0) break;
    
    const groupGoals = priorityGroups[priority];
    
    // Bu gruptaki hedeflerin kalan ihtiyaçlarını hesapla
    const groupRemaining = groupGoals.reduce((sum, goal) => {
      const goalNeed = Math.max(0, goal.targetAmount - goal.currentAmount);
      return sum + goalNeed;
    }, 0);
    
    if (groupRemaining === 0) {
      console.log(`Öncelik ${priority}: Tüm hedefler dolu, sonrakine geçiliyor`);
      continue; // Bu grup dolu, sonrakine geç
    }
    
    // Bu gruba verilecek maksimum miktar
    const amountForThisGroup = Math.min(remainingAmount, groupRemaining);
    
    console.log(`Öncelik ${priority}: ${groupGoals.length} hedef, ${amountForThisGroup}₺ dağıtılacak`);
    
    // Aynı önceliktekilere eşit oranda dağıt
    for (const goal of groupGoals) {
      const goalNeed = Math.max(0, goal.targetAmount - goal.currentAmount);
      
      if (goalNeed > 0) {
        // Bu hedefe düşen pay
        const goalRatio = goalNeed / groupRemaining;
        const goalAmount = Math.min(
          Math.floor(amountForThisGroup * goalRatio),
          goalNeed,
          remainingAmount
        );
        
        if (goalAmount > 0) {
          goal.currentAmount += goalAmount;
          remainingAmount -= goalAmount;
          
          // Hedef tamamlandıysa durumu güncelle
          if (goal.currentAmount >= goal.targetAmount) {
            goal.status = 'completed';
            goal.completedAt = new Date();
          }
          
          goal.updatedAt = new Date();
          await goal.save();
          
          distributions.push({
            goalId: goal._id,
            goalName: goal.name,
            distributedAmount: goalAmount,
            newTotal: goal.currentAmount,
            priority: goal.priority,
            progress: Math.round((goal.currentAmount / goal.targetAmount) * 100)
          });
          
          console.log(`Distributed ${goalAmount}₺ to ${goal.name} (${goal.currentAmount}/${goal.targetAmount}) [P${goal.priority}]`);
        }
      }
    }
  }
  
  console.log(`Distribution completed. Total distributed: ${totalAmount - remainingAmount}₺`);
  return distributions;
};

// Para aktarma metodu
accountSchema.methods.transfer = async function (targetAccount, amount) {
  if (this.balance < amount) {
    throw new Error('Yetersiz bakiye');
  }
  
  // Kaynak hesaptan düş
  await this.updateBalance(-amount);
  
  // Hedef hesaba ekle
  await targetAccount.updateBalance(amount);
  
  return {
    sourceBalance: this.balance,
    targetBalance: targetAccount.balance,
  };
};

// Hesap bilgilerini güncelleme metodu
accountSchema.methods.updateDetails = async function (details) {
  Object.assign(this, details);
  this.updatedAt = new Date();
  await this.save();
  return this;
};

const Account = mongoose.model('Account', accountSchema);

export { Account }; 