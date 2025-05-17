const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

// Import database connection
const connectDB = require('./config/db');

// Import routes
const authRoutes = require('./routes/auth');
const propertyRoutes = require('./routes/properties');
const deviceRoutes = require('./routes/devices');
const userRoutes = require('./routes/users');
const portfolioRoutes = require('./routes/portfolio.routes');
const { protect } = require('./middleware/auth.middleware'); // Import the protect middleware

// Initialize express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Connect to database
connectDB();

// Public Routes (like auth, health-check)
app.use('/api/auth', authRoutes);
app.get('/health', (req, res) => { // Moved health check to be explicitly public
  res.status(200).send('Server is running');
});

// Protected API v1 Routes
// All routes under /api/v1 will now be protected by the 'protect' middleware
const apiV1Router = express.Router();
apiV1Router.use('/portfolios', portfolioRoutes); 
// Add other v1 routes here, e.g.:
// apiV1Router.use('/properties', propertyRoutes); // If propertyRoutes are also v1 and need protection
// apiV1Router.use('/units', unitRoutes); // If unitRoutes are also v1 and need protection

app.use('/api/v1', protect, apiV1Router); // Protect all /api/v1 routes

// Legacy or other public/unprotected routes (example)
app.use('/api/properties', propertyRoutes); // Assuming these are currently unprotected or handled differently
app.use('/api/devices', deviceRoutes);
app.use('/api/users', userRoutes);

// Health check route (already defined as public above)
// app.get('/health', (req, res) => {
//   res.status(200).send('Server is running');
// });

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'production' ? null : err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
}); 