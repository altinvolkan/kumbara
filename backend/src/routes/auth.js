import express from 'express';
import { User } from '../models/User.js';
import { authMiddleware } from '../middleware/auth.js';
import { Account } from '../models/Account.js';

const router = express.Router();

// Kayıt ol
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    // Email kontrolü
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'Bu email zaten kullanımda' });
    }
    
    // Kullanıcı oluştur
    const user = new User({
      name,
      email,
      password,
      role: role || 'parent',
    });
    
    await user.save();
    
    // Ana hesap oluştur
    const mainAccount = new Account({
      name: 'Ana Hesap',
      type: 'main',
      owner: user._id,
      description: 'Otomatik oluşturulan ana hesap',
      icon: 'wallet',
      color: '#2196F3'
    });
    
    await mainAccount.save();
    
    // Token oluştur
    const token = user.generateAuthToken();
    
    res.status(201).json({
      user,
      token,
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(400).json({ error: error.message });
  }
});

// Giriş yap
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Kullanıcıyı bul
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ error: 'Geçersiz email veya şifre' });
    }
    
    // Şifreyi kontrol et
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Geçersiz email veya şifre' });
    }
    
    // Token oluştur
    const token = user.generateAuthToken();
    
    res.json({
      user,
      token,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(400).json({ error: error.message });
  }
});

// Profil bilgilerini getir
router.get('/profile', authMiddleware, async (req, res) => {
  res.json(req.user);
});

// Profil güncelle
router.patch('/profile', authMiddleware, async (req, res) => {
  try {
    const updates = Object.keys(req.body);
    const allowedUpdates = ['name', 'password', 'settings'];
    const isValidOperation = updates.every(update => allowedUpdates.includes(update));
    
    if (!isValidOperation) {
      return res.status(400).json({ error: 'Geçersiz güncelleme alanları' });
    }
    
    updates.forEach(update => {
      if (update === 'settings') {
        req.user.settings = { ...req.user.settings, ...req.body.settings };
      } else {
        req.user[update] = req.body[update];
      }
    });
    
    await req.user.save();
    res.json(req.user);
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(400).json({ error: error.message });
  }
});

// Çocuk hesabı oluşturma
router.post('/create-child', authMiddleware, async (req, res) => {
  try {
    console.log('Creating child account request:', req.body);
    const { name, email, password, linkedAccountId } = req.body;

    // Ebeveyn kullanıcısını kontrol et
    const parentUser = req.user;
    console.log('Parent user:', parentUser._id);
    if (!parentUser) {
      return res.status(401).json({ error: 'Yetkilendirme hatası' });
    }

    // Bağlanacak hesabı kontrol et
    const account = await Account.findById(linkedAccountId);
    if (!account) {
      return res.status(404).json({ error: 'Hesap bulunamadı' });
    }

    // Hesabın ebeveyne ait olduğunu kontrol et
    if (account.owner.toString() !== parentUser._id.toString()) {
      return res.status(403).json({ error: 'Bu hesaba erişim yetkiniz yok' });
    }

    // Hesap tipini kontrol et
    if (account.type !== 'savings' && account.type !== 'piggy') {
      return res.status(400).json({ error: 'Sadece birikim veya kumbara hesapları bağlanabilir' });
    }

    // Çocuk kullanıcısını oluştur
    const childUser = new User({
      name,
      email,
      password,
      role: 'child',
      parent: parentUser._id
    });

    await childUser.save();
    console.log('Child user created:', childUser._id);

    // Hesabı çocuk kullanıcısına bağla
    account.linkedUserId = childUser._id;
    await account.save();
    // Çocuğa da hesabı bağla
    childUser.linkedAccount = account._id;
    await childUser.save();
    console.log('Account linked to child:', account._id);

    res.status(201).json({
      message: 'Çocuk hesabı başarıyla oluşturuldu',
      userId: childUser._id
    });

  } catch (error) {
    console.error('Çocuk hesabı oluşturma hatası:', error);
    res.status(500).json({ error: 'Çocuk hesabı oluşturulurken bir hata oluştu' });
  }
});

