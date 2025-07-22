import express from 'express';
import mongoose from 'mongoose';
import { Device } from '../models/Device.js';
import { Account } from '../models/Account.js';
import { Goal } from '../models/Goal.js';
import { User } from '../models/User.js';

const router = express.Router();

// ESP32 health check
router.get('/health', (req, res) => {
  res.json({ status: 'ESP32 Route OK' });
});

// ESP32 için kullanıcı hedefleri endpoint'i
router.get('/goals/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log('ESP32 Goals Request for userId:', userId);
    
    // User'ı bul
    const user = await User.findById(userId);
    if (!user) {
      console.log('User not found:', userId);
      return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
    }
    
    // Toplam hedef sayısını al (ESP32 display için)
    const totalCount = await Goal.countDocuments({ 
      owner: userId, 
      isVisible: true,
      status: 'active'
    });
    
    // İlk 15 hedefi getir (ESP32 memory limit)
    const goals = await Goal.find({ 
      owner: userId, 
      isVisible: true,
      status: 'active'
    }).sort({ priority: 1, createdAt: -1 }).limit(15);
    
    console.log('Found goals for ESP32:', goals.length, '/', totalCount);
    
    // Emoji'leri ESP32'nin anlayabileceği string'lere dönüştür
    const emojiToString = (emoji) => {
      const emojiMap = {
        '🧸': 'toy',
        '📚': 'book',
        '📱': 'phone',
        '⚽': 'sport',
        '👕': 'clothes',
        '🎮': 'game',
        '🚗': 'car',
        '🏠': 'house',
        '✈️': 'travel',
        '💻': 'electronics',
        '💰': 'money',
        '⭐': 'default',
        '🎨': 'art',
        '🎵': 'music',
        '🍕': 'food',
        'other': 'default',
        'art': 'art',
        'music': 'music',
        'food': 'food',
        'games': 'game',
        'game': 'game',
        'gamepad': 'game',
        'game_controller': 'game',
        'oyun_kolu': 'game',
        'oyun kolu': 'game',
        'controller': 'game',
        'game controller': 'game',
        'joystick': 'game',
        'toy': 'toy',
        'book': 'book',
        'electronics': 'electronics',
        'sports': 'sport',
        'clothes': 'clothes',
        'travel': 'travel',
        'education': 'book',
        'default': 'default',
      };
      return emojiMap[emoji] || 'default';
    };

    // ESP32 için basit format
    const esp32Goals = goals.map(goal => {
      const convertedIcon = emojiToString(goal.icon) || emojiToString(goal.category) || 'default';
      console.log(`Goal: ${goal.name} | Original icon: ${goal.icon} | Category: ${goal.category} | Converted: ${convertedIcon}`);
      
      return {
        id: goal._id,
        name: goal.name,
        current: goal.currentAmount || 0,
        target: goal.targetAmount || 1,
        icon: convertedIcon,
        progress: Math.round(((goal.currentAmount || 0) / (goal.targetAmount || 1)) * 100)
      };
    });
    
    res.json({
      success: true,
      goals: esp32Goals,
      count: esp32Goals.length,
      totalCount: totalCount
    });
    
  } catch (error) {
    console.error('Error in ESP32 goals:', error);
    res.status(500).json({ error: error.message });
  }
});

// ESP32'den para işlemi (transaction) endpoint'i
router.post('/transaction', async (req, res) => {
  try {
    const { deviceId, type, amount, description } = req.body;
    
    console.log('ESP32 Transaction:', { deviceId, type, amount, description });
    
    // ESP32'den gelen istekleri doğrula
    const esp32Secret = process.env.ESP32_SECRET || "esp32-super-secret-key-2024";
    const requestSecret = req.header('X-ESP32-Secret');
    
    if (requestSecret !== esp32Secret) {
      console.log('ESP32 Secret mismatch:', requestSecret, 'vs', esp32Secret);
      return res.status(401).json({ error: 'Yetkisiz erişim' });
    }
    
    // Cihazı bul
    const device = await Device.findOne({ deviceId });
    if (!device) {
      console.log('Device not found:', deviceId);
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    console.log('Device found:', device.name, 'linkedAccount:', device.linkedAccount);
    
    // Bağlı hesabı kontrol et
    if (!device.linkedAccount) {
      return res.status(400).json({ error: 'Cihaza bağlı hesap yok' });
    }
    
    // Hesaba para yatır
    const account = await Account.findById(device.linkedAccount);
    if (!account) {
      return res.status(404).json({ error: 'Bağlı hesap bulunamadı' });
    }
    
    console.log('Account found:', account.name, 'balance:', account.balance);
    
    // Para yatırma işlemini gerçekleştir
    const transaction = await account.updateBalance(amount, description || 'ESP32 Kumbara - Otomatik para yatırma');
    
    // Cihaz bakiyesini güncelle
    await device.updateBalance(amount);
    
    console.log('Transaction successful:', transaction._id);
    
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
    console.error('ESP32 Transaction error:', error);
    res.status(400).json({ error: error.message });
  }
});

// ESP32 cihaz durumu güncelle
router.post('/status/:deviceId', async (req, res) => {
  try {
    const { status, batteryLevel, balance } = req.body;
    const deviceId = req.params.deviceId;
    
    // ESP32'den gelen istekleri doğrula
    const esp32Secret = process.env.ESP32_SECRET || "esp32-super-secret-key-2024";
    const requestSecret = req.header('X-ESP32-Secret');
    
    if (requestSecret !== esp32Secret) {
      return res.status(401).json({ error: 'Yetkisiz erişim' });
    }
    
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ error: 'Cihaz bulunamadı' });
    }
    
    await device.updateStatus(status, batteryLevel);
    
    res.json({
      device: {
        id: device._id,
        status: device.status,
        batteryLevel: device.batteryLevel,
        currentBalance: device.currentBalance,
      },
    });
  } catch (error) {
    console.error('ESP32 Status error:', error);
    res.status(400).json({ error: error.message });
  }
});

export default router; 