import express from 'express';
import { Transaction } from '../models/Transaction.js';
import { Account } from '../models/Account.js';
import { authMiddleware } from '../middleware/auth.js';

const router = express.Router();

// İşlem listesi
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { accountId } = req.query;
    
    let query = { accountId: { $exists: true } };
    
    if (accountId) {
      // Belirli bir hesabın işlemleri
      const account = await Account.findOne({
        _id: accountId,
        owner: req.user._id,
      });
      
      if (!account) {
        return res.status(404).json({ error: 'Hesap bulunamadı' });
      }
      
      query.accountId = accountId;
    } else {
      // Kullanıcının tüm hesaplarının işlemleri
      const accounts = await Account.find({ owner: req.user._id });
      query.accountId = { $in: accounts.map(acc => acc._id) };
    }
    
    const transactions = await Transaction.find(query)
      .sort({ createdAt: -1 })
      .populate('accountId', 'name type'); // Hesap bilgilerini ekle
    
    res.json(transactions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Yeni işlem oluştur
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { accountId, type, amount, description, targetAccountId } = req.body;
    
    if (!accountId || !type || !amount) {
      return res.status(400).json({ error: 'Eksik bilgi' });
    }
    
    const sourceAccount = await Account.findOne({
      _id: accountId,
      owner: req.user._id,
    });
    
    if (!sourceAccount) {
      return res.status(404).json({ error: 'Kaynak hesap bulunamadı' });
    }

    // Transfer işlemi için özel mantık
    if (type === 'transfer' && targetAccountId) {
      const targetAccount = await Account.findOne({
        _id: targetAccountId,
        owner: req.user._id,
      });

      if (!targetAccount) {
        return res.status(404).json({ error: 'Hedef hesap bulunamadı' });
      }

      try {
        // Transfer işlemini gerçekleştir
        await sourceAccount.transfer(targetAccount, Math.abs(amount));

        // Kaynak hesap için çıkış işlemi
        const sourceTransaction = new Transaction({
          accountId: sourceAccount._id,
          type: 'transfer',
          amount: -Math.abs(amount),
          description: description || `${targetAccount.name} hesabına transfer`,
          balance: sourceAccount.balance,
        });
        await sourceTransaction.save();

        // Hedef hesap için giriş işlemi
        const targetTransaction = new Transaction({
          accountId: targetAccount._id,
          type: 'transfer',
          amount: Math.abs(amount),
          description: description || `${sourceAccount.name} hesabından transfer`,
          balance: targetAccount.balance,
        });
        await targetTransaction.save();

        return res.status(201).json({
          source: sourceTransaction,
          target: targetTransaction,
        });
      } catch (error) {
        return res.status(400).json({ error: error.message });
      }
    }
    
    // Normal işlem mantığı
    const transaction = new Transaction({
      accountId,
      type,
      amount,
      description,
      balance: sourceAccount.balance + (type === 'deposit' ? amount : -amount),
    });
    
    await sourceAccount.updateBalance(type === 'deposit' ? amount : -amount);
    await transaction.save();
    
    res.status(201).json(transaction);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// İşlem detayları
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const transaction = await Transaction.findById(req.params.id);
    
    if (!transaction) {
      return res.status(404).json({ error: 'İşlem bulunamadı' });
    }
    
    const account = await Account.findOne({
      _id: transaction.accountId,
      owner: req.user._id,
    });
    
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }
    
    res.json(transaction);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router; 