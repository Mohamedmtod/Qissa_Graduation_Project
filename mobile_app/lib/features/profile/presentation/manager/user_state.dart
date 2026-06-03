import 'package:equatable/equatable.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';

abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {
  const UserInitial();
}

class UserLoading extends UserState {
  const UserLoading();
}

class UserLoaded extends UserState {
  final UserModel user;

  const UserLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

class UserEmpty extends UserState {
  const UserEmpty();
}

class UserUpdating extends UserState {
  final UserModel user;

  const UserUpdating(this.user);

  @override
  List<Object?> get props => [user];
}

class UserUpdateSuccess extends UserState {
  final UserModel user;

  const UserUpdateSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class UserError extends UserState {
  final String message;
  final UserModel? user;

  const UserError(this.message, {this.user});

  @override
  List<Object?> get props => [message, user];
}
