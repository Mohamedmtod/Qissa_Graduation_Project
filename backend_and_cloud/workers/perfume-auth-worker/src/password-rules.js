const PASSWORD_RULES = {
  minLength: 8,
  upperCase: /[A-Z]/,
  lowerCase: /[a-z]/,
  digit: /[0-9]/,
  specialChar: /[!@#$%^&*()_\-+=?.,/|]/,
  englishOnly: /^[A-Za-z0-9!@#$%^&*()_\-+=?.,/|]*$/,
};

/**
 * @param {unknown} value
 */
export function validatePassword(value) {
  if (typeof value !== "string" || value.length === 0) {
    return "Password is required.";
  }
  if (!PASSWORD_RULES.englishOnly.test(value)) {
    return "Only English letters, numbers, and symbols are allowed.";
  }
  if (!PASSWORD_RULES.lowerCase.test(value)) {
    return "Password must contain at least one lowercase letter.";
  }
  if (!PASSWORD_RULES.upperCase.test(value)) {
    return "Password must contain at least one uppercase letter.";
  }
  if (!PASSWORD_RULES.digit.test(value)) {
    return "Password must contain at least one digit.";
  }
  if (!PASSWORD_RULES.specialChar.test(value)) {
    return "Password must contain at least one special character.";
  }
  if (value.length < PASSWORD_RULES.minLength) {
    return "Password must be at least 8 characters long.";
  }
  return null;
}

/**
 * @param {unknown} value
 */
export function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

/**
 * @param {string} email
 */
export function isValidEmail(email) {
  return email.length <= 255 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * @param {unknown} value
 */
export function normalizeOtp(value) {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * @param {string} otp
 */
export function isValidOtpShape(otp) {
  return /^\d{6}$/.test(otp);
}
