const jwt = require('jsonwebtoken');
const User = require('../models/User'); // To potentially fetch full user object
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
    console.error("FATAL ERROR: JWT_SECRET is not defined. Set it in your .env file.");
    process.exit(1);
}

const protect = async (req, res, next) => {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        try {
            token = req.headers.authorization.split(' ')[1];

            if (!token) {
                return res.status(401).json({ status: 'error', message: 'Not authorized, no token provided.' });
            }

            const decoded = jwt.verify(token, JWT_SECRET);

            // Attach user ID to request object. We can also fetch the full user object if needed frequently.
            // For now, just attaching the decoded payload which includes user.id.
            req.user = decoded.user; // Payload was { user: { id: userId } }
            
            // Fetch the full user object from DB
            // This allows access to any user fields, e.g., for global role checks like SuperAdmin
            const userDbRecord = await User.findById(decoded.user.id).select('-password');
            if (!userDbRecord) {
                // This case should ideally not happen if JWT is valid and user was not deleted post-token-issuance
                return res.status(401).json({ status: 'error', message: 'Not authorized, user record not found.' });
            }
            req.userDbRecord = userDbRecord; // Attach full user DB record

            next();
        } catch (error) {
            console.error('Token verification error:', error.message);
            if (error.name === 'JsonWebTokenError') {
                return res.status(401).json({ status: 'error', message: 'Not authorized, token failed verification.' });
            }
            if (error.name === 'TokenExpiredError') {
                return res.status(401).json({ status: 'error', message: 'Not authorized, token expired.' });
            }
            return res.status(401).json({ status: 'error', message: 'Not authorized, token issue.' });
        }
    }

    if (!token) {
        return res.status(401).json({ status: 'error', message: 'Not authorized, no token.' });
    }
};

module.exports = { protect }; 