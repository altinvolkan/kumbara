export const errorHandler = (err, req, res, next) => {
  const logger = req.logger;
  
  // Hata logla
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    body: req.body,
    query: req.query,
    params: req.params,
    user: req.user?._id,
  });
  
  // Validation hataları
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map(error => error.message);
    return res.status(400).json({ error: errors.join(', ') });
  }
  
  // MongoDB duplicate key hatası
  if (err.code === 11000) {
    const field = Object.keys(err.keyPattern)[0];
    return res.status(400).json({ error: `${field} zaten kullanımda` });
  }
  
  // JWT hataları
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ error: 'Geçersiz token' });
  }
  
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: 'Token süresi doldu' });
  }
  
  // Özel hata mesajları
  if (err.message) {
    return res.status(err.status || 500).json({ error: err.message });
  }
  
  // Genel hata
  res.status(500).json({ error: 'Bir hata oluştu' });
}; 