// Ebeveynin çocuk hesaplarını listele
router.get('/children', authMiddleware, async (req, res) => {
  try {
    const parentUser = req.user;
    console.log('Getting children for parent:', parentUser._id);

    // Ebeveyne bağlı çocuk hesaplarını bul
    const childUsers = await User.find({ parent: parentUser._id })
      .select('-password') // Şifre hariç tüm bilgileri getir
      .lean();
    
    console.log('Found child users:', childUsers.length);

    // Her çocuk için bağlı hesap bilgisini al
    const childrenWithAccounts = await Promise.all(
      childUsers.map(async (child) => {
        const linkedAccount = await Account.findOne({ linkedUserId: child._id })
          .select('name type balance')
          .lean();

        console.log(`Child ${child._id} linked account:`, linkedAccount);

        return {
          ...child,
          linkedAccount: linkedAccount || null
        };
      })
    );

    console.log('Returning children with accounts:', childrenWithAccounts);
    res.json(childrenWithAccounts);
  } catch (error) {
    console.error('Çocuk hesapları listeleme hatası:', error);
    res.status(500).json({ error: 'Çocuk hesapları listelenirken bir hata oluştu' });
  }
});

// Çocuk hesabını güncelle
router.patch('/children/:childId', authMiddleware, async (req, res) => {
  try {
    const { childId } = req.params;
    const { name, email, linkedAccountId } = req.body;
    const parentUser = req.user;

    // Çocuk hesabını bul ve ebeveyn kontrolü yap
    const childUser = await User.findOne({ _id: childId, parent: parentUser._id });
    if (!childUser) {
      return res.status(404).json({ error: 'Çocuk hesabı bulunamadı' });
    }

    // Temel bilgileri güncelle
    if (name) childUser.name = name;
    if (email) childUser.email = email;
    await childUser.save();

    // Bağlı hesabı değiştir
    if (linkedAccountId) {
      // Eski bağlantıyı kaldır
      await Account.updateOne(
        { linkedUserId: childUser._id },
        { $unset: { linkedUserId: 1 } }
      );

      // Yeni hesabı kontrol et
      const newAccount = await Account.findById(linkedAccountId);
      if (!newAccount) {
        return res.status(404).json({ error: 'Hesap bulunamadı' });
      }

      // Hesabın ebeveyne ait olduğunu kontrol et
      if (newAccount.owner.toString() !== parentUser._id.toString()) {
        return res.status(403).json({ error: 'Bu hesaba erişim yetkiniz yok' });
      }

      // Hesap tipini kontrol et
      if (newAccount.type !== 'savings' && newAccount.type !== 'piggy') {
        return res.status(400).json({ error: 'Sadece birikim veya kumbara hesapları bağlanabilir' });
      }

      // Yeni bağlantıyı kur
      newAccount.linkedUserId = childUser._id;
      await newAccount.save();
    }

    res.json({ message: 'Çocuk hesabı başarıyla güncellendi' });
  } catch (error) {
    console.error('Çocuk hesabı güncelleme hatası:', error);
    res.status(500).json({ error: 'Çocuk hesabı güncellenirken bir hata oluştu' });
  }
});

// Çocuk hesabını sil
router.delete('/children/:childId', authMiddleware, async (req, res) => {
  try {
    const { childId } = req.params;
    const parentUser = req.user;

    // Çocuk hesabını bul ve ebeveyn kontrolü yap
    const childUser = await User.findOne({ _id: childId, parent: parentUser._id });
    if (!childUser) {
      return res.status(404).json({ error: 'Çocuk hesabı bulunamadı' });
    }

    // Bağlı hesaptan referansı kaldır
    await Account.updateOne(
      { linkedUserId: childUser._id },
      { $unset: { linkedUserId: 1 } }
    );

    // Çocuk hesabını sil
    await User.deleteOne({ _id: childUser._id });

    res.json({ message: 'Çocuk hesabı başarıyla silindi' });
  } catch (error) {
    console.error('Çocuk hesabı silme hatası:', error);
    res.status(500).json({ error: 'Çocuk hesabı silinirken bir hata oluştu' });
  }
});

export default router; 