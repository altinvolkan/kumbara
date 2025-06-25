import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import { createServer } from 'http';
import { Server } from 'socket.io';
import winston from 'winston';

// Routes
import authRoutes from './routes/auth.js';
import accountRoutes from './routes/accounts.js';
import deviceRoutes from './routes/devices.js';
import transactionRoutes from './routes/transactions.js';
import goalRoutes from './routes/goals.js';
import esp32Routes from './routes/esp32.js';

// Middleware
import { errorHandler } from './middleware/error.js';
import { authMiddleware } from './middleware/auth.js';

// Config
dotenv.config();

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple(),
  }));
}

// Express app
const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());
app.use((req, res, next) => {
  req.logger = logger;
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/accounts', accountRoutes);
app.use('/api/devices', authMiddleware, deviceRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/goals', goalRoutes);

// ESP32 özel endpoint'leri (auth middleware'siz)
app.use('/api/esp32', esp32Routes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Kumbara Backend API çalışıyor',
    timestamp: new Date().toISOString()
  });
});

// WebSocket
io.on('connection', (socket) => {
  logger.info('Client connected:', socket.id);

  socket.on('join-device', (deviceId) => {
    socket.join(`device-${deviceId}`);
    logger.info(`Client ${socket.id} joined device-${deviceId}`);
  });

  socket.on('balance-update', (data) => {
    const { deviceId, balance } = data;
    io.to(`device-${deviceId}`).emit('balance-changed', { balance });
    logger.info(`Balance updated for device-${deviceId}: ${balance}`);
  });

  socket.on('goal-update', (data) => {
    const { deviceId, goalId, progress } = data;
    io.to(`device-${deviceId}`).emit('goal-progress', { goalId, progress });
    logger.info(`Goal progress updated for device-${deviceId}, goal-${goalId}: ${progress}%`);
  });

  socket.on('disconnect', () => {
    logger.info('Client disconnected:', socket.id);
  });
});

// Error handling
app.use(errorHandler);

// Database connection
mongoose
  .connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/kumbara')
  .then(() => {
    logger.info('Connected to MongoDB');
    // Start server
    const PORT = process.env.PORT || 3000;
    const HOST = '0.0.0.0'; // Tüm IP adreslerinde dinle
    httpServer.listen(PORT, HOST, () => {
      logger.info(`Server running on http://${HOST}:${PORT}`);
      logger.info(`Local: http://localhost:${PORT}`);
      logger.info(`Network: http://192.168.1.21:${PORT}`);
    });
  })
  .catch((error) => {
    logger.error('MongoDB connection error:', error);
    process.exit(1);
  }); 