import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/features/profile/data/repos/user_repo.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_state.dart';

class UserCubit extends Cubit<UserState> {
  final UserRepo _userRepo;
  StreamSubscription<UserModel?>? _userSubscription;

  UserCubit(this._userRepo) : super(const UserInitial());

  /// Load user data once without a real-time stream
  Future<void> loadUserOnce(String uid) async {
    _cancelSubscription();
    emit(const UserLoading());
    try {
      final user = await _userRepo.getUser(uid);
      if (user != null) {
        emit(UserLoaded(user));
      } else {
        emit(const UserEmpty());
      }
    } catch (e) {
      final currentState = state;
      UserModel? oldUser;
      if (currentState is UserLoaded) oldUser = currentState.user;

      emit(UserError(e.toString(), user: oldUser));
    }
  }

  /// Listen to real-time user data updates
  void watchUser(String uid) {
    _cancelSubscription();
    emit(const UserLoading());

    _userSubscription = _userRepo
        .streamUser(uid)
        .listen(
          (user) {
            if (user != null) {
              emit(UserLoaded(user));
            } else {
              emit(const UserEmpty());
            }
          },
          onError: (error) {
            final currentState = state;
            UserModel? oldUser;
            if (currentState is UserLoaded) oldUser = currentState.user;

            emit(UserError(error.toString(), user: oldUser));
          },
        );
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel updatedUser) async {
    // Keep reference to current loaded user to revert if update fails
    final currentState = state;
    UserModel? previousUser;

    // We only want to handle updates if we have the current user data
    // but just in case, we'll try to update anyway and handle the state explicitly.
    if (currentState is UserLoaded) previousUser = currentState.user;
    if (currentState is UserUpdateSuccess) previousUser = currentState.user;

    // Use current user to prevent UI from flashing empty, fallback to updatedUser
    emit(UserUpdating(previousUser ?? updatedUser));

    try {
      await _userRepo.updateUser(updatedUser);
      emit(UserUpdateSuccess(updatedUser));
      // Optionally we could transition automatically back to UserLoaded,
      // but stream listener might handle it if watchUser is active.
      // If loadUserOnce was used, we might need to manually emit UserLoaded.

      // We'll leave it in UserUpdateSuccess momentarily so UI can react (e.g. show snackbar)
      // then return to Loaded.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed && state is UserUpdateSuccess) {
          emit(UserLoaded(updatedUser));
        }
      });
    } catch (e) {
      emit(UserError(e.toString(), user: previousUser));
      // If we had a previous user, we should revert to it
      if (previousUser != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!isClosed) emit(UserLoaded(previousUser!));
        });
      }
    }
  }

  /// Update only the user's preferred payment method
  Future<void> updatePreferredPaymentMethod(
    String? preferredPaymentMethod,
  ) async {
    final currentState = state;
    UserModel? previousUser;

    if (currentState is UserLoaded) previousUser = currentState.user;
    if (currentState is UserUpdating) previousUser = currentState.user;
    if (currentState is UserUpdateSuccess) previousUser = currentState.user;
    if (currentState is UserError) previousUser = currentState.user;

    if (previousUser == null) {
      emit(const UserError('No user loaded to update payment method.'));
      return;
    }

    String? validatedPreferredPaymentMethod;
    try {
      validatedPreferredPaymentMethod =
          PaymentMethodCodes.requireSupportedPreference(preferredPaymentMethod);
    } catch (e) {
      emit(UserError(e.toString(), user: previousUser));
      return;
    }

    final userToPersist = previousUser.copyWith(
      preferredPaymentMethod: validatedPreferredPaymentMethod,
    );

    emit(UserUpdating(userToPersist));

    try {
      await _userRepo.updatePreferredPaymentMethod(
        uid: userToPersist.uid,
        preferredPaymentMethod: validatedPreferredPaymentMethod,
      );

      final updatedUser = userToPersist.copyWith(
        preferredPaymentMethod: validatedPreferredPaymentMethod,
      );

      emit(UserUpdateSuccess(updatedUser));

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed && state is UserUpdateSuccess) {
          emit(UserLoaded(updatedUser));
        }
      });
    } catch (e) {
      emit(UserError(e.toString(), user: previousUser));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!isClosed) emit(UserLoaded(previousUser!));
      });
    }
  }

  void _cancelSubscription() {
    _userSubscription?.cancel();
    _userSubscription = null;
  }

  void clearUser() {
    _cancelSubscription();
    emit(const UserInitial());
  }

  @override
  Future<void> close() {
    _cancelSubscription();
    return super.close();
  }
}
