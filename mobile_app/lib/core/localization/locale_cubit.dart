import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/localization/locale_repository.dart';

class LocaleCubit extends Cubit<Locale> {
  final LocaleRepository _repository;

  LocaleCubit(this._repository, {Locale? initialLocale}) 
      : super(initialLocale ?? const Locale('en')) {
    if (initialLocale == null) {
      _initLocale();
    }
  }

  Future<void> _initLocale() async {
    final savedLocale = await _repository.getSavedLocale();
    if (savedLocale != null) {
      emit(savedLocale);
    } else {
      // Default to device locale if supported, else English
      final deviceLocale = PlatformDispatcher.instance.locale;
      if (deviceLocale.languageCode == 'ar') {
        emit(const Locale('ar'));
      } else {
        emit(const Locale('en'));
      }
    }
  }

  Future<void> changeLocale(Locale locale) async {
    if (state == locale) return;
    await _repository.saveLocale(locale);
    emit(locale);
  }
}
