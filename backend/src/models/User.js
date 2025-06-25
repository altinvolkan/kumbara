import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'kumbara-secret-key';

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
  },
  password: {
    type: String,
    required: true,
    minlength: 6,
  },
  role: {
    type: String,
    enum: ['parent', 'child'],
    default: 'parent',
  },
  parent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  linkedAccount: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    default: null,
  },
  avatar: {
    type: String,
    default: null,
  },
  level: {
    type: Number,
    default: 1,
  },
  xp: {
    type: Number,
    default: 0,
  },
  nextLevelXp: {
    type: Number,
    default: 1000,
  },
  settings: {
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
    darkMode: {
      type: Boolean,
      default: false,
    },
  },
}, {
  timestamps: true,
});

// Şifre hashleme middleware
userSchema.pre('save', async function(next) {
  const user = this;
  if (user.isModified('password')) {
    user.password = await bcrypt.hash(user.password, 10);
  }
  next();
});

// Token oluşturma metodu
userSchema.methods.generateAuthToken = function() {
  return jwt.sign({ userId: this._id }, JWT_SECRET, {
    expiresIn: '7d',
  });
};

// Şifre kontrolü
userSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

// JSON dönüşümünde şifreyi çıkar
userSchema.methods.toJSON = function() {
  const user = this.toObject();
  delete user.password;
  return user;
};

// XP ve level yönetimi
userSchema.methods.addXp = async function (amount) {
  this.xp += amount;
  
  // Level atlama kontrolü
  while (this.xp >= this.nextLevelXp) {
    this.level += 1;
    this.xp -= this.nextLevelXp;
    this.nextLevelXp = Math.floor(this.nextLevelXp * 1.5); // Her seviyede %50 daha fazla XP gerekir
  }
  
  await this.save();
  return {
    level: this.level,
    xp: this.xp,
    nextLevelXp: this.nextLevelXp,
  };
};

const User = mongoose.model('User', userSchema);

export { User }; 