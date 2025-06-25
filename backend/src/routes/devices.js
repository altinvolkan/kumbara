import express from 'express';
import { Device } from '../models/Device.js';
import { Transaction } from '../models/Transaction.js';
import { Account } from '../models/Account.js';
import { authMiddleware } from '../middleware/auth.js';
import mongoose from 'mongoose';

const router = express.Router();

// Yeni cihaz oluştur
router.post('/', async (req, res) => {
  try {
    const { name } = req.body;
    const device = await Device.createNew(req.user._id, name);
    
    res.status(201).json({
      device: {
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        pairingCode: device.pairingCode,
        isPaired: device.isPaired,
        status: device.status,
        currentBalance: device.currentBalance,
        features: device.features,
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihazları listele
router.get('/', async (req, res) => {
  try {
    const devices = await Device.find({ owner: req.user._id });
    
    res.json({
      devices: devices.map(device => ({
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        isPaired: device.isPaired,
        status: device.status,
        batteryLevel: device.batteryLevel,
        firmwareVersion: device.firmwareVersion,
        lastSyncAt: device.lastSyncAt,
        currentBalance: device.currentBalance,
        features: device.features,
      })),
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihaz detayları
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const device = await Device.findOne({
      _id: req.params.id,
      owner: req.user._id,
    }).populate('linkedAccount', 'name type balance');
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    // Son işlemleri getir
    const transactions = await Transaction.find({ device: device._id })
      .sort({ createdAt: -1 })
      .limit(10);
    
    res.json({
      device: {
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        isPaired: device.isPaired,
        status: device.status,
        batteryLevel: device.batteryLevel,
        firmwareVersion: device.firmwareVersion,
        lastSyncAt: device.lastSyncAt,
        currentBalance: device.currentBalance,
        features: device.features,
        linkedAccount: device.linkedAccount ? {
          id: device.linkedAccount._id,
          name: device.linkedAccount.name,
          type: device.linkedAccount.type,
          balance: device.linkedAccount.balance,
        } : null,
      },
      recentTransactions: transactions.map(tx => ({
        id: tx._id,
        type: tx.type,
        amount: tx.amount,
        balance: tx.balance,
        description: tx.description,
        createdAt: tx.createdAt,
      })),
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihaz eşleştir
router.post('/:id/pair', async (req, res) => {
  try {
    const { code } = req.body;
    const device = await Device.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    await device.pair(code);
    
    res.json({
      device: {
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        isPaired: device.isPaired,
        status: device.status,
        lastPairedAt: device.lastPairedAt,
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihaz ayarlarını güncelle
router.patch('/:id/settings', async (req, res) => {
  try {
    const updates = Object.keys(req.body);
    const allowedUpdates = ['name', 'features'];
    const isValidOperation = updates.every(update => allowedUpdates.includes(update));
    
    if (!isValidOperation) {
      return res.status(400).json({ error: 'Geçersiz güncelleme alanları' });
    }
    
    const device = await Device.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    updates.forEach(update => {
      if (update === 'features') {
        device.features = { ...device.features, ...req.body.features };
      } else {
        device[update] = req.body[update];
      }
    });
    
    await device.save();
    
    res.json({
      device: {
        id: device._id,
        name: device.name,
        features: device.features,
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihaz durumunu güncelle (ESP32'den gelen istekler için)
router.post('/:deviceId/status', async (req, res) => {
  try {
    const { status, batteryLevel, balance } = req.body;
    const device = await Device.findOne({ deviceId: req.params.deviceId });
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    // ESP32'den gelen istekleri doğrula
    const esp32Secret = process.env.ESP32_SECRET;
    const requestSecret = req.header('X-ESP32-Secret');
    
    if (requestSecret !== esp32Secret) {
      return res.status(401).json({ error: 'Yetkisiz erişim' });
    }
    
    await device.updateStatus(status, batteryLevel);
    
    // Bakiye değişikliği varsa işlem oluştur
    if (balance !== undefined && balance !== device.currentBalance) {
      const amount = balance - device.currentBalance;
      await Transaction.createTransaction({
        device: device._id,
        type: amount > 0 ? 'deposit' : 'withdrawal',
        amount: Math.abs(amount),
        balance,
        description: 'Otomatik bakiye güncelleme',
      });
    }
    
    res.json({
      device: {
        id: device._id,
        status: device.status,
        batteryLevel: device.batteryLevel,
        currentBalance: device.currentBalance,
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Gerçek hesapları oluştur
router.post('/setup-accounts', async (req, res) => {
  try {
    // Önce mevcut cihazları sil
    await Device.deleteMany({ owner: req.user._id });
    
    // Gerçek hesapları oluştur
    const accounts = [
      { name: 'Mehmet Yılmaz', balance: 15000 },
      { name: 'Ali Yılmaz', balance: 15000 },
      { name: 'Ayşe Yılmaz', balance: 1800 }
    ];
    
    const createdDevices = [];
    for (const account of accounts) {
      const device = await Device.createNew(req.user._id, account.name);
      device.currentBalance = account.balance;
      await device.save();
      createdDevices.push(device);
    }
    
    res.json({ 
      message: `${createdDevices.length} hesap oluşturuldu`,
      devices: createdDevices 
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Tüm cihazları sil (temizlik için)
router.delete('/cleanup', async (req, res) => {
  try {
    const result = await Device.deleteMany({ owner: req.user._id });
    res.json({ message: `${result.deletedCount} cihaz silindi` });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihaza hesap bağla
router.post('/:id/link-account', authMiddleware, async (req, res) => {
  try {
    const { accountId } = req.body;
    
    const device = await Device.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    // Hesabın kullanıcıya ait olduğunu kontrol et
    const account = await Account.findOne({
      _id: accountId,
      owner: req.user._id,
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    if (account.type === 'main') {
      return res.status(400).json({ error: 'Ana hesap bağlanamaz' });
    }
    
    await device.linkAccount(accountId);
    
    res.json({
      device: {
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        linkedAccount: {
          id: account._id,
          name: account.name,
          type: account.type,
          balance: account.balance,
        },
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cihazdan hesap bağlantısını kaldır
router.delete('/:id/unlink-account', authMiddleware, async (req, res) => {
  try {
    const device = await Device.findOne({
      _id: req.params.id,
      owner: req.user._id,
    });
    
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    await device.unlinkAccount();
    
    res.json({
      device: {
        id: device._id,
        deviceId: device.deviceId,
        name: device.name,
        linkedAccount: null,
      },
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ESP32'den para işlemi (transaction) endpoint'i
router.post('/transaction', async (req, res) => {
  try {
    const { deviceId, type, amount, description } = req.body;
    
    // ESP32'den gelen istekleri doğrula
    const esp32Secret = process.env.ESP32_SECRET || "esp32-super-secret-key-2024";
    const requestSecret = req.header('X-ESP32-Secret');
    
    if (requestSecret !== esp32Secret) {
      return res.status(401).json({ error: 'Yetkisiz erişim' });
    }
    
    // Cihazı bul
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    // Bağlı hesabı kontrol et
    if (!device.linkedAccount) {
      return res.status(400).json({ error: 'Cihaza bağlı hesap yok' });
    }
    
    // Hesaba para yatır
    const Account = mongoose.model('Account');
    const account = await Account.findById(device.linkedAccount);
    if (!account) {
      return res.status(404).json({ error: 'Bağlı hesap bulunamadı' });
    }
    
    // Para yatırma işlemini gerçekleştir
    const transaction = await account.updateBalance(amount, description || 'ESP32 Kumbara - Otomatik para yatırma');
    
    // Cihaz bakiyesini güncelle
    await device.updateBalance(amount);
    
    res.json({
      success: true,
      transaction: {
        id: transaction._id,
        type: transaction.type,
        amount: transaction.amount,
        balance: transaction.balance,
        description: transaction.description,
        createdAt: transaction.createdAt,
      },
      device: {
        id: device._id,
        currentBalance: device.currentBalance,
      },
      account: {
        id: account._id,
        balance: account.balance,
      },
    });
  } catch (error) {
    console.error('Transaction error:', error);
    res.status(400).json({ error: error.message });
  }
});

export default router; 