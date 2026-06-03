// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get labelQty => 'Qty';

  @override
  String get appTitle => 'QISSA';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get labelWelcomeTitle => 'Welcome to Qissa';

  @override
  String get btnLogin => 'Log in';

  @override
  String get btnRegister => 'Create an account';

  @override
  String get hintEmail => 'Email';

  @override
  String get hintPassword => 'Password';

  @override
  String get labelLoginWelcome => 'Welcome back!\nLog in to your account';

  @override
  String get btnForgotPassword => 'Forgot password?';

  @override
  String get hintFirstName => 'First name';

  @override
  String get hintLastName => 'Last name';

  @override
  String get msgLoggingIn => 'Logging in...';

  @override
  String get msgCreatingAccount => 'Creating account...';

  @override
  String get hintConfirmPassword => 'Confirm Password';

  @override
  String get labelResetPassword => 'Reset Password';

  @override
  String get msgResetPasswordInstructions =>
      'Enter your email to receive a password reset link.';

  @override
  String get msgSending => 'Sending...';

  @override
  String get btnSendResetLink => 'Send Reset Code';

  @override
  String get msgResetLinkSent => 'Reset link sent! Check your email.';

  @override
  String get msgResetCodeInstructions =>
      'Enter your email to receive a 6-digit reset code.';

  @override
  String get msgEnterResetCodeInstructions =>
      'Enter the code sent to your email.';

  @override
  String get msgChooseNewPasswordInstructions =>
      'Choose a new password for your account.';

  @override
  String get msgResetCodeSentGeneric =>
      'If this email exists, a reset code has been sent.';

  @override
  String get msgInvalidOrExpiredCode => 'Invalid or expired code.';

  @override
  String get msgResetCodeSendFailed => 'Could not send a reset code right now.';

  @override
  String get hintResetCode => '6-digit code';

  @override
  String get btnContinue => 'Continue';

  @override
  String get btnResendCode => 'Resend code';

  @override
  String get labelCategories => 'Categories';

  @override
  String get hintSearch => 'Search';

  @override
  String get hintSearchPerfumes => 'Search for perfumes...';

  @override
  String get labelFlashSale => 'Flash Sale';

  @override
  String get btnSeeAll => 'SEE ALL';

  @override
  String get labelViewedBefore => 'Viewed Before';

  @override
  String get msgViewedBefore => 'Browse items you\'ve already viewed';

  @override
  String get btnHistory => 'HISTORY';

  @override
  String get labelMyWishlist => 'My Wishlist';

  @override
  String get msgEmptyWishlist => 'Your wishlist is empty';

  @override
  String labelPrice(String price) {
    return '$price EGP';
  }

  @override
  String get labelInStock => 'In Stock';

  @override
  String get labelOutOfStock => 'Out of Stock';

  @override
  String get labelDescription => 'Description';

  @override
  String get msgLoginToAddToCart => 'Please login to add items to cart';

  @override
  String get msgLoginToAddToWishlist =>
      'Please login to add items to your wishlist.';

  @override
  String get btnAddToCart => 'Add to Cart';

  @override
  String get labelFrequentlyBoughtTogether => 'Frequently Bought Together';

  @override
  String get msgCustomersAlsoBought =>
      'Customers who bought this item also picked these perfumes.';

  @override
  String labelConfidence(int percent) {
    return '$percent% confidence';
  }

  @override
  String labelLift(String lift) {
    return 'Lift $lift';
  }

  @override
  String get msgCancelOrderTitle => 'Cancel Order?';

  @override
  String get msgCancelOrderDesc =>
      'You can cancel only pending orders. Stock will be restored automatically.';

  @override
  String get btnNo => 'No';

  @override
  String get btnYesCancel => 'Yes, Cancel';

  @override
  String msgOrderCancelledSuccess(String id) {
    return 'Order #$id cancelled successfully.';
  }

  @override
  String get msgNoOrdersYet => 'No orders yet';

  @override
  String get msgStartShoppingOrders =>
      'Start shopping and your orders\nwill appear here';

  @override
  String get btnBrowseProducts => 'Browse Products';

  @override
  String get msgSomethingWentWrong => 'Something went wrong';

  @override
  String get btnTryAgain => 'Try Again';

  @override
  String labelOrderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String get labelNA => 'N/A';

  @override
  String labelReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get labelTotal => 'Total';

  @override
  String get btnCancelOrder => 'Cancel Order';

  @override
  String get labelStatusOrderProcessing => 'Processing';

  @override
  String get labelStatusOutForDelivery => 'Out for Delivery';

  @override
  String get labelStatusDelivered => 'Delivered';

  @override
  String get msgEmptyCart => 'Your Cart is Empty';

  @override
  String get labelOrderSummary => 'Order Summary';

  @override
  String get labelSubtotal => 'Subtotal';

  @override
  String get labelShippingFee => 'Shipping fee';

  @override
  String get labelDiscounts => 'Discounts';

  @override
  String get btnCheckout => 'CHECKOUT';

  @override
  String get labelHello => 'Hello,';

  @override
  String get labelCheckout => 'Checkout';

  @override
  String get msgFailedToLoadCart => 'Failed to load cart data';

  @override
  String get msgOrderPlacedAwaitingConfirmation =>
      'Order placed. Awaiting final confirmation...';

  @override
  String get msgSelectDeliveryAddress => 'Select Delivery Address';

  @override
  String labelCityStreet(String city, String street) {
    return '$city, $street';
  }

  @override
  String labelBuildingFloor(String building, String floor) {
    return 'Bldg $building, Floor $floor';
  }

  @override
  String get labelPayWith => 'Pay With';

  @override
  String get labelPaymentSummary => 'Payment Summary';

  @override
  String get msgPleaseSelectDeliveryAddress =>
      'Please select a delivery address first.';

  @override
  String get btnPlaceOrder => 'PLACE ORDER';

  @override
  String msgNumOfItems(int count) {
    return '$count Items';
  }

  @override
  String get labelOrderPreview => 'Order Preview';

  @override
  String get labelDeliveryInstructions => 'Delivery Instructions';

  @override
  String get hintAddDeliveryInstructions => 'Add delivery instructions...';

  @override
  String get labelMyOrders => 'My Orders';

  @override
  String get msgWhereDeliver => 'Where should we deliver?';

  @override
  String get labelPersonalInfo => 'Personal Info';

  @override
  String get labelFullName => 'Full Name';

  @override
  String get hintName => 'name';

  @override
  String get msgNameRequired => 'Name is required';

  @override
  String get msgNameNoSymbols => 'Name cannot contain symbols or numbers.';

  @override
  String get labelPhoneNumber => 'Phone Number';

  @override
  String get hintPhone => '01XXXXXXXXX';

  @override
  String get msgPhoneRequired => 'Phone is required';

  @override
  String get msgInvalidPhone => 'Enter a valid phone number';

  @override
  String get labelAddressDetails => 'Address Details';

  @override
  String get labelCity => 'City';

  @override
  String get hintCity => 'city';

  @override
  String get msgCityRequired => 'City is required';

  @override
  String get labelAreaDistrict => 'Area / District';

  @override
  String get hintArea => 'area';

  @override
  String get msgAreaRequired => 'Area is required';

  @override
  String get labelStreetDetailed => 'Street / Detailed Address';

  @override
  String get hintSearchMapOrManual => 'Search on map or enter manually';

  @override
  String get msgAddressDetailsRequired => 'Address details are required';

  @override
  String get labelBuilding => 'Building';

  @override
  String get hintBuilding => '12';

  @override
  String get labelFloorApt => 'Floor / Apt';

  @override
  String get hintFloor => '3rd';

  @override
  String get labelAdditionalNotes => 'Additional Notes';

  @override
  String get labelDeliveryNotesOptional => 'Delivery Notes (optional)';

  @override
  String get hintDeliveryNotesEx => 'Near the mosque, blue gate…';

  @override
  String get labelSettingsTitle => 'Settings';

  @override
  String get labelSetAsDefaultAddress => 'Set as Default Address';

  @override
  String get msgSuccess => 'Success';

  @override
  String get btnSaveAddress => 'SAVE ADDRESS';

  @override
  String get btnAddNewAddress => 'Add New Address';

  @override
  String get msgNoSavedAddresses => 'No saved addresses found.';

  @override
  String get labelDefault => 'Default';

  @override
  String get btnSetAsDefault => 'Set as Default';

  @override
  String get titleDeleteAddress => 'Delete Address';

  @override
  String get msgConfirmDeleteAddress =>
      'Are you sure you want to delete this address?';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnDelete => 'Delete';

  @override
  String get msgManageAndTrack => 'Manage & Track';

  @override
  String msgSavedItems(int count) {
    return '$count saved items';
  }

  @override
  String get labelAvailabilityRequests => 'My Availability Requests';

  @override
  String get msgTrackCancelRequests => 'Track and cancel Notify Me requests';

  @override
  String get labelMyAccount => 'My Account';

  @override
  String get labelAddress => 'Address';

  @override
  String get msgManageAddresses => 'Manage your addresses';

  @override
  String get labelPaymentMethods => 'Saved Cards';

  @override
  String get msgManagePaymentOptions =>
      'Manage your cards and payment preferences';

  @override
  String get msgUseCardAsDefault =>
      'Use card as the default choice at checkout';

  @override
  String get msgSelectLanguage => 'Select your language';

  @override
  String get labelSecurity => 'Security';

  @override
  String get msgChangePasswordAndMore => 'Change password & more';

  @override
  String get labelSignOut => 'Sign Out';

  @override
  String get msgLogoutFromAccount => 'Logout from your account';

  @override
  String get labelChangePassword => 'Change Password';

  @override
  String get labelEditProfile => 'Edit Profile';

  @override
  String get msgProfileUpdated => 'Profile updated successfully';

  @override
  String get labelFirstName => 'First Name';

  @override
  String get hintEnterFirstName => 'Enter your first name';

  @override
  String get msgRequiredField => 'Required field';

  @override
  String get labelLastName => 'Last Name';

  @override
  String get hintEnterLastName => 'Enter your last name';

  @override
  String get labelPhoneNumberOptional => 'Phone Number (Optional)';

  @override
  String get hintEnterPhoneNumber => 'Enter your phone number';

  @override
  String get btnSaveChanges => 'Save Changes';

  @override
  String get msgNewPasswordsDoNotMatch => 'New passwords do not match';

  @override
  String get msgPasswordUpdated => 'Password updated successfully';

  @override
  String get labelCurrentPassword => 'Current Password';

  @override
  String get hintEnterCurrentPassword => 'Enter current password';

  @override
  String get labelNewPassword => 'New Password';

  @override
  String get hintEnterNewPassword => 'Enter new password';

  @override
  String get labelConfirmNewPassword => 'Confirm New Password';

  @override
  String get hintReenterNewPassword => 'Re-enter new password';

  @override
  String get btnUpdatePassword => 'Update Password';

  @override
  String get labelCashOnDelivery => 'Cash on Delivery';

  @override
  String get msgDefaultPaymentMethod => 'Default payment method';

  @override
  String get labelDebitCreditCard => 'Debit/Credit Card';

  @override
  String get msgAddANewCard => 'Add a new card';

  @override
  String get msgPleaseLogInFirst => 'Please log in first';

  @override
  String get msgNeedAccountToTrack =>
      'You need an account to track availability requests.';

  @override
  String get msgCouldNotLoadRequests => 'Could not load requests';

  @override
  String get msgPleaseTryAgain => 'Please try again in a moment.';

  @override
  String get msgNoAvailabilityRequests => 'No availability requests yet';

  @override
  String get msgUseNotifyMeButton =>
      'Use the Notify Me button from AI recommendations when an item is out of stock.';

  @override
  String labelProductId(String id) {
    return 'Product ID: $id';
  }

  @override
  String labelRequestedDate(String date) {
    return 'Requested: $date';
  }

  @override
  String labelNotifiedDate(String date) {
    return 'Notified: $date';
  }

  @override
  String labelConvertedDate(String date) {
    return 'Converted: $date';
  }

  @override
  String labelCancelledDate(String date) {
    return 'Cancelled: $date';
  }

  @override
  String get btnCancelRequest => 'Cancel request';

  @override
  String get msgRequestCancelled => 'Request cancelled successfully.';

  @override
  String get labelStatusPending => 'Pending';

  @override
  String get labelStatusNotified => 'Notified';

  @override
  String get labelStatusPurchased => 'Purchased';

  @override
  String get labelStatusCancelled => 'Cancelled';

  @override
  String get labelTabAddress => 'Address';

  @override
  String get labelTabPickup => 'Pickup';

  @override
  String get msgPickupContentPlaceholder =>
      'Pickup content // will add it later';

  @override
  String labelQuantityFormat(int count) {
    return '×$count';
  }

  @override
  String labelFullAddressStrings(String street, String area, String city) {
    return '$street, $area, $city';
  }

  @override
  String labelFullAddressDetails(
    String city,
    String area,
    String street,
    String building,
    String floor,
  ) {
    return '$city, $area, $street, Bldg $building, Floor $floor';
  }

  @override
  String get labelDeliverTo => 'Deliver to';

  @override
  String get labelSelectAddress => 'Select Address';

  @override
  String get msgGenericTryAgainLater => 'Oops, try again later.';

  @override
  String get msgNoInternetConnection =>
      'No internet connection. Please try again.';

  @override
  String get msgInvalidEmailOrPassword => 'Invalid email or password.';

  @override
  String get msgNoUserFoundForEmail => 'No user found for that email.';

  @override
  String get msgInvalidEmailAddress => 'Please enter a valid email address.';

  @override
  String get msgTooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get msgAccountAlreadyExists =>
      'The account already exists for that email.';

  @override
  String get msgWeakPassword => 'The password provided is too weak.';

  @override
  String get msgIncorrectCurrentPassword => 'Incorrect current password.';

  @override
  String get msgAddedToCartSuccessfully => 'Added to cart successfully!';

  @override
  String get msgAddToCartFailed =>
      'Could not add this item to the cart right now.';

  @override
  String get msgNotEnoughStockAvailable => 'Not enough stock available.';

  @override
  String msgOnlyItemsAvailable(int count) {
    return 'Only $count items available in stock.';
  }

  @override
  String get msgCartUpdateFailed => 'Could not update the cart right now.';

  @override
  String get msgWishlistLoadFailed => 'Could not load your wishlist right now.';

  @override
  String get msgHomeLoadFailed => 'Could not load the home page right now.';

  @override
  String get msgSearchLoadFailed => 'Could not load search results right now.';

  @override
  String get msgProductLoadFailed =>
      'Could not load product details right now.';

  @override
  String get msgProductNotFound => 'Product not found.';

  @override
  String get msgProductUnavailable => 'This product is no longer available.';

  @override
  String get msgOrderLoadFailed => 'Could not load your orders right now.';

  @override
  String get msgOrderPlaceFailed => 'Could not place your order right now.';

  @override
  String get msgProfileLoadFailed => 'Could not load your profile right now.';

  @override
  String get msgProfileUpdateFailed =>
      'Could not update your profile right now.';

  @override
  String get msgPasswordUpdateFailed =>
      'Could not update your password right now.';

  @override
  String get msgAddressSavedSuccessfully => 'Address saved successfully.';

  @override
  String get msgAddressSaveFailedGeneric =>
      'Could not save the address right now.';

  @override
  String get msgCancelRequestFailedGeneric =>
      'Could not cancel the request right now.';

  @override
  String get msgLocationServicesDisabled =>
      'Please enable Location Services (GPS).';

  @override
  String get msgLocationPermissionDenied => 'Location permission denied.';

  @override
  String get msgLocationPermissionPermanentlyDenied =>
      'Location permission is permanently denied. Please enable it from settings.';

  @override
  String get msgEnableGpsAndPermissions =>
      'Please enable GPS and grant permissions.';

  @override
  String get msgAddressLookupFailed =>
      'Could not fetch the address for this location.';

  @override
  String get labelPickDeliveryLocation => 'Pick Delivery Location';

  @override
  String get btnConfirmLocation => 'Confirm Location';

  @override
  String get msgNoProductsFound => 'No products found.';

  @override
  String get msgNoRecentlyViewedProducts => 'No recently viewed products yet.';

  @override
  String msgNoProductsFoundForCategory(String category) {
    return 'No products found for $category.';
  }

  @override
  String get labelAIChatTitle => 'AI Assistant';

  @override
  String get tooltipNewChat => 'New Chat';

  @override
  String get msgAIChatFeedbackThankYou => 'Thanks for your feedback.';

  @override
  String get msgAIChatPrivacyDisclosure =>
      'Avoid sharing phone numbers, addresses, or payment details. Chat messages and feedback may be stored to improve recommendations and support quality review.';

  @override
  String get hintAIChatThinking => 'Thinking...';

  @override
  String hintAIChatCooldown(int seconds) {
    return 'Wait ${seconds}s before sending again...';
  }

  @override
  String get hintAIChatInput => 'Tell me what kind of perfume you want...';

  @override
  String get labelGenderMen => 'Men';

  @override
  String get labelGenderWomen => 'Women';

  @override
  String get labelGenderUnisex => 'Unisex';

  @override
  String labelPrefBudgetUnder(int amount) {
    return 'Under $amount';
  }

  @override
  String get labelPrefSeason => 'Season';

  @override
  String get labelPrefOccasion => 'Occasion';

  @override
  String get labelPrefTime => 'Time';

  @override
  String get labelPrefIntensity => 'Intensity';

  @override
  String get labelPrefNote => 'Note';

  @override
  String get labelPrefTopNote => 'Top';

  @override
  String get labelPrefMiddleNote => 'Middle';

  @override
  String get labelPrefBaseNote => 'Base';

  @override
  String get labelPrefVibe => 'Vibe';

  @override
  String get labelPrefWithout => 'Without';

  @override
  String get labelAIChatFeedbackQuestion =>
      'Were these recommendations helpful?';

  @override
  String get labelFeedbackHelpful => 'Helpful';

  @override
  String get labelFeedbackNotHelpful => 'Not helpful';

  @override
  String get hintFeedbackNote => 'Optional note (no sensitive info)';

  @override
  String get msgFeedbackSaved => 'Your feedback was saved.';

  @override
  String get labelChatWarning => 'Warning';

  @override
  String get labelFilterBy => 'Filter By';

  @override
  String get btnApplyFilters => 'Apply Filters';

  @override
  String get labelClearFilters => 'Clear All';

  @override
  String get labelGender => 'Gender';

  @override
  String get labelSeason => 'Season';

  @override
  String get labelFragranceFamily => 'Fragrance Family';

  @override
  String get labelComingSoon => 'Coming Soon';

  @override
  String get labelTestPage => 'Test Page';

  @override
  String get labelSoldOut => 'Sold';

  @override
  String get labelBestSeller => 'Best Seller';

  @override
  String get labelNew => 'New';

  @override
  String get msgNotifyMeRequestSaved =>
      'Your request was saved. We will notify you as soon as it is available.';

  @override
  String get labelNotifySaved => 'Saved';

  @override
  String get btnNotifyMe => 'Notify';

  @override
  String get btnDetails => 'Details';

  @override
  String get labelBehavioralRecommendationsTitle => 'Based on your taste';

  @override
  String get labelFallbackRecommendationsTitle => 'Recommended for you';

  @override
  String get msgAddressAdded => 'Address added successfully';

  @override
  String get msgAddressUpdated => 'Address updated successfully';

  @override
  String get msgAddressDeleted => 'Address deleted successfully';

  @override
  String get msgDefaultAddressUpdated => 'Default address updated';

  @override
  String get labelOptionSummer => 'Summer';

  @override
  String get labelOptionWinter => 'Winter';

  @override
  String get labelOptionSpring => 'Spring';

  @override
  String get labelOptionAutumn => 'Autumn';

  @override
  String get labelOptionAllSeason => 'All Season';

  @override
  String get labelOptionFloral => 'Floral';

  @override
  String get labelOptionWoody => 'Woody';

  @override
  String get labelOptionOriental => 'Oriental';

  @override
  String get labelOptionFresh => 'Fresh';

  @override
  String get labelOptionCitrus => 'Citrus';

  @override
  String get categoryPerfumes => 'Perfumes';

  @override
  String get categoryBokhoor => 'Bokhoor';

  @override
  String get categoryMabkhara => 'Mabkhara';

  @override
  String get categoryFawa7a => 'Fawa7a';

  @override
  String get categoryWatches => 'Watches';

  @override
  String get categorySunglasses => 'Sunglasses';

  @override
  String get labelNavHome => 'Home';

  @override
  String get labelNavCategories => 'Categories';

  @override
  String get labelNavAI => 'AI';

  @override
  String get labelNavCart => 'Cart';

  @override
  String get labelNavProfile => 'Profile';

  @override
  String get labelOrderSuccessful => 'Order Placed Successfully!';

  @override
  String get msgOrderProcessingAssurance =>
      'We\'ve received your order and are currently processing it.';

  @override
  String get btnTrackOrder => 'Track Order';

  @override
  String get btnContinueShopping => 'Continue Shopping';

  @override
  String get msgCartCleanupWarning =>
      'Your order was placed successfully, but we couldn\'t update your cart right now.';

  @override
  String get labelFragranceFamiliesTitle => 'Fragrance\nFamilies';

  @override
  String get labelUnsureWhereToBegin => 'Unsure where to begin?';

  @override
  String get msgAiAssistantHelp =>
      'Our Ai assistant can help you find your perfect scent match!';

  @override
  String get btnStartChatting => 'Start Chatting';

  @override
  String get descFloral => 'Petals & Blooms';

  @override
  String get labelOptionFruity => 'Fruity';

  @override
  String get descFruity => 'Bright & Juicy';

  @override
  String get descOriental => 'Spicy & Ambery';

  @override
  String get descWoody => 'Cedar &\nSandalwood';

  @override
  String get descFresh => 'citrusy & aquatic';

  @override
  String get labelOptionGourmand => 'Gourmand';

  @override
  String get descGourmand => 'Caramel & Coffee';

  @override
  String get labelOptionLeather => 'Leather';

  @override
  String get descLeather => 'Smoky Accords';

  @override
  String get labelOptionOud => 'Oud';

  @override
  String get descOud => 'Rich Oud & Smoke';

  @override
  String get btnEdit => 'Edit';

  @override
  String get msgDeliveryZoneUnavailable =>
      'Sorry, we don\'t deliver to this address at the moment.';

  @override
  String get addressGovernorate => 'Governorate';

  @override
  String get addressSelectGovernorate => 'Select governorate';

  @override
  String get addressErrGovernorateRequired => 'Governorate is required';

  @override
  String get btnRequestAccountDeletion => 'Request Account Deletion';

  @override
  String get securityDeleteAccountSubtitle =>
      'Submit a secure request for admin review';

  @override
  String get securityDeleteAccountDialogTitle =>
      'Do you want to request account deletion?';

  @override
  String get securityDeleteAccountDialogBody =>
      'Your request will be sent to the admin team for review.';

  @override
  String get btnSubmitRequest => 'Submit request';

  @override
  String get msgAccountDeletionSubmitted =>
      'Account deletion request submitted.';

  @override
  String get orderNumber => 'Order number';

  @override
  String get btnCopyID => 'Copy ID';

  @override
  String get msgOrderNumberCopied => 'Order number copied';

  @override
  String get loginWelcomeBack => 'Welcome back!';

  @override
  String get loginSubtitle => 'Log in to your account';

  @override
  String get btnCreateAccount => 'Create account';

  @override
  String get welcomeExploreProducts => 'Explore Products';

  @override
  String get btnRemoveFromCart => 'Remove from cart';

  @override
  String get btnReset => 'Reset';

  @override
  String get filterMen => 'Men';

  @override
  String get filterWomen => 'Women';

  @override
  String get filterUnisex => 'Unisex';

  @override
  String get seasonSummer => 'Summer';

  @override
  String get seasonWinter => 'Winter';

  @override
  String get seasonSpring => 'Spring';

  @override
  String get seasonAutumn => 'Autumn';

  @override
  String get seasonAllSeason => 'All Season';

  @override
  String get scentFloral => 'Floral';

  @override
  String get scentWoody => 'Woody';

  @override
  String get scentOriental => 'Oriental';

  @override
  String get scentFresh => 'Fresh';

  @override
  String get scentCitrus => 'Citrus';

  @override
  String get scentFruity => 'Fruity';

  @override
  String get scentGourmand => 'Gourmand';

  @override
  String get scentLeather => 'Leather';

  @override
  String get msgDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get msgAlreadyHaveAccount => 'Already have an account? ';
}
