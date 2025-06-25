import express from 'express';
import { Device } from '../models/Device.js';
import { Goal } from '../models/Goal.js';
import { authMiddleware } from '../middleware/auth.js';

const router = express.Router();

// Sadece görünür hedefler - ÖNEMLİ: Bu route /:id'den önce olmalı!
router.get('/visible', authMiddleware, async (req, res) => {
  try {
    console.log('GET /goals/visible - User ID:', req.user._id);
    
    const goals = await Goal.find({ 
      owner: req.user._id, 
      isVisible: true,
      status: 'active'
    }).sort({ priority: 1, createdAt: -1 });
    
    console.log('Found goals:', goals.length);
    console.log('Goals:', goals.map(g => `${g.name} (${g.currentAmount}/${g.targetAmount})`));
    
    res.json(goals);
  } catch (error) {
    console.error('Error in /goals/visible:', error);
    res.status(500).json({ error: error.message });
  }
});

// Paralel hedefler
router.get('/parallel', authMiddleware, async (req, res) => {
  try {
    const goals = await Goal.find({ 
      owner: req.user._id, 
      isParallel: true,
      status: 'active'
    }).sort({ priority: 1 });
    res.json(goals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Tamamlanan hedefleri getir
router.get('/completed', authMiddleware, async (req, res) => {
  try {
    console.log('GET /goals/completed - User ID:', req.user._id);
    
    const goals = await Goal.find({
      owner: req.user._id,
      status: 'completed'
    }).sort({ completedAt: -1, updatedAt: -1 });
    
    console.log('Found completed goals:', goals.length);
    console.log('Completed goals:', goals.map(g => `${g.name} (${g.currentAmount}/${g.targetAmount})`));
    
    res.json(goals);
  } catch (error) {
    console.error('Error in /goals/completed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Hedef listesi
router.get('/', authMiddleware, async (req, res) => {
  try {
    const goals = await Goal.find({ owner: req.user._id })
      .sort({ priority: 1, createdAt: -1 });
    res.json(goals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Yeni hedef oluştur
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { name, targetAmount, description, icon, targetDate, priority, isVisible, isParallel, color, category } = req.body;
    
    if (!name || !targetAmount) {
      return res.status(400).json({ error: 'Eksik bilgi' });
    }
    
    const goal = new Goal({
      owner: req.user._id,
      name,
      targetAmount,
      currentAmount: 0,
      description,
      icon,
      status: 'active',
      targetDate,
      priority: priority || 1,
      isVisible: isVisible !== undefined ? isVisible : true,
      isParallel: isParallel || false,
      color: color || '#2196F3',
      category: category || 'other',
    });
    
    await goal.save();
    res.status(201).json(goal);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hedef önceliklerini güncelle (sürükle-bırak için)
router.put('/reorder', authMiddleware, async (req, res) => {
  try {
    const { goalOrders } = req.body; // [{ id, priority }, ...]
    
    if (!Array.isArray(goalOrders)) {
      return res.status(400).json({ error: 'goalOrders array gerekli' });
    }
    
    const updates = goalOrders.map(({ id, priority }) => 
      Goal.updateOne(
        { _id: id, owner: req.user._id },
        { priority, updatedAt: new Date() }
      )
    );
    
    await Promise.all(updates);
    
    const updatedGoals = await Goal.find({ owner: req.user._id })
      .sort({ priority: 1, createdAt: -1 });
    
    res.json(updatedGoals);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hedef detayları
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const goal = await Goal.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı' });
    }
    
    res.json(goal);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Hedef durumunu güncelle
router.patch('/:id/status', authMiddleware, async (req, res) => {
  try {
    const { status } = req.body;
    
    if (!['active', 'paused', 'completed'].includes(status)) {
      return res.status(400).json({ error: 'Geçersiz durum' });
    }
    
    const goal = await Goal.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı' });
    }
    
    goal.status = status;
    await goal.save();
    
    res.json(goal);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hedefe katkı ekle
router.post('/:id/contribute', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Geçersiz miktar' });
    }
    
    const goal = await Goal.findOne({
      _id: req.params.id,
      owner: req.user._id,
      status: 'active',
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı veya aktif değil' });
    }
    
    goal.currentAmount += amount;
    
    // Hedef tamamlandıysa durumu güncelle
    if (goal.currentAmount >= goal.targetAmount) {
      goal.status = 'completed';
    }
    
    await goal.save();
    res.json(goal);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Paralel hedef dağıtımı (yeni para eklendiğinde)
router.post('/distribute', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Geçersiz miktar' });
    }
    
    // Paralel hedefleri getir
    const parallelGoals = await Goal.find({
      owner: req.user._id,
      isParallel: true,
      status: 'active'
    }).sort({ priority: 1 });
    
    if (parallelGoals.length === 0) {
      return res.status(400).json({ error: 'Paralel hedef bulunamadı' });
    }
    
    // Toplam kalan miktar hesapla
    const totalRemaining = parallelGoals.reduce((sum, goal) => {
      return sum + Math.max(0, goal.targetAmount - goal.currentAmount);
    }, 0);
    
    if (totalRemaining === 0) {
      return res.status(400).json({ error: 'Tüm paralel hedefler tamamlanmış' });
    }
    
    const distributions = [];
    let remainingAmount = amount;
    
    // Öncelik sırasına göre dağıt
    for (let i = 0; i < parallelGoals.length && remainingAmount > 0; i++) {
      const goal = parallelGoals[i];
      const goalRemaining = goal.targetAmount - goal.currentAmount;
      
      if (goalRemaining > 0) {
        const goalWeight = goalRemaining / totalRemaining;
        const distributedAmount = Math.min(
          Math.round(amount * goalWeight),
          goalRemaining,
          remainingAmount
        );
        
        if (distributedAmount > 0) {
          goal.currentAmount += distributedAmount;
          remainingAmount -= distributedAmount;
          
          // Hedef tamamlandıysa durumu güncelle
          if (goal.currentAmount >= goal.targetAmount) {
            goal.status = 'completed';
          }
          
          await goal.save();
          distributions.push({
            goalId: goal._id,
            goalName: goal.name,
            distributedAmount,
            newTotal: goal.currentAmount,
            progress: (goal.currentAmount / goal.targetAmount) * 100
          });
        }
      }
    }
    
    res.json({
      totalDistributed: amount - remainingAmount,
      remaining: remainingAmount,
      distributions
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hedefi sil ve parasını diğer hedeflere dağıt
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const goal = await Goal.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı' });
    }

    const goalMoney = goal.currentAmount;
    console.log(`Hedef siliniyor: ${goal.name} (${goalMoney}₺ var)`);

    // Diğer aktif hedefleri bul
    const otherGoals = await Goal.find({
      _id: { $ne: goal._id }, // Bu hedefe eşit olmayanlar
      owner: req.user._id,
      status: 'active',
      isVisible: true
    }).sort({ priority: 1, createdAt: 1 });

    // Hedefe ait parayı diğer aktif hedeflere redistribute et
    if (goalMoney > 0 && otherGoals.length > 0) {
      console.log(`${goalMoney}₺ ${otherGoals.length} hedefe dağıtılacak`);
      
      // Gelişmiş öncelik sistemi ile dağıtım
      const redistributed = await redistributeByPriority(goalMoney, otherGoals);
      
      console.log('Redistribüsyon tamamlandı:', redistributed.map(r => 
        `${r.goalName}: +${r.amount}₺`
      ));
    } else if (goalMoney > 0) {
      console.log('Dağıtım yapılacak başka hedef yok, para kaybolacak');
    }

    // Hedefi sil
    await Goal.findByIdAndDelete(req.params.id);
    
    res.json({ 
      message: 'Hedef başarıyla silindi',
      redistributedAmount: goalMoney,
      redistributedTo: otherGoals.length
    });
  } catch (error) {
    console.error('Hedef silme hatası:', error);
    res.status(500).json({ error: error.message });
  }
});

// Hedefi güncelle
router.patch('/:id', authMiddleware, async (req, res) => {
  try {
    const goal = await Goal.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı' });
    }

    const allowedUpdates = ['name', 'description', 'targetAmount', 'icon', 'color', 'category', 'targetDate', 'priority', 'isVisible', 'isParallel'];
    const updates = {};
    
    for (const key of allowedUpdates) {
      if (req.body[key] !== undefined) {
        updates[key] = req.body[key];
      }
    }
    
    updates.updatedAt = new Date();
    
    Object.assign(goal, updates);
    await goal.save();
    
    res.json(goal);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Gelişmiş öncelik sistemi ile para dağıtımı
async function redistributeByPriority(totalAmount, goals) {
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
  const redistributions = [];

  // Her öncelik seviyesini işle
  for (const priority of priorities) {
    if (remainingAmount <= 0) break;
    
    const groupGoals = priorityGroups[priority];
    
    // Bu gruptaki hedeflerin kalan ihtiyaçlarını hesapla
    const groupRemaining = groupGoals.reduce((sum, goal) => {
      const goalNeed = Math.max(0, goal.targetAmount - goal.currentAmount);
      return sum + goalNeed;
    }, 0);
    
    if (groupRemaining === 0) continue; // Bu grup dolu, sonrakine geç
    
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
          
          redistributions.push({
            goalId: goal._id,
            goalName: goal.name,
            amount: goalAmount,
            newTotal: goal.currentAmount,
            priority: goal.priority
          });
          
          console.log(`  ${goal.name}: +${goalAmount}₺ (${goal.currentAmount}/${goal.targetAmount})`);
        }
      }
    }
  }
  
  console.log(`Redistribüsyon tamamlandı. Kalan: ${remainingAmount}₺`);
  return redistributions;
}

export default router; 