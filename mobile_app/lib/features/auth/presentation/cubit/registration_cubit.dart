import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/states/registration_state.dart';

class RegistrationCubit extends Cubit<RegisterState> {
  final AuthRepository _authRepository;

  RegistrationCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(RegisterInitial());

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    if (isClosed) return;
    emit(RegisterLoading());

    final error = await _authRepository.createEmailAndPassword(
      firstName,
      lastName,
      email,
      password,
    );


    if (isClosed) return;

    if (error == null) {
      emit(RegisterSuccess());
    } else {
      emit(RegisterFailure(error));
    }
  }
}
