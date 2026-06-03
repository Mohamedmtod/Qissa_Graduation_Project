import 'package:equatable/equatable.dart';

enum ForgotPasswordStep { email, otp, password }

abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object> get props => [];
}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {
  final ForgotPasswordStep step;

  const ForgotPasswordLoading(this.step);

  @override
  List<Object> get props => [step];
}

class ForgotPasswordCodeSent extends ForgotPasswordState {
  final String email;

  const ForgotPasswordCodeSent(this.email);

  @override
  List<Object> get props => [email];
}

class ForgotPasswordOtpVerified extends ForgotPasswordState {}

class ForgotPasswordSuccess extends ForgotPasswordState {}

class ForgotPasswordFailure extends ForgotPasswordState {
  final String message;
  final ForgotPasswordStep step;

  const ForgotPasswordFailure(this.message, this.step);

  @override
  List<Object> get props => [message, step];
}
