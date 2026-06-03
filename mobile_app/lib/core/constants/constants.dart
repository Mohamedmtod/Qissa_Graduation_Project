class InputLimits {
  static const lastName = 15;
  static const firstName = 15;
  static const email = 40;
  static const phone = 11;
  static const password = 32;
  static const address = 100;
  static const productName = 100;
  static const description = 1000;
  static const search = 50;
  static const coupon = 16;
}

class FontSizes {
  static double pad = 8;
  static double pad2 = 16;
  static double padZero = 0;
  static double radius = 8;
  static double h1 = 22;
  static double h2 = 15;
  static double h3 = 14;
  static double h4 = 12;
}

class AppConstants {
  static const appName = 'Qissa';
  static const double defaultShippingFee = 0.0;
  static const double defaultDiscount = 0.0;
}

class PaymentMethodCodes {
  static const cashOnDelivery = 'cash_on_delivery';
  static const card = 'card';

  static const checkoutDefaultMethod = cashOnDelivery;

  static const preferenceSupported = <String>[];
  static const orderSupported = <String>[cashOnDelivery];

  static String? normalizePreference(String? value) {
    return null;
  }

  static String? requireSupportedPreference(String? value) {
    if (value == null) {
      return null;
    }

    if (!preferenceSupported.contains(value)) {
      throw ArgumentError.value(
        value,
        'preferredPaymentMethod',
        'Unsupported payment method code',
      );
    }

    return value;
  }
}

class GeneralErrorMessages {
  static const generic = 'Oops, try again later.';
}

class WorkerErrorMessages {
  static const orderRequestFailed =
      'Could not complete your order right now. Please try again.';
  static const restockRequestFailed =
      'Could not update your restock request right now. Please try again.';
}

class EmailErrorMessages {
  static const empty = 'Email cannot be empty.';
  static const invalid = 'Please enter a valid email address.';
}

class PasswordErrorMessages {
  static const empty = 'Please enter your password';
  static const short = 'Password must be at least 8 characters long.';
  static const upperCase =
      'Password must contain at least one uppercase letter.';
  static const lowerCase =
      'Password must contain at least one lowercase letter.';
  static const digit = 'Password must contain at least one digit.';
  static const specialChar =
      'Password must contain at least one special character.';
  static const englishOnly =
      'Only English letters, numbers, and symbols are allowed.';
}

class AuthErrorMessages {
  static const userNotFound = 'No user found for that email.';
  static const invalidCredentials = 'Invalid email or password.';
  static const invalidEmail = 'Please enter a valid email address.';
  static const tooManyRequests = 'Too many attempts. Try again later.';
  static const networkFailed = 'No internet connection. Please try again.';
  static const genericLoginFailed = 'Login failed. Please try again.';
}

class RegistrationErrorMessages {
  static const emailAlreadyInUse = 'The account already exists for that email.';
  static const weakPassword = 'The password provided is too weak.';
  static const invalidEmail = 'Please enter a valid email address.';
  static const networkFailed = 'No internet connection. Please try again.';
  static const genericRegistrationFailed =
      'Registration failed. Please try again.';
  static const profileSetupFailed =
      'Account created, but profile setup failed. Please sign in again.';
}

class RegistrationSuccessMessages {
  static const accountCreated = 'Account created successfully!';
}

class NameValidatorMessages {
  static const empty = 'This field cannot be empty.';
  static const tooShort = 'Too short.';
  static const noSymbols = 'Name cannot contain symbols or numbers.';
}

class ConfirmPasswordValidatorMessages {
  static const empty = 'Please confirm your password.';
  static const notMatch = 'Passwords do not match.';
}

class AddressErrorMessages {
  static const nameEmpty = 'Full name is required.';
  static const phoneEmpty = 'Phone number is required.';
  static const phoneInvalid =
      'Enter a valid Egyptian phone number (e.g. 010XXXXXXXX).';
  static const cityEmpty = 'City is required.';
  static const areaEmpty = 'Area / District is required.';
  static const streetEmpty = 'Street details are required.';
}

class SearchErrorMessages {
  static const tooShort = 'Please enter at least 2 characters to search.';
}
