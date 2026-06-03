import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Short label for Quantity
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get labelQty;

  /// The application name shown in the app bar and title
  ///
  /// In en, this message translates to:
  /// **'QISSA'**
  String get appTitle;

  /// Title shown in the app bar of the Language selection page
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for the English language option in the list
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Label for the Arabic (العربية) language option in the list
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// Title shown on the Welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Qissa'**
  String get labelWelcomeTitle;

  /// Button to navigate to login or trigger login
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get btnLogin;

  /// Button to trigger registration
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get btnRegister;

  /// Hint text for email input
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get hintEmail;

  /// Hint text for password input
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hintPassword;

  /// Header text on the Login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome back!\nLog in to your account'**
  String get labelLoginWelcome;

  /// Link to the forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get btnForgotPassword;

  /// Hint text for first name input
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get hintFirstName;

  /// Hint text for last name input
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get hintLastName;

  /// Loading text during login
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get msgLoggingIn;

  /// Loading text during account creation
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get msgCreatingAccount;

  /// Hint text for confirm password input
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get hintConfirmPassword;

  /// Header text on the Forgot Password screen
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get labelResetPassword;

  /// Body text explaining how to reset password
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a password reset link.'**
  String get msgResetPasswordInstructions;

  /// Loading text while sending the reset link
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get msgSending;

  /// Button to trigger sending the reset code
  ///
  /// In en, this message translates to:
  /// **'Send Reset Code'**
  String get btnSendResetLink;

  /// Success message after a reset link is sent
  ///
  /// In en, this message translates to:
  /// **'Reset link sent! Check your email.'**
  String get msgResetLinkSent;

  /// Body text explaining how to request a password reset OTP
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a 6-digit reset code.'**
  String get msgResetCodeInstructions;

  /// Body text explaining how to enter a password reset OTP
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email.'**
  String get msgEnterResetCodeInstructions;

  /// Body text explaining how to choose a new password after OTP
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get msgChooseNewPasswordInstructions;

  /// Generic success message that does not reveal whether an email exists
  ///
  /// In en, this message translates to:
  /// **'If this email exists, a reset code has been sent.'**
  String get msgResetCodeSentGeneric;

  /// Error shown when a password reset OTP is invalid or expired
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code.'**
  String get msgInvalidOrExpiredCode;

  /// Generic error shown when sending a password reset OTP fails
  ///
  /// In en, this message translates to:
  /// **'Could not send a reset code right now.'**
  String get msgResetCodeSendFailed;

  /// Hint text for the password reset OTP field
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get hintResetCode;

  /// Button to continue to the next form step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btnContinue;

  /// Button to resend a password reset OTP
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get btnResendCode;

  /// Header for categories section
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get labelCategories;

  /// Short hint text for search field
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get hintSearch;

  /// Longer hint text for the main search page
  ///
  /// In en, this message translates to:
  /// **'Search for perfumes...'**
  String get hintSearchPerfumes;

  /// Header for flash sale section
  ///
  /// In en, this message translates to:
  /// **'Flash Sale'**
  String get labelFlashSale;

  /// Button to see all items in a category/section
  ///
  /// In en, this message translates to:
  /// **'SEE ALL'**
  String get btnSeeAll;

  /// Header for recently viewed products
  ///
  /// In en, this message translates to:
  /// **'Viewed Before'**
  String get labelViewedBefore;

  /// Subtitle for the recently viewed products section
  ///
  /// In en, this message translates to:
  /// **'Browse items you\'ve already viewed'**
  String get msgViewedBefore;

  /// Button to view product history
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get btnHistory;

  /// Title for the wishlist page
  ///
  /// In en, this message translates to:
  /// **'My Wishlist'**
  String get labelMyWishlist;

  /// Message shown when wishlist has no items
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get msgEmptyWishlist;

  /// Format for displaying price
  ///
  /// In en, this message translates to:
  /// **'{price} EGP'**
  String labelPrice(String price);

  /// Label indicating a product is available
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get labelInStock;

  /// Label indicating a product is out of stock
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get labelOutOfStock;

  /// Header for the product description section
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get labelDescription;

  /// Message prompting user to login before adding to cart
  ///
  /// In en, this message translates to:
  /// **'Please login to add items to cart'**
  String get msgLoginToAddToCart;

  /// Message prompting user to login before adding to wishlist
  ///
  /// In en, this message translates to:
  /// **'Please login to add items to your wishlist.'**
  String get msgLoginToAddToWishlist;

  /// Button to add an item to the shopping cart
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get btnAddToCart;

  /// Header for frequent recommendations
  ///
  /// In en, this message translates to:
  /// **'Frequently Bought Together'**
  String get labelFrequentlyBoughtTogether;

  /// Description text for frequent recommendations
  ///
  /// In en, this message translates to:
  /// **'Customers who bought this item also picked these perfumes.'**
  String get msgCustomersAlsoBought;

  /// Metric showing AI recommendation confidence
  ///
  /// In en, this message translates to:
  /// **'{percent}% confidence'**
  String labelConfidence(int percent);

  /// Metric showing recommendation lift
  ///
  /// In en, this message translates to:
  /// **'Lift {lift}'**
  String labelLift(String lift);

  /// Title for cancel order dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel Order?'**
  String get msgCancelOrderTitle;

  /// Description for cancel order dialog
  ///
  /// In en, this message translates to:
  /// **'You can cancel only pending orders. Stock will be restored automatically.'**
  String get msgCancelOrderDesc;

  /// No button
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get btnNo;

  /// Yes cancel button
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get btnYesCancel;

  /// Success message for cancelled order
  ///
  /// In en, this message translates to:
  /// **'Order #{id} cancelled successfully.'**
  String msgOrderCancelledSuccess(String id);

  /// Title when no orders exist
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get msgNoOrdersYet;

  /// Subtitle when no orders exist
  ///
  /// In en, this message translates to:
  /// **'Start shopping and your orders\nwill appear here'**
  String get msgStartShoppingOrders;

  /// Button to browse products
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get btnBrowseProducts;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get msgSomethingWentWrong;

  /// Try again button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get btnTryAgain;

  /// Order number display
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String labelOrderNumber(String id);

  /// Not available
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get labelNA;

  /// Failure reason
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String labelReason(String reason);

  /// Total amount
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get labelTotal;

  /// Button to cancel order
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get btnCancelOrder;

  /// Order processing status
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get labelStatusOrderProcessing;

  /// Out for delivery status
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get labelStatusOutForDelivery;

  /// Delivered status
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get labelStatusDelivered;

  /// Title when cart is empty
  ///
  /// In en, this message translates to:
  /// **'Your Cart is Empty'**
  String get msgEmptyCart;

  /// Header for order summary section
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get labelOrderSummary;

  /// Subtotal label
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get labelSubtotal;

  /// Shipping fee label
  ///
  /// In en, this message translates to:
  /// **'Shipping fee'**
  String get labelShippingFee;

  /// Discounts label
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get labelDiscounts;

  /// Checkout button
  ///
  /// In en, this message translates to:
  /// **'CHECKOUT'**
  String get btnCheckout;

  /// Greeting in profile page
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get labelHello;

  /// Checkout page title
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get labelCheckout;

  /// Error message when cart fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load cart data'**
  String get msgFailedToLoadCart;

  /// Success message after placing order
  ///
  /// In en, this message translates to:
  /// **'Order placed. Awaiting final confirmation...'**
  String get msgOrderPlacedAwaitingConfirmation;

  /// Prompt to select an address
  ///
  /// In en, this message translates to:
  /// **'Select Delivery Address'**
  String get msgSelectDeliveryAddress;

  /// Format for city and street
  ///
  /// In en, this message translates to:
  /// **'{city}, {street}'**
  String labelCityStreet(String city, String street);

  /// Format for building and floor
  ///
  /// In en, this message translates to:
  /// **'Bldg {building}, Floor {floor}'**
  String labelBuildingFloor(String building, String floor);

  /// Payment method section header
  ///
  /// In en, this message translates to:
  /// **'Pay With'**
  String get labelPayWith;

  /// Payment summary header
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get labelPaymentSummary;

  /// Error when no address is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery address first.'**
  String get msgPleaseSelectDeliveryAddress;

  /// Button to place the order
  ///
  /// In en, this message translates to:
  /// **'PLACE ORDER'**
  String get btnPlaceOrder;

  /// Number of items in cart
  ///
  /// In en, this message translates to:
  /// **'{count} Items'**
  String msgNumOfItems(int count);

  /// Order preview section header
  ///
  /// In en, this message translates to:
  /// **'Order Preview'**
  String get labelOrderPreview;

  /// Delivery instructions section header
  ///
  /// In en, this message translates to:
  /// **'Delivery Instructions'**
  String get labelDeliveryInstructions;

  /// Hint text for delivery notes
  ///
  /// In en, this message translates to:
  /// **'Add delivery instructions...'**
  String get hintAddDeliveryInstructions;

  /// Title for orders section
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get labelMyOrders;

  /// Header for address page
  ///
  /// In en, this message translates to:
  /// **'Where should we deliver?'**
  String get msgWhereDeliver;

  /// Header for personal info
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get labelPersonalInfo;

  /// Full name label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get labelFullName;

  /// Name hint
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get hintName;

  /// Validation error for name
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get msgNameRequired;

  /// Validation error for name containing symbols
  ///
  /// In en, this message translates to:
  /// **'Name cannot contain symbols or numbers.'**
  String get msgNameNoSymbols;

  /// Phone number label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get labelPhoneNumber;

  /// Phone number hint
  ///
  /// In en, this message translates to:
  /// **'01XXXXXXXXX'**
  String get hintPhone;

  /// Validation error for phone
  ///
  /// In en, this message translates to:
  /// **'Phone is required'**
  String get msgPhoneRequired;

  /// Validation error for invalid phone
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get msgInvalidPhone;

  /// Header for address details
  ///
  /// In en, this message translates to:
  /// **'Address Details'**
  String get labelAddressDetails;

  /// City label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get labelCity;

  /// City hint
  ///
  /// In en, this message translates to:
  /// **'city'**
  String get hintCity;

  /// Validation error for city
  ///
  /// In en, this message translates to:
  /// **'City is required'**
  String get msgCityRequired;

  /// Area label
  ///
  /// In en, this message translates to:
  /// **'Area / District'**
  String get labelAreaDistrict;

  /// Area hint
  ///
  /// In en, this message translates to:
  /// **'area'**
  String get hintArea;

  /// Validation error for area
  ///
  /// In en, this message translates to:
  /// **'Area is required'**
  String get msgAreaRequired;

  /// Street address label
  ///
  /// In en, this message translates to:
  /// **'Street / Detailed Address'**
  String get labelStreetDetailed;

  /// Hint for street input
  ///
  /// In en, this message translates to:
  /// **'Search on map or enter manually'**
  String get hintSearchMapOrManual;

  /// Validation error for street
  ///
  /// In en, this message translates to:
  /// **'Address details are required'**
  String get msgAddressDetailsRequired;

  /// Building label
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get labelBuilding;

  /// Building hint
  ///
  /// In en, this message translates to:
  /// **'12'**
  String get hintBuilding;

  /// Floor label
  ///
  /// In en, this message translates to:
  /// **'Floor / Apt'**
  String get labelFloorApt;

  /// Floor hint
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get hintFloor;

  /// Additional notes header
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get labelAdditionalNotes;

  /// Notes label
  ///
  /// In en, this message translates to:
  /// **'Delivery Notes (optional)'**
  String get labelDeliveryNotesOptional;

  /// Notes hint
  ///
  /// In en, this message translates to:
  /// **'Near the mosque, blue gate…'**
  String get hintDeliveryNotesEx;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get labelSettingsTitle;

  /// Toggle to set address as default
  ///
  /// In en, this message translates to:
  /// **'Set as Default Address'**
  String get labelSetAsDefaultAddress;

  /// Generic success message
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get msgSuccess;

  /// Button to save address
  ///
  /// In en, this message translates to:
  /// **'SAVE ADDRESS'**
  String get btnSaveAddress;

  /// Button to add new address
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get btnAddNewAddress;

  /// Empty state for addresses list
  ///
  /// In en, this message translates to:
  /// **'No saved addresses found.'**
  String get msgNoSavedAddresses;

  /// Default address badge
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get labelDefault;

  /// Button to set as default
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get btnSetAsDefault;

  /// Dialog title for delete address
  ///
  /// In en, this message translates to:
  /// **'Delete Address'**
  String get titleDeleteAddress;

  /// Dialog confirmation for delete
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this address?'**
  String get msgConfirmDeleteAddress;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btnDelete;

  /// Subtitle for orders section
  ///
  /// In en, this message translates to:
  /// **'Manage & Track'**
  String get msgManageAndTrack;

  /// Subtitle for wishlist showing count
  ///
  /// In en, this message translates to:
  /// **'{count} saved items'**
  String msgSavedItems(int count);

  /// Title for restock requests
  ///
  /// In en, this message translates to:
  /// **'My Availability Requests'**
  String get labelAvailabilityRequests;

  /// Subtitle for restock requests
  ///
  /// In en, this message translates to:
  /// **'Track and cancel Notify Me requests'**
  String get msgTrackCancelRequests;

  /// Header for account section
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get labelMyAccount;

  /// Title for address section
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelAddress;

  /// Subtitle for address section
  ///
  /// In en, this message translates to:
  /// **'Manage your addresses'**
  String get msgManageAddresses;

  /// Title for payment methods
  ///
  /// In en, this message translates to:
  /// **'Saved Cards'**
  String get labelPaymentMethods;

  /// Subtitle for payment methods
  ///
  /// In en, this message translates to:
  /// **'Manage your cards and payment preferences'**
  String get msgManagePaymentOptions;

  /// Helper text for enabling saved card preference
  ///
  /// In en, this message translates to:
  /// **'Use card as the default choice at checkout'**
  String get msgUseCardAsDefault;

  /// Subtitle for language section
  ///
  /// In en, this message translates to:
  /// **'Select your language'**
  String get msgSelectLanguage;

  /// Title for security section
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get labelSecurity;

  /// Subtitle for security section
  ///
  /// In en, this message translates to:
  /// **'Change password & more'**
  String get msgChangePasswordAndMore;

  /// Title for sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get labelSignOut;

  /// Subtitle for sign out
  ///
  /// In en, this message translates to:
  /// **'Logout from your account'**
  String get msgLogoutFromAccount;

  /// Title for change password page
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get labelChangePassword;

  /// Title for edit profile page
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get labelEditProfile;

  /// Success message when profile is updated
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get msgProfileUpdated;

  /// Label for first name field
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get labelFirstName;

  /// Hint for first name field
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get hintEnterFirstName;

  /// Validation message for a required field
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get msgRequiredField;

  /// Label for last name field
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get labelLastName;

  /// Hint for last name field
  ///
  /// In en, this message translates to:
  /// **'Enter your last name'**
  String get hintEnterLastName;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Optional)'**
  String get labelPhoneNumberOptional;

  /// Hint for phone number field
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get hintEnterPhoneNumber;

  /// Button to save profile changes
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get btnSaveChanges;

  /// Validation message when new passwords don't match
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match'**
  String get msgNewPasswordsDoNotMatch;

  /// Success message when password is updated
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get msgPasswordUpdated;

  /// Label for current password field
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get labelCurrentPassword;

  /// Hint for current password field
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get hintEnterCurrentPassword;

  /// Label for new password field
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get labelNewPassword;

  /// Hint for new password field
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get hintEnterNewPassword;

  /// Label for confirm password field
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get labelConfirmNewPassword;

  /// Hint for confirm password field
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get hintReenterNewPassword;

  /// Button to submit new password
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get btnUpdatePassword;

  /// Cash on delivery payment method
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get labelCashOnDelivery;

  /// Subtitle indicating default payment
  ///
  /// In en, this message translates to:
  /// **'Default payment method'**
  String get msgDefaultPaymentMethod;

  /// Credit card payment method
  ///
  /// In en, this message translates to:
  /// **'Debit/Credit Card'**
  String get labelDebitCreditCard;

  /// Subtitle indicating to add new card
  ///
  /// In en, this message translates to:
  /// **'Add a new card'**
  String get msgAddANewCard;

  /// Title when user needs to login
  ///
  /// In en, this message translates to:
  /// **'Please log in first'**
  String get msgPleaseLogInFirst;

  /// Explanation why login is needed
  ///
  /// In en, this message translates to:
  /// **'You need an account to track availability requests.'**
  String get msgNeedAccountToTrack;

  /// Title when requests fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load requests'**
  String get msgCouldNotLoadRequests;

  /// Subtitle for error state
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get msgPleaseTryAgain;

  /// Title for empty request list
  ///
  /// In en, this message translates to:
  /// **'No availability requests yet'**
  String get msgNoAvailabilityRequests;

  /// Explanation for how to make a request
  ///
  /// In en, this message translates to:
  /// **'Use the Notify Me button from AI recommendations when an item is out of stock.'**
  String get msgUseNotifyMeButton;

  /// Prefix for product ID
  ///
  /// In en, this message translates to:
  /// **'Product ID: {id}'**
  String labelProductId(String id);

  /// Prefix for requested date
  ///
  /// In en, this message translates to:
  /// **'Requested: {date}'**
  String labelRequestedDate(String date);

  /// Prefix for notified date
  ///
  /// In en, this message translates to:
  /// **'Notified: {date}'**
  String labelNotifiedDate(String date);

  /// Prefix for converted date
  ///
  /// In en, this message translates to:
  /// **'Converted: {date}'**
  String labelConvertedDate(String date);

  /// Prefix for cancelled date
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {date}'**
  String labelCancelledDate(String date);

  /// Button to cancel a restock request
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get btnCancelRequest;

  /// Success message when request is cancelled
  ///
  /// In en, this message translates to:
  /// **'Request cancelled successfully.'**
  String get msgRequestCancelled;

  /// Status pending for restock request
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get labelStatusPending;

  /// Status notified for restock request
  ///
  /// In en, this message translates to:
  /// **'Notified'**
  String get labelStatusNotified;

  /// Status purchased for restock request
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get labelStatusPurchased;

  /// Status cancelled for restock request
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get labelStatusCancelled;

  /// Tab label for Address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelTabAddress;

  /// Tab label for Pickup
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get labelTabPickup;

  /// Placeholder for pickup tab content
  ///
  /// In en, this message translates to:
  /// **'Pickup content // will add it later'**
  String get msgPickupContentPlaceholder;

  /// Format for item quantity
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String labelQuantityFormat(int count);

  /// Format for displaying a full address line
  ///
  /// In en, this message translates to:
  /// **'{street}, {area}, {city}'**
  String labelFullAddressStrings(String street, String area, String city);

  /// Format for full address including building and floor
  ///
  /// In en, this message translates to:
  /// **'{city}, {area}, {street}, Bldg {building}, Floor {floor}'**
  String labelFullAddressDetails(
    String city,
    String area,
    String street,
    String building,
    String floor,
  );

  /// Label for delivery header
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get labelDeliverTo;

  /// Placeholder for when no address is selected
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get labelSelectAddress;

  /// Generic fallback error message
  ///
  /// In en, this message translates to:
  /// **'Oops, try again later.'**
  String get msgGenericTryAgainLater;

  /// Error shown when network is unavailable
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please try again.'**
  String get msgNoInternetConnection;

  /// Login failure for invalid credentials
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get msgInvalidEmailOrPassword;

  /// Login or reset failure when email is not registered
  ///
  /// In en, this message translates to:
  /// **'No user found for that email.'**
  String get msgNoUserFoundForEmail;

  /// Error shown for invalid email address
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get msgInvalidEmailAddress;

  /// Error shown when too many auth attempts were made
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get msgTooManyAttempts;

  /// Registration failure for existing account
  ///
  /// In en, this message translates to:
  /// **'The account already exists for that email.'**
  String get msgAccountAlreadyExists;

  /// Registration or password update error for weak password
  ///
  /// In en, this message translates to:
  /// **'The password provided is too weak.'**
  String get msgWeakPassword;

  /// Password update error when current password is wrong
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password.'**
  String get msgIncorrectCurrentPassword;

  /// Success message after adding an item to the cart
  ///
  /// In en, this message translates to:
  /// **'Added to cart successfully!'**
  String get msgAddedToCartSuccessfully;

  /// Fallback error when add to cart fails
  ///
  /// In en, this message translates to:
  /// **'Could not add this item to the cart right now.'**
  String get msgAddToCartFailed;

  /// Error shown when requested quantity exceeds stock
  ///
  /// In en, this message translates to:
  /// **'Not enough stock available.'**
  String get msgNotEnoughStockAvailable;

  /// Error shown when only a limited number of items are available
  ///
  /// In en, this message translates to:
  /// **'Only {count} items available in stock.'**
  String msgOnlyItemsAvailable(int count);

  /// Fallback error when cart changes fail
  ///
  /// In en, this message translates to:
  /// **'Could not update the cart right now.'**
  String get msgCartUpdateFailed;

  /// Error shown when wishlist loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load your wishlist right now.'**
  String get msgWishlistLoadFailed;

  /// Error shown when home data fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load the home page right now.'**
  String get msgHomeLoadFailed;

  /// Error shown when search loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load search results right now.'**
  String get msgSearchLoadFailed;

  /// Error shown when product details fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load product details right now.'**
  String get msgProductLoadFailed;

  /// Error shown when a product cannot be found
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get msgProductNotFound;

  /// Message shown when a product is hidden or inactive
  ///
  /// In en, this message translates to:
  /// **'This product is no longer available.'**
  String get msgProductUnavailable;

  /// Error shown when orders loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load your orders right now.'**
  String get msgOrderLoadFailed;

  /// Error shown when placing an order fails
  ///
  /// In en, this message translates to:
  /// **'Could not place your order right now.'**
  String get msgOrderPlaceFailed;

  /// Error shown when profile loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile right now.'**
  String get msgProfileLoadFailed;

  /// Error shown when profile update fails
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile right now.'**
  String get msgProfileUpdateFailed;

  /// Error shown when password update fails
  ///
  /// In en, this message translates to:
  /// **'Could not update your password right now.'**
  String get msgPasswordUpdateFailed;

  /// Success message after saving an address
  ///
  /// In en, this message translates to:
  /// **'Address saved successfully.'**
  String get msgAddressSavedSuccessfully;

  /// Fallback error when saving an address fails
  ///
  /// In en, this message translates to:
  /// **'Could not save the address right now.'**
  String get msgAddressSaveFailedGeneric;

  /// Fallback error when cancelling a restock request fails
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the request right now.'**
  String get msgCancelRequestFailedGeneric;

  /// Error shown when device location services are off
  ///
  /// In en, this message translates to:
  /// **'Please enable Location Services (GPS).'**
  String get msgLocationServicesDisabled;

  /// Error shown when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get msgLocationPermissionDenied;

  /// Error shown when location permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Please enable it from settings.'**
  String get msgLocationPermissionPermanentlyDenied;

  /// Empty state message for location picker when GPS or permissions are missing
  ///
  /// In en, this message translates to:
  /// **'Please enable GPS and grant permissions.'**
  String get msgEnableGpsAndPermissions;

  /// Error shown when reverse geocoding fails
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the address for this location.'**
  String get msgAddressLookupFailed;

  /// Title for the location picker page
  ///
  /// In en, this message translates to:
  /// **'Pick Delivery Location'**
  String get labelPickDeliveryLocation;

  /// Button to confirm the currently picked map location
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get btnConfirmLocation;

  /// Empty state message for product searches with no results
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get msgNoProductsFound;

  /// Empty state message when there are no recently viewed products
  ///
  /// In en, this message translates to:
  /// **'No recently viewed products yet.'**
  String get msgNoRecentlyViewedProducts;

  /// Empty state message when a category has no products
  ///
  /// In en, this message translates to:
  /// **'No products found for {category}.'**
  String msgNoProductsFoundForCategory(String category);

  /// Title of the AI Chat page in the AppBar
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get labelAIChatTitle;

  /// Tooltip for the refresh/new-chat button in AI Chat AppBar
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get tooltipNewChat;

  /// Snackbar shown after a feedback is successfully submitted
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback.'**
  String get msgAIChatFeedbackThankYou;

  /// Short privacy disclosure shown near the AI chat interface
  ///
  /// In en, this message translates to:
  /// **'Avoid sharing phone numbers, addresses, or payment details. Chat messages and feedback may be stored to improve recommendations and support quality review.'**
  String get msgAIChatPrivacyDisclosure;

  /// Hint text and loading bubble text while AI is processing
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get hintAIChatThinking;

  /// Hint text shown in input field during cooldown period
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds}s before sending again...'**
  String hintAIChatCooldown(int seconds);

  /// Default hint text for the AI chat message input field
  ///
  /// In en, this message translates to:
  /// **'Tell me what kind of perfume you want...'**
  String get hintAIChatInput;

  /// Gender tag label: Men
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get labelGenderMen;

  /// Gender tag label: Women
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get labelGenderWomen;

  /// Gender tag label: Unisex
  ///
  /// In en, this message translates to:
  /// **'Unisex'**
  String get labelGenderUnisex;

  /// Preference bar chip showing budget ceiling
  ///
  /// In en, this message translates to:
  /// **'Under {amount}'**
  String labelPrefBudgetUnder(int amount);

  /// Prefix label for season preference chip
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get labelPrefSeason;

  /// Prefix label for occasion preference chip
  ///
  /// In en, this message translates to:
  /// **'Occasion'**
  String get labelPrefOccasion;

  /// Prefix label for time-of-day preference chip
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get labelPrefTime;

  /// Prefix label for intensity preference chip
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get labelPrefIntensity;

  /// Prefix label for preferred-notes chip
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get labelPrefNote;

  /// Prefix label for preferred top-notes chip
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get labelPrefTopNote;

  /// Prefix label for preferred middle-notes chip
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get labelPrefMiddleNote;

  /// Prefix label for preferred base-notes chip
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get labelPrefBaseNote;

  /// Prefix label for vibe / mood tags chip
  ///
  /// In en, this message translates to:
  /// **'Vibe'**
  String get labelPrefVibe;

  /// Prefix label for excluded-notes chip
  ///
  /// In en, this message translates to:
  /// **'Without'**
  String get labelPrefWithout;

  /// Feedback form header asking if recommendations were helpful
  ///
  /// In en, this message translates to:
  /// **'Were these recommendations helpful?'**
  String get labelAIChatFeedbackQuestion;

  /// Label for the thumbs-up (helpful) feedback button
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get labelFeedbackHelpful;

  /// Label for the thumbs-down (not helpful) feedback button
  ///
  /// In en, this message translates to:
  /// **'Not helpful'**
  String get labelFeedbackNotHelpful;

  /// Hint text in the optional feedback note field
  ///
  /// In en, this message translates to:
  /// **'Optional note (no sensitive info)'**
  String get hintFeedbackNote;

  /// Confirmation text shown below feedback form after submission
  ///
  /// In en, this message translates to:
  /// **'Your feedback was saved.'**
  String get msgFeedbackSaved;

  /// Warning label shown below an error message bubble in AI Chat
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get labelChatWarning;

  /// Header title for the filter bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Filter By'**
  String get labelFilterBy;

  /// Button to apply selected filters
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get btnApplyFilters;

  /// Button to clear all active filters
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get labelClearFilters;

  /// Filter section title for gender
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get labelGender;

  /// Filter section title for season
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get labelSeason;

  /// Filter section title for fragrance family
  ///
  /// In en, this message translates to:
  /// **'Fragrance Family'**
  String get labelFragranceFamily;

  /// Placeholder text when a product section has no items yet
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get labelComingSoon;

  /// Title for the development test page
  ///
  /// In en, this message translates to:
  /// **'Test Page'**
  String get labelTestPage;

  /// Badge label when a product is out of stock in AI recommendations
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get labelSoldOut;

  /// Badge label when a product is a best seller
  ///
  /// In en, this message translates to:
  /// **'Best Seller'**
  String get labelBestSeller;

  /// Badge label when a product is new
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get labelNew;

  /// Snackbar message confirming a restock notification request
  ///
  /// In en, this message translates to:
  /// **'Your request was saved. We will notify you as soon as it is available.'**
  String get msgNotifyMeRequestSaved;

  /// Button label after a notify-me request has been saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get labelNotifySaved;

  /// Button to request notification when product is back in stock
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get btnNotifyMe;

  /// Button to view product details from AI recommendation card
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get btnDetails;

  /// Title shown for behavioral recommendation source
  ///
  /// In en, this message translates to:
  /// **'Based on your taste'**
  String get labelBehavioralRecommendationsTitle;

  /// Title shown for fallback recommendation source
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get labelFallbackRecommendationsTitle;

  /// Success message after adding a new address
  ///
  /// In en, this message translates to:
  /// **'Address added successfully'**
  String get msgAddressAdded;

  /// Success message after updating an address
  ///
  /// In en, this message translates to:
  /// **'Address updated successfully'**
  String get msgAddressUpdated;

  /// Success message after deleting an address
  ///
  /// In en, this message translates to:
  /// **'Address deleted successfully'**
  String get msgAddressDeleted;

  /// Success message after changing the default address
  ///
  /// In en, this message translates to:
  /// **'Default address updated'**
  String get msgDefaultAddressUpdated;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get labelOptionSummer;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get labelOptionWinter;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get labelOptionSpring;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get labelOptionAutumn;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'All Season'**
  String get labelOptionAllSeason;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Floral'**
  String get labelOptionFloral;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Woody'**
  String get labelOptionWoody;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Oriental'**
  String get labelOptionOriental;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get labelOptionFresh;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Citrus'**
  String get labelOptionCitrus;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Perfumes'**
  String get categoryPerfumes;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Bokhoor'**
  String get categoryBokhoor;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Mabkhara'**
  String get categoryMabkhara;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Fawa7a'**
  String get categoryFawa7a;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Watches'**
  String get categoryWatches;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Sunglasses'**
  String get categorySunglasses;

  /// Navigation bar label for Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get labelNavHome;

  /// Navigation bar label for Categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get labelNavCategories;

  /// Navigation bar label for AI Assistant
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get labelNavAI;

  /// Navigation bar label for Cart
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get labelNavCart;

  /// Navigation bar label for Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get labelNavProfile;

  /// Title shown when order is placed successfully
  ///
  /// In en, this message translates to:
  /// **'Order Placed Successfully!'**
  String get labelOrderSuccessful;

  /// Assurance message shown on order success page
  ///
  /// In en, this message translates to:
  /// **'We\'ve received your order and are currently processing it.'**
  String get msgOrderProcessingAssurance;

  /// Button to track the order from the success page
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get btnTrackOrder;

  /// Button to continue shopping from the success page
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get btnContinueShopping;

  /// Warning shown when order succeeds but cart clearing fails
  ///
  /// In en, this message translates to:
  /// **'Your order was placed successfully, but we couldn\'t update your cart right now.'**
  String get msgCartCleanupWarning;

  /// Title for Fragrance Families section
  ///
  /// In en, this message translates to:
  /// **'Fragrance\nFamilies'**
  String get labelFragranceFamiliesTitle;

  /// Title for AI assistant banner
  ///
  /// In en, this message translates to:
  /// **'Unsure where to begin?'**
  String get labelUnsureWhereToBegin;

  /// Message for AI assistant banner
  ///
  /// In en, this message translates to:
  /// **'Our Ai assistant can help you find your perfect scent match!'**
  String get msgAiAssistantHelp;

  /// Button to start AI chat
  ///
  /// In en, this message translates to:
  /// **'Start Chatting'**
  String get btnStartChatting;

  /// Description for Floral category
  ///
  /// In en, this message translates to:
  /// **'Petals & Blooms'**
  String get descFloral;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Fruity'**
  String get labelOptionFruity;

  /// Description for Fruity category
  ///
  /// In en, this message translates to:
  /// **'Bright & Juicy'**
  String get descFruity;

  /// Description for Oriental category
  ///
  /// In en, this message translates to:
  /// **'Spicy & Ambery'**
  String get descOriental;

  /// Description for Woody category
  ///
  /// In en, this message translates to:
  /// **'Cedar &\nSandalwood'**
  String get descWoody;

  /// Description for Fresh category
  ///
  /// In en, this message translates to:
  /// **'citrusy & aquatic'**
  String get descFresh;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Gourmand'**
  String get labelOptionGourmand;

  /// Description for Gourmand category
  ///
  /// In en, this message translates to:
  /// **'Caramel & Coffee'**
  String get descGourmand;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Leather'**
  String get labelOptionLeather;

  /// Description for Leather category
  ///
  /// In en, this message translates to:
  /// **'Smoky Accords'**
  String get descLeather;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Oud'**
  String get labelOptionOud;

  /// Description for Oud category
  ///
  /// In en, this message translates to:
  /// **'Rich Oud & Smoke'**
  String get descOud;

  /// Tooltip/label for edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get btnEdit;

  /// Error shown when delivery zone is disabled
  ///
  /// In en, this message translates to:
  /// **'Sorry, we don\'t deliver to this address at the moment.'**
  String get msgDeliveryZoneUnavailable;

  /// No description provided for @addressGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get addressGovernorate;

  /// No description provided for @addressSelectGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Select governorate'**
  String get addressSelectGovernorate;

  /// No description provided for @addressErrGovernorateRequired.
  ///
  /// In en, this message translates to:
  /// **'Governorate is required'**
  String get addressErrGovernorateRequired;

  /// No description provided for @btnRequestAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request Account Deletion'**
  String get btnRequestAccountDeletion;

  /// No description provided for @securityDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a secure request for admin review'**
  String get securityDeleteAccountSubtitle;

  /// No description provided for @securityDeleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you want to request account deletion?'**
  String get securityDeleteAccountDialogTitle;

  /// No description provided for @securityDeleteAccountDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Your request will be sent to the admin team for review.'**
  String get securityDeleteAccountDialogBody;

  /// No description provided for @btnSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get btnSubmitRequest;

  /// No description provided for @msgAccountDeletionSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Account deletion request submitted.'**
  String get msgAccountDeletionSubmitted;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNumber;

  /// No description provided for @btnCopyID.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get btnCopyID;

  /// No description provided for @msgOrderNumberCopied.
  ///
  /// In en, this message translates to:
  /// **'Order number copied'**
  String get msgOrderNumberCopied;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account'**
  String get loginSubtitle;

  /// No description provided for @btnCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get btnCreateAccount;

  /// No description provided for @welcomeExploreProducts.
  ///
  /// In en, this message translates to:
  /// **'Explore Products'**
  String get welcomeExploreProducts;

  /// No description provided for @btnRemoveFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove from cart'**
  String get btnRemoveFromCart;

  /// No description provided for @btnReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get btnReset;

  /// No description provided for @filterMen.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get filterMen;

  /// No description provided for @filterWomen.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get filterWomen;

  /// No description provided for @filterUnisex.
  ///
  /// In en, this message translates to:
  /// **'Unisex'**
  String get filterUnisex;

  /// No description provided for @seasonSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get seasonSummer;

  /// No description provided for @seasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get seasonWinter;

  /// No description provided for @seasonSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get seasonSpring;

  /// No description provided for @seasonAutumn.
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get seasonAutumn;

  /// No description provided for @seasonAllSeason.
  ///
  /// In en, this message translates to:
  /// **'All Season'**
  String get seasonAllSeason;

  /// No description provided for @scentFloral.
  ///
  /// In en, this message translates to:
  /// **'Floral'**
  String get scentFloral;

  /// No description provided for @scentWoody.
  ///
  /// In en, this message translates to:
  /// **'Woody'**
  String get scentWoody;

  /// No description provided for @scentOriental.
  ///
  /// In en, this message translates to:
  /// **'Oriental'**
  String get scentOriental;

  /// No description provided for @scentFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get scentFresh;

  /// No description provided for @scentCitrus.
  ///
  /// In en, this message translates to:
  /// **'Citrus'**
  String get scentCitrus;

  /// No description provided for @scentFruity.
  ///
  /// In en, this message translates to:
  /// **'Fruity'**
  String get scentFruity;

  /// No description provided for @scentGourmand.
  ///
  /// In en, this message translates to:
  /// **'Gourmand'**
  String get scentGourmand;

  /// No description provided for @scentLeather.
  ///
  /// In en, this message translates to:
  /// **'Leather'**
  String get scentLeather;

  /// No description provided for @msgDontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get msgDontHaveAccount;

  /// No description provided for @msgAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get msgAlreadyHaveAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
