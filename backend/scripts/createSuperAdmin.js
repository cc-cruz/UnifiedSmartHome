require('dotenv').config({ path: '../.env' }); // Adjust path to .env if script is run from scripts/ directory
const mongoose = require('mongoose');
const readline = require('readline');
const User = require('../models/User'); // Adjust path as needed
const connectDB = require('../config/db'); // Adjust path as needed

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const promptUser = (query) => new Promise((resolve) => rl.question(query, resolve));

async function createSuperAdmin() {
  try {
    await connectDB();
    console.log('MongoDB Connected for script...');

    const email = await promptUser('Enter SuperAdmin email: ');
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.log('User with this email already exists.');
      rl.close();
      mongoose.connection.close();
      return;
    }

    const firstName = await promptUser('Enter SuperAdmin first name: ');
    const lastName = await promptUser('Enter SuperAdmin last name: ');
    const password = await promptUser('Enter SuperAdmin password: ');

    if (!email || !firstName || !lastName || !password) {
        console.log('All fields are required.');
        rl.close();
        mongoose.connection.close();
        return;
    }

    const superAdmin = new User({
      firstName,
      lastName,
      email,
      password, // Will be hashed by pre-save hook
      isSuperAdmin: true
    });

    await superAdmin.save();
    console.log('SuperAdmin user created successfully!');
    console.log(`Email: ${superAdmin.email}`);
    console.log(`isSuperAdmin: ${superAdmin.isSuperAdmin}`);

  } catch (error) {
    console.error('Error creating SuperAdmin:', error.message);
  } finally {
    rl.close();
    mongoose.connection.close(() => {
        console.log('MongoDB connection closed.');
        process.exit(0);
    });
  }
}

createSuperAdmin(); 