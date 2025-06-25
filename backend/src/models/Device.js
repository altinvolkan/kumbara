import mongoose from 'mongoose';
import crypto from 'crypto';

const deviceSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    unique: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  linkedAccount: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    default: null,
  },
  pairingCode: {
    type: String,
    required: true,
  },
  isPaired: {
    type: Boolean,
    default: false,
  },
  lastPairedAt: {
    type: Date,
    default: null,
  },
  firmwareVersion: {
    type: String,
    default: '1.0.0',
  },
  batteryLevel: {
    type: Number,
    default: 100,
  },
  lastSyncAt: {
    type: Date,
    default: null,
  },
  features: {
    autoLock: {
      type: Boolean,
      default: true,
    },
    notifications: {
      type: Boolean,
      default: true,
    },
    soundEffects: {
      type: Boolean,
      default: true,
    },
    vibration: {
      type: Boolean,
      default: true,
    },
  },
  status: {
    type: String,
    enum: ['online', 'offline', 'maintenance'],
    default: 'offline',
  },
  currentBalance: {
    type: Number,
    default: 0,
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

// Yeni cihaz oluşturma statik metodu
deviceSchema.statics.createNew = async function (ownerId, name) {
  const deviceId = crypto.randomBytes(4).toString('hex');
  const pairingCode = crypto.randomBytes(3).toString('hex');
  
  const device = new this({
    deviceId,
    name,
    owner: ownerId,
    pairingCode,
  });
  
  await device.save();
  return device;
};

// Cihaz eşleştirme metodu
deviceSchema.methods.pair = async function (code) {
  if (this.isPaired) {
    throw new Error('Cihaz zaten eşleştirilmiş');
  }
  
  if (this.pairingCode !== code) {
    throw new Error('Geçersiz eşleştirme kodu');
  }
  
  this.isPaired = true;
  this.lastPairedAt = new Date();
  this.status = 'online';
  
  await this.save();
  return this;
};

// Bakiye güncelleme metodu
deviceSchema.methods.updateBalance = async function (amount) {
  this.currentBalance += amount;
  this.lastSyncAt = new Date();
  this.updatedAt = new Date();
  
  await this.save();
  return this.currentBalance;
};

// Durum güncelleme metodu
deviceSchema.methods.updateStatus = async function (status, batteryLevel = null) {
  this.status = status;
  if (batteryLevel !== null) {
    this.batteryLevel = batteryLevel;
  }
  this.lastSyncAt = new Date();
  this.updatedAt = new Date();
  
  await this.save();
  return this;
};

// Hesap bağlama metodu
deviceSchema.methods.linkAccount = async function (accountId) {
  const Account = mongoose.model('Account');
  const account = await Account.findById(accountId);
  
  if (!account) {
    throw new Error('Hesap bulunamadı');
  }
  
  if (account.type === 'main') {
    throw new Error('Ana hesap bağlanamaz');
  }
  
  this.linkedAccount = accountId;
  this.updatedAt = new Date();
  
  await this.save();
  return this;
};

// Hesap bağlantısını kaldırma metodu
deviceSchema.methods.unlinkAccount = async function () {
  this.linkedAccount = null;
  this.updatedAt = new Date();
  
  await this.save();
  return this;
};

const Device = mongoose.model('Device', deviceSchema);

export { Device }; 