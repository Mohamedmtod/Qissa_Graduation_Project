import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';

abstract class UpdatePasswordState {}

class UpdatePasswordInitial extends UpdatePasswordState {}

class UpdatePasswordLoading extends UpdatePasswordState {}

class UpdatePasswordSuccess extends UpdatePasswordState {}

class UpdatePasswordError extends UpdatePasswordState {
  final String message;
  UpdatePasswordError(this.message);
}

class UpdatePasswordCubit extends Cubit<UpdatePasswordState> {
  final AuthRepository authRepository;

  UpdatePasswordCubit({required this.authRepository}) : super(UpdatePasswordInitial());

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    emit(UpdatePasswordLoading());
    final error = await authRepository.updatePassword(currentPassword, newPassword);
    
    if (error == null) {
      emit(UpdatePasswordSuccess());
    } else {
      emit(UpdatePasswordError(error));
    }
  }
}
