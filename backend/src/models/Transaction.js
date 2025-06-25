import mongoose from 'mongoose';

const transactionSchema = new mongoose.Schema({
  accountId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    required: true,
  },
  type: {
    type: String,
    enum: ['deposit', 'withdrawal', 'transfer'],
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  balance: {
    type: Number,
    required: true,
  },
  description: {
    type: String,
    trim: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// İşlem oluşturma statik metodu
transactionSchema.statics.createTransaction = async function (data) {
  const transaction = new this(data);
  await transaction.save();
  
  // Cihaz bakiyesini güncelle
  const device = await mongoose.model('Device').findById(data.device);
  if (device) {
    // Transfer işlemlerinde balance zaten hesaplanmış olarak geliyor
    if (data.type === 'transfer') {
      device.currentBalance = data.balance;
    } else {
      // Diğer işlemler için mevcut mantık
      await device.updateBalance(data.type === 'deposit' ? data.amount : -data.amount);
    }
    await device.save();
  }
  
  return transaction;
};

// İşlem geçmişi sorgulama metodu
transactionSchema.statics.getHistory = async function (deviceId, options = {}) {
  const {
    startDate,
    endDate,
    type,
    limit = 50,
    skip = 0,
  } = options;
  
  const query = { device: deviceId };
  
  if (startDate || endDate) {
    query.createdAt = {};
    if (startDate) query.createdAt.$gte = new Date(startDate);
    if (endDate) query.createdAt.$lte = new Date(endDate);
  }
  
  if (type) query.type = type;
  
  return this.find(query)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .populate('goal', 'name targetAmount currentAmount');
};

const Transaction = mongoose.model('Transaction', transactionSchema);

export { Transaction }; 