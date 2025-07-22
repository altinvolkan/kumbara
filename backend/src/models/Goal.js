import mongoose from 'mongoose';

const goalSchema = new mongoose.Schema({
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  targetAmount: {
    type: Number,
    required: true,
    min: 0,
  },
  currentAmount: {
    type: Number,
    default: 0,
    min: 0,
  },
  description: {
    type: String,
    trim: true,
  },
  icon: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['active', 'paused', 'completed'],
    default: 'active',
  },
  targetDate: {
    type: Date,
  },
  priority: {
    type: Number,
    default: 1,
    min: 1,
  },
  isVisible: {
    type: Boolean,
    default: true,
  },
  isParallel: {
    type: Boolean,
    default: false,
  },
  color: {
    type: String,
    default: '#2196F3',
  },
  category: {
    type: String,
    enum: ['toy', 'electronics', 'clothes', 'sport', 'education', 'travel', 'other', 'game', 'games', 'book', 'books', 'money', 'car', 'house', 'phone', 'food', 'art', 'music'],
    default: 'other',
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

// İlerleme yüzdesi hesaplama
goalSchema.virtual('progress').get(function() {
  return (this.currentAmount / this.targetAmount) * 100;
});

// Hedef oluşturma statik metodu
goalSchema.statics.createGoal = async function (data) {
  const goal = new this(data);
  await goal.save();
  return goal;
};

// Para ekleme metodu
goalSchema.methods.addAmount = async function (amount) {
  if (this.status !== 'active') {
    throw new Error('Hedef aktif değil');
  }
  
  this.currentAmount += amount;
  this.updatedAt = new Date();
  
  // Hedef tamamlandı mı kontrol et
  if (this.currentAmount >= this.targetAmount) {
    this.status = 'completed';
    this.completedAt = new Date();
    this.currentAmount = this.targetAmount; // Hedef miktarını aşmayı engelle
  }
  
  // Kilometre taşlarını kontrol et
  for (const milestone of this.milestones) {
    if (!milestone.completed && this.currentAmount >= milestone.amount) {
      milestone.completed = true;
      milestone.completedAt = new Date();
    }
  }
  
  await this.save();
  return this;
};

// Hedef durumunu güncelleme metodu
goalSchema.methods.updateStatus = async function (status) {
  if (!['active', 'completed', 'paused'].includes(status)) {
    throw new Error('Geçersiz durum');
  }
  
  this.status = status;
  this.updatedAt = new Date();
  
  if (status === 'completed') {
    this.completedAt = new Date();
  }
  
  await this.save();
  return this;
};

const Goal = mongoose.model('Goal', goalSchema);

export { Goal }; 