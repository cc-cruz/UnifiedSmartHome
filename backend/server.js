const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

// Import database connection
const connectDB = require('./config/db');

// Import routes
const authRoutes = require('./routes/auth');
const propertyRoutes = require('./routes/properties');
// const deviceRoutes = require('./routes/devices'); // Removed legacy import
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
const propertyV1Routes = require('./routes/property.routes');
apiV1Router.use('/properties', propertyV1Routes);
const unitV1Routes = require('./routes/unit.routes'); // Import unit v1 routes
apiV1Router.use('/units', unitV1Routes); // Add unit v1 routes
// Add other v1 routes here, e.g.:
// apiV1Router.use('/units', unitRoutes); // If unitRoutes are also v1 and need protection

// Re-introduce devices route import for v1 protected path
const deviceRoutes = require('./routes/devices');
apiV1Router.use('/devices', deviceRoutes);

// Remove legacy users path and add under api v1 router
// app.use('/api/users', userRoutes);
apiV1Router.use('/users', userRoutes);

app.use('/api/v1', protect, apiV1Router); // Protect all /api/v1 routes

// Legacy or other public/unprotected routes (example)
// app.use('/api/properties', propertyRoutes); // This line can be removed or commented if properties are now fully v1

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