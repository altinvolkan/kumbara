import express from 'express';
import { User } from '../models/User.js';
import { Device } from '../models/Device.js';
import { Transaction } from '../models/Transaction.js';
import { Goal } from '../models/Goal.js';
import { Account } from '../models/Account.js';
import { authMiddleware } from '../middleware/auth.js';

const router = express.Router();

// Hesap özeti
router.get('/summary', authMiddleware, async (req, res) => {
  try {
    // Kullanıcının hesaplarını getir
    const accounts = await Account.find({ owner: req.user._id, isActive: true });
    
    // Hesaplar için istatistikleri hesapla
    const accountStats = accounts.map(account => ({
      accountId: account._id,
      accountName: account.name,
      accountType: account.type,
      balance: account.balance,
      currency: account.currency,
      icon: account.icon,
      color: account.color
    }));
    
    // Genel istatistikler
    const totalBalance = accounts.reduce((sum, acc) => sum + acc.balance, 0);
    const totalAccounts = accounts.length;
    
    res.json({
      accounts: accountStats,
      summary: {
        totalBalance,
        totalAccounts,
        currency: 'TRY',
        lastUpdate: new Date()
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Hesap geçmişi
router.get('/history', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate, type } = req.query;
    
    // Kullanıcının cihazlarını bul
    const devices = await Device.find({ userId });
    const deviceIds = devices.map(d => d._id);
    
    // Filtreleme kriterleri
    const filter = { deviceId: { $in: deviceIds } };
    if (startDate || endDate) {
      filter.createdAt = {};
      if (startDate) filter.createdAt.$gte = new Date(startDate);
      if (endDate) filter.createdAt.$lte = new Date(endDate);
    }
    if (type) filter.type = type;
    
    // İşlemleri getir
    const transactions = await Transaction.find(filter)
      .sort({ createdAt: -1 })
      .populate('deviceId', 'name')
      .populate('goalId', 'name');
    
    res.json(transactions);
  } catch (error) {
    next(error);
  }
});

// Hesap istatistikleri
router.get('/stats', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { period } = req.query; // daily, weekly, monthly, yearly
    
    // Kullanıcının cihazlarını bul
    const devices = await Device.find({ userId });
    const deviceIds = devices.map(d => d._id);
    
    // Tarih aralığını belirle
    const now = new Date();
    let startDate;
    switch (period) {
      case 'daily':
        startDate = new Date(now.setHours(0, 0, 0, 0));
        break;
      case 'weekly':
        startDate = new Date(now.setDate(now.getDate() - 7));
        break;
      case 'monthly':
        startDate = new Date(now.setDate(1));
        break;
      case 'yearly':
        startDate = new Date(now.setMonth(0, 1));
        break;
      default:
        startDate = new Date(now.setDate(now.getDate() - 30)); // Varsayılan: son 30 gün
    }
    
    // İşlemleri getir
    const transactions = await Transaction.find({
      deviceId: { $in: deviceIds },
      createdAt: { $gte: startDate }
    });
    
    // İstatistikleri hesapla
    const stats = {
      totalDeposits: 0,
      totalWithdrawals: 0,
      netAmount: 0,
      transactionCount: transactions.length,
      byDevice: {},
      byType: {
        deposit: 0,
        withdrawal: 0,
        goal: 0
      }
    };
    
    transactions.forEach(t => {
      // Genel toplamlar
      if (t.type === 'deposit') {
        stats.totalDeposits += t.amount;
        stats.byType.deposit += t.amount;
      } else {
        stats.totalWithdrawals += t.amount;
        stats.byType.withdrawal += t.amount;
      }
      
      // Cihaz bazlı istatistikler
      const deviceId = t.deviceId.toString();
      if (!stats.byDevice[deviceId]) {
        stats.byDevice[deviceId] = {
          totalDeposits: 0,
          totalWithdrawals: 0,
          transactionCount: 0
        };
      }
      
      if (t.type === 'deposit') {
        stats.byDevice[deviceId].totalDeposits += t.amount;
      } else {
        stats.byDevice[deviceId].totalWithdrawals += t.amount;
      }
      stats.byDevice[deviceId].transactionCount++;
    });
    
    stats.netAmount = stats.totalDeposits - stats.totalWithdrawals;
    
    res.json(stats);
  } catch (error) {
    next(error);
  }
});

// Tüm hesapları getir
router.get('/', authMiddleware, async (req, res) => {
  try {
    const accounts = await Account.find({ owner: req.user._id, isActive: true });
    const transformedAccounts = accounts.map(acc => ({
      id: acc._id.toString(),
      name: acc.name,
      type: acc.type,
      balance: acc.balance,
      currency: acc.currency,
      owner: acc.owner.toString(),
      description: acc.description,
      isActive: acc.isActive,
      icon: acc.icon,
      color: acc.color,
      createdAt: acc.createdAt,
      updatedAt: acc.updatedAt
    }));
    res.json(transformedAccounts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Çocuk kullanıcısının bağlı hesabını getir - ÖNEMLİ: /:id'den önce olmalı!
router.get('/linked', authMiddleware, async (req, res) => {
  try {
    console.log('GET /accounts/linked - User ID:', req.user._id);
    console.log('User role:', req.user.role);
    
    // Sadece çocuk kullanıcılar için
    if (req.user.role !== 'child') {
      return res.status(403).json({ error: 'Bu endpoint sadece çocuk kullanıcılar için' });
    }

    // Çocuk kullanıcısının linked account ID'sini bul
    const linkedAccountId = req.user.linkedAccount;
    console.log('Linked account ID:', linkedAccountId);
    
    if (!linkedAccountId) {
      return res.status(404).json({ error: 'Bağlı hesap bulunamadı' });
    }

    // Hesap bilgilerini getir
    const account = await Account.findById(linkedAccountId);
    console.log('Found account:', account);
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }

    res.json({
      id: account._id,
      name: account.name,
      type: account.type,
      balance: account.balance,
      currency: account.currency || 'TRY',
      icon: account.icon,
      color: account.color
    });
  } catch (error) {
    console.error('Error in /accounts/linked:', error);
    res.status(500).json({ error: error.message });
  }
});

// Yeni hesap oluştur
router.post('/', authMiddleware, async (req, res) => {
  try {
    const accountData = {
      ...req.body,
      owner: req.user._id  // Use authenticated user's ID
    };
    
    const account = new Account(accountData);
    await account.save();
    
    // Transform response for frontend
    const transformedAccount = {
      id: account._id.toString(),
      name: account.name,
      type: account.type,
      balance: account.balance,
      currency: account.currency,
      owner: account.owner.toString(),
      description: account.description,
      isActive: account.isActive,
      icon: account.icon,
      color: account.color,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt
    };
    
    res.status(201).json(transformedAccount);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hesap detaylarını getir
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const account = await Account.findOne({
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    res.json(account);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Hesap bilgilerini güncelle
router.patch('/:id', authMiddleware, async (req, res) => {
  const updates = Object.keys(req.body);
  const allowedUpdates = ['name', 'type', 'description', 'icon', 'color'];
  const isValidOperation = updates.every(update => allowedUpdates.includes(update));
  
  if (!isValidOperation) {
    return res.status(400).json({ error: 'Geçersiz güncelleme' });
  }
  
  try {
    const account = await Account.findOne({
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    await account.updateDetails(req.body);
    res.json(account);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hesabı sil (soft delete)
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const account = await Account.findOne({
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    account.isActive = false;
    await account.save();
    
    res.json({ message: 'Hesap başarıyla silindi' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Hesap bakiyesini güncelle
router.post('/:id/balance', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    if (typeof amount !== 'number') {
      return res.status(400).json({ error: 'Geçersiz miktar' });
    }
    
    const account = await Account.findOne({
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    const newBalance = await account.updateBalance(amount);
    res.json({ balance: newBalance });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Para yatır (hesap ID ile)
router.post('/:id/deposit', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    const account = await Account.findOne({ 
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    await account.updateBalance(amount);
    
    res.json({
      balance: account.balance,
      currency: account.currency
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Para çek (hesap ID ile)
router.post('/:id/withdraw', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    const account = await Account.findOne({ 
      _id: req.params.id,
      owner: req.user._id
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    if (account.balance < amount) {
      return res.status(400).json({ error: 'Yetersiz bakiye' });
    }
    
    await account.updateBalance(-amount);
    
    res.json({
      balance: account.balance,
      currency: account.currency
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Para transferi
router.post('/transfer', authMiddleware, async (req, res) => {
  try {
    const { fromAccountId, toAccountId, amount } = req.body;
    
    // Kaynak hesabı bul
    const fromAccount = await Account.findOne({ 
      _id: fromAccountId,
      owner: req.user._id
    });
    
    if (!fromAccount) {
      return res.status(404).json({ error: 'Kaynak hesap bulunamadı' });
    }
    
    // Hedef hesabı bul
    const toAccount = await Account.findOne({ 
      _id: toAccountId,
      owner: req.user._id
    });
    
    if (!toAccount) {
      return res.status(404).json({ error: 'Hedef hesap bulunamadı' });
    }
    
    // Bakiye kontrolü
    if (fromAccount.balance < amount) {
      return res.status(400).json({ error: 'Yetersiz bakiye' });
    }
    
    // Transfer yap - updateBalance kullanarak otomatik dağıtımı tetikle
    await fromAccount.updateBalance(-amount);
    await toAccount.updateBalance(amount);
    
    res.json({
      fromBalance: fromAccount.balance,
      toBalance: toAccount.balance,
      message: 'Transfer başarılı'
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Hesaptan hedefe manuel para aktarımı
router.post('/transfer-to-goal', authMiddleware, async (req, res) => {
  try {
    const { goalId, amount } = req.body;
    
    console.log(`Manuel transfer: ${amount}₺ hedefe aktarılıyor (Goal ID: ${goalId})`);
    
    if (!goalId || !amount || amount <= 0) {
      return res.status(400).json({ error: 'Geçersiz parametreler' });
    }
    
    // Hedefi bul ve sahipliğini kontrol et
    const goal = await Goal.findOne({
      _id: goalId,
      owner: req.user._id,
      status: 'active'
    });
    
    if (!goal) {
      return res.status(404).json({ error: 'Hedef bulunamadı veya aktif değil' });
    }
    
    // Kullanıcının bağlı hesabını bul
    let linkedAccount;
    if (req.user.role === 'child') {
      // Çocuk kullanıcıysa linkedAccount field'ından bul
      linkedAccount = await Account.findOne({
        _id: req.user.linkedAccount,
        isActive: true
      });
    } else {
      // Ebeveyn kullanıcıysa kendi hesaplarından birini al
      linkedAccount = await Account.findOne({
        owner: req.user._id,
        isActive: true
      });
    }
    
    if (!linkedAccount) {
      return res.status(404).json({ error: 'Bağlı hesap bulunamadı' });
    }
    
    // Bakiye kontrolü
    if (linkedAccount.balance < amount) {
      return res.status(400).json({ error: 'Yetersiz bakiye' });
    }
    
    // Hedefin mevcut durumu
    const currentAmount = goal.currentAmount;
    const targetAmount = goal.targetAmount;
    const remainingAmount = targetAmount - currentAmount;
    
    // Aktarılacak miktarı hedefin kalan miktarı ile sınırla
    const transferAmount = Math.min(amount, remainingAmount);
    
    // Hesaptan parayı çık
    await linkedAccount.updateBalance(-transferAmount);
    
    // Hedefe parayı ekle
    goal.currentAmount += transferAmount;
    
    // Hedef tamamlandıysa durumu güncelle
    if (goal.currentAmount >= goal.targetAmount) {
      goal.status = 'completed';
      goal.completedAt = new Date();
      console.log(`Hedef tamamlandı: ${goal.name}`);
    }
    
    await goal.save();
    
    console.log(`Transfer başarılı: ${transferAmount}₺ aktarıldı`);
    console.log(`Hedef durumu: ${goal.currentAmount}/${goal.targetAmount}₺`);
    console.log(`Hesap bakiyesi: ${linkedAccount.balance}₺`);
    
    res.json({
      success: true,
      transferAmount,
      goalProgress: {
        currentAmount: goal.currentAmount,
        targetAmount: goal.targetAmount,
        percentage: (goal.currentAmount / goal.targetAmount) * 100,
        isCompleted: goal.status === 'completed'
      },
      accountBalance: linkedAccount.balance,
      message: transferAmount < amount ? 
        `${transferAmount}₺ aktarıldı (hedef tamamlandı)` : 
        `${transferAmount}₺ hedefe aktarıldı`
    });
  } catch (error) {
    console.error('Transfer-to-goal hatası:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router; 