// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

class $AssetsAnimationsGen {
  const $AssetsAnimationsGen();

  /// File path: assets/animations/locationAnimation.json
  String get locationAnimation => 'assets/animations/locationAnimation.json';

  /// List of all assets
  List<String> get values => [locationAnimation];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/222222222.png
  AssetGenImage get a222222222 =>
      const AssetGenImage('assets/icons/222222222.png');

  /// File path: assets/icons/Luxurious perfume bottles arrangement.png
  AssetGenImage get luxuriousPerfumeBottlesArrangement => const AssetGenImage(
    'assets/icons/Luxurious perfume bottles arrangement.png',
  );

  /// File path: assets/icons/bokhoor.png
  AssetGenImage get bokhoor => const AssetGenImage('assets/icons/bokhoor.png');

  /// File path: assets/icons/bokhoor22.png
  AssetGenImage get bokhoor22 =>
      const AssetGenImage('assets/icons/bokhoor22.png');

  /// File path: assets/icons/fawa7aIcon.png
  AssetGenImage get fawa7aIcon =>
      const AssetGenImage('assets/icons/fawa7aIcon.png');

  /// File path: assets/icons/flashSale.png
  AssetGenImage get flashSale =>
      const AssetGenImage('assets/icons/flashSale.png');

  /// File path: assets/icons/gift.png
  AssetGenImage get gift => const AssetGenImage('assets/icons/gift.png');

  /// File path: assets/icons/mabkhara.png
  AssetGenImage get mabkhara =>
      const AssetGenImage('assets/icons/mabkhara.png');

  /// File path: assets/icons/perfume.png
  AssetGenImage get perfume => const AssetGenImage('assets/icons/perfume.png');

  /// File path: assets/icons/searchIcon.svg
  SvgGenImage get searchIcon =>
      const SvgGenImage('assets/icons/searchIcon.svg');

  /// File path: assets/icons/sunglassIcon.png
  AssetGenImage get sunglassIcon =>
      const AssetGenImage('assets/icons/sunglassIcon.png');

  /// File path: assets/icons/watch.png
  AssetGenImage get watch => const AssetGenImage('assets/icons/watch.png');

  /// List of all assets
  List<dynamic> get values => [
    a222222222,
    luxuriousPerfumeBottlesArrangement,
    bokhoor,
    bokhoor22,
    fawa7aIcon,
    flashSale,
    gift,
    mabkhara,
    perfume,
    searchIcon,
    sunglassIcon,
    watch,
  ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/welcomePage.png
  AssetGenImage get welcomePage =>
      const AssetGenImage('assets/images/welcomePage.png');

  /// List of all assets
  List<AssetGenImage> get values => [welcomePage];
}

class Assets {
  const Assets._();

  static const $AssetsAnimationsGen animations = $AssetsAnimationsGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}

class SvgGenImage {
  const SvgGenImage(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  const SvgGenImage.vec(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter:
          colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
