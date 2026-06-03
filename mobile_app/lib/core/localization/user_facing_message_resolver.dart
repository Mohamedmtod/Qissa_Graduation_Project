import 'package:flutter/widgets.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

String resolveUserFacingMessage(
  BuildContext context,
  Object? error, {
  String? fallback,
}) {
  final l10n = AppLocalizations.of(context);
  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return fallback ?? l10n.msgGenericTryAgainLater;
  }

  final sanitized = raw
      .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '')
      .trim();
  final normalized = sanitized.toLowerCase();

  final stockMatch = RegExp(r'only\s+(\d+)\s+items?\s+available').firstMatch(
    normalized,
  );
  if (stockMatch != null) {
    final count = int.tryParse(stockMatch.group(1) ?? '');
    if (count != null) {
      return l10n.msgOnlyItemsAvailable(count);
    }
  }

  if (normalized.contains('network-request-failed') ||
      normalized.contains('no internet connection') ||
      normalized.contains('socketexception') ||
      normalized.contains('network is unreachable')) {
    return l10n.msgNoInternetConnection;
  }
  if (normalized.contains('invalid email or password')) {
    return l10n.msgInvalidEmailOrPassword;
  }
  if (normalized.contains('no user found for that email')) {
    return l10n.msgNoUserFoundForEmail;
  }
  if (normalized.contains('valid email address') ||
      normalized == 'invalid-email' ||
      normalized.contains('invalid email')) {
    return l10n.msgInvalidEmailAddress;
  }
  if (normalized.contains('too many attempts') ||
      normalized.contains('too-many-requests')) {
    return l10n.msgTooManyAttempts;
  }
  if (normalized.contains('account already exists') ||
      normalized.contains('email-already-in-use')) {
    return l10n.msgAccountAlreadyExists;
  }
  if (normalized.contains('password provided is too weak') ||
      normalized.contains('weak-password')) {
    return l10n.msgWeakPassword;
  }
  if (normalized.contains('incorrect current password')) {
    return l10n.msgIncorrectCurrentPassword;
  }
  if (normalized.contains('not enough stock')) {
    return l10n.msgNotEnoughStockAvailable;
  }
  if (normalized.contains('failed to update quantity') ||
      normalized.contains('failed to update cart quantity') ||
      normalized.contains('failed to clear cart') ||
      normalized.contains('failed to remove item from cart')) {
    return l10n.msgCartUpdateFailed;
  }
  if (normalized.contains('failed to update wishlist') ||
      normalized.contains('failed to load wishlist')) {
    return l10n.msgWishlistLoadFailed;
  }
  if (normalized.contains('failed to load orders')) {
    return l10n.msgOrderLoadFailed;
  }
  if (normalized.contains('failed to place order')) {
    return l10n.msgOrderPlaceFailed;
  }
  if (normalized.contains('product not found')) {
    return l10n.msgProductNotFound;
  }
  if (normalized.contains('failed to update password')) {
    return l10n.msgPasswordUpdateFailed;
  }
  if (normalized.contains('error getting user') ||
      normalized.contains('failed to load profile')) {
    return l10n.msgProfileLoadFailed;
  }
  if (normalized.contains('error updating user') ||
      normalized.contains('failed to update profile')) {
    return l10n.msgProfileUpdateFailed;
  }
  if (normalized.contains('failed to save address')) {
    return l10n.msgAddressSaveFailedGeneric;
  }
  if (normalized.contains('failed to cancel restock request') ||
      normalized.contains('could not cancel request')) {
    return l10n.msgCancelRequestFailedGeneric;
  }
  if (normalized.contains('location services')) {
    return l10n.msgLocationServicesDisabled;
  }
  if (normalized.contains('location permission permanently denied') ||
      normalized.contains('permanently denied')) {
    return l10n.msgLocationPermissionPermanentlyDenied;
  }
  if (normalized.contains('location permission denied')) {
    return l10n.msgLocationPermissionDenied;
  }
  if (normalized.contains('failed to fetch address')) {
    return l10n.msgAddressLookupFailed;
  }
  if (normalized.contains('address added successfully')) {
    return l10n.msgAddressAdded;
  }
  if (normalized.contains('address updated successfully')) {
    return l10n.msgAddressUpdated;
  }
  if (normalized.contains('address deleted successfully')) {
    return l10n.msgAddressDeleted;
  }
  if (normalized.contains('default address updated')) {
    return l10n.msgDefaultAddressUpdated;
  }

  return fallback ?? l10n.msgGenericTryAgainLater;
}
