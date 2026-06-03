import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/states/login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository;

  LoginCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const LoginInitial());

  Future<void> login({required String email, required String password}) async {
    emit(const LoginLoading());

    final error = await _authRepository.loginWithEmailAndPassword(email, password);
    if (isClosed) return;

    if (error == null) {
      emit(const LoginSuccess());
    } else {
      emit(LoginFailure(error));
    }
  }

  void reset() => emit(const LoginInitial());
}
