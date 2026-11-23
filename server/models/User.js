const mongoose = require('mongoose');

// Native bcrypt (C++) is ~3-5x faster than pure-JS bcryptjs on Render's small
// CPU, which directly speeds up login/registration. Hashes are fully
// compatible ($2a/$2b), so existing users keep working. Falls back to bcryptjs
// if the native module cannot be loaded on the host.
let bcrypt;
try {
  bcrypt = require('bcrypt');
} catch (_) {
  bcrypt = require('bcryptjs');
}

const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      minlength: [3, 'Username must be at least 3 characters'],
      maxlength: [32, 'Username must be at most 32 characters'],
      match: [
        /^[a-zA-Z0-9._-]+$/,
        'Username can only contain letters, numbers, dots, underscores and hyphens',
      ],
    },
    password: {
      type: String,
      required: true,
      minlength: 6,
      select: false,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    businessName: {
      type: String,
      default: '',
      trim: true,
    },
    currency: {
      type: String,
      default: 'RUB',
      trim: true,
    },
    locale: {
      type: String,
      default: 'ru',
      trim: true,
    },
    avatar: {
      type: String,
      default: '',
    },
  },
  { timestamps: true }
);

// Hash password before save
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Method to compare password
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
