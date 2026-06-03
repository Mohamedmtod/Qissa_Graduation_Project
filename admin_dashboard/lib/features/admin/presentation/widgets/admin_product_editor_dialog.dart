import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/staff_taste_intelligence.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_media_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_media_picker_dialog.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class AdminProductEditorInitial {
  const AdminProductEditorInitial({
    this.name = '',
    this.nameAr = '',
    this.brand = '',
    this.brandAr = '',
    this.aliases = const <String>[],
    this.aliasesAr = const <String>[],
    this.description = '',
    this.price = 0,
    this.size,
    this.salePrice,
    this.categoryName = '',
    this.stock = 0,
    this.isActive = true,
    this.isBestSeller = false,
    this.isNew = false,
    this.gender = 'unisex',
    this.season = 'all_season',
    this.time = 'any',
    this.occasion = 'casual',
    this.intensity = 'moderate',
    this.fragranceFamily = 'floral',
    this.topNotes = const <String>[],
    this.middleNotes = const <String>[],
    this.baseNotes = const <String>[],
    this.tags = const <String>[],
    this.imageUrls = const <String>[],
    this.productType = 'simple',
    this.isSellable = true,
    this.unitType = 'piece',
    this.costPrice,
    this.variants = const <ProductVariant>[],
    this.staffTagScores = const <String, int>{},
    this.staffWarnings = const <String>[],
    this.staffSalesNotes = const <String, String>{},
    this.similarFamousDna = const <String>[],
    this.staffIntelligenceStatus = 'draft',
    this.reviewNeeded = false,
    this.staffConfidence = 1,
    this.staffDataCoverage = 0,
    this.staffTaxonomyVersion = StaffTasteIntelligence.taxonomyVersion,
  });

  final String name;
  final String nameAr;
  final String brand;
  final String brandAr;
  final List<String> aliases;
  final List<String> aliasesAr;
  final String description;
  final double price;
  final String? size;
  final double? salePrice;
  final String categoryName;
  final int stock;
  final bool isActive;
  final bool isBestSeller;
  final bool isNew;
  final String gender;
  final String season;
  final String time;
  final String occasion;
  final String intensity;
  final String fragranceFamily;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final List<String> imageUrls;
  final String productType;
  final bool isSellable;
  final String unitType;
  final double? costPrice;
  final List<ProductVariant> variants;
  final Map<String, int> staffTagScores;
  final List<String> staffWarnings;
  final Map<String, String> staffSalesNotes;
  final List<String> similarFamousDna;
  final String staffIntelligenceStatus;
  final bool reviewNeeded;
  final int staffConfidence;
  final double staffDataCoverage;
  final int staffTaxonomyVersion;
}

class AdminProductEditorResult {
  const AdminProductEditorResult({
    required this.name,
    required this.nameAr,
    required this.brand,
    required this.brandAr,
    required this.aliases,
    required this.aliasesAr,
    required this.description,
    required this.price,
    required this.size,
    required this.salePrice,
    required this.categoryName,
    required this.stock,
    required this.isActive,
    required this.isBestSeller,
    required this.isNew,
    required this.gender,
    required this.season,
    required this.time,
    required this.occasion,
    required this.intensity,
    required this.fragranceFamily,
    required this.topNotes,
    required this.middleNotes,
    required this.baseNotes,
    required this.tags,
    required this.imageUrls,
    required this.productType,
    required this.isSellable,
    required this.unitType,
    required this.costPrice,
    required this.variants,
    required this.staffTagScores,
    required this.staffWarnings,
    required this.staffSalesNotes,
    required this.similarFamousDna,
    required this.staffIntelligenceStatus,
    required this.reviewNeeded,
    required this.staffConfidence,
    required this.staffDataCoverage,
    required this.staffTaxonomyVersion,
  });

  final String name;
  final String nameAr;
  final String brand;
  final String brandAr;
  final List<String> aliases;
  final List<String> aliasesAr;
  final String description;
  final double price;
  final String? size;
  final double? salePrice;
  final String categoryName;
  final int stock;
  final bool isActive;
  final bool isBestSeller;
  final bool isNew;
  final String gender;
  final String season;
  final String time;
  final String occasion;
  final String intensity;
  final String fragranceFamily;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final List<String> imageUrls;
  final String productType;
  final bool isSellable;
  final String unitType;
  final double? costPrice;
  final List<ProductVariant> variants;
  final Map<String, int> staffTagScores;
  final List<String> staffWarnings;
  final Map<String, String> staffSalesNotes;
  final List<String> similarFamousDna;
  final String staffIntelligenceStatus;
  final bool reviewNeeded;
  final int staffConfidence;
  final double staffDataCoverage;
  final int staffTaxonomyVersion;
}

typedef AdminProductSubmit =
    Future<bool> Function(AdminProductEditorResult result);

Future<void> showAdminProductEditorDialog(
  BuildContext context, {
  required String title,
  required AdminProductSubmit onSubmit,
  AdminProductEditorInitial initial = const AdminProductEditorInitial(),
}) {
  final l10n = context.read<AdminLocaleController>();
  final basicFormKey = GlobalKey<FormState>();

  final nameController = TextEditingController(text: initial.name);
  final nameArController = TextEditingController(text: initial.nameAr);
  final brandController = TextEditingController(text: initial.brand);
  final brandArController = TextEditingController(text: initial.brandAr);
  final aliasesController = TextEditingController(
    text: initial.aliases.join(', '),
  );
  final aliasesArController = TextEditingController(
    text: initial.aliasesAr.join(', '),
  );
  final descriptionController = TextEditingController(
    text: initial.description,
  );
  final priceController = TextEditingController(
    text: _formatPriceInput(initial.price),
  );
  final sizeController = TextEditingController(text: initial.size ?? '');
  final salePriceController = TextEditingController(
    text: _formatPriceInput(initial.salePrice ?? 0),
  );
  final collectionController = TextEditingController(
    text: initial.categoryName,
  );
  final stockController = TextEditingController(text: '${initial.stock}');
  final costPriceController = TextEditingController(
    text: _formatPriceInput(initial.costPrice ?? 0),
  );

  final topNotesController = TextEditingController();
  final middleNotesController = TextEditingController();
  final baseNotesController = TextEditingController();
  final tagsController = TextEditingController();
  final staffNoteArController = TextEditingController(
    text: initial.staffSalesNotes['ar'] ?? '',
  );
  final staffNoteEnController = TextEditingController(
    text: initial.staffSalesNotes['en'] ?? '',
  );

  final topNotes = initial.topNotes.toList();
  final middleNotes = initial.middleNotes.toList();
  final baseNotes = initial.baseNotes.toList();
  final tags = initial.tags.toList();
  final staffTagScores = Map<String, int>.from(initial.staffTagScores);
  final staffWarnings = initial.staffWarnings.toList();
  final similarFamousDna = initial.similarFamousDna.toList();
  final imageUrls = initial.imageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();

  var currentStep = 0;
  var isSaving = false;
  var isActive = initial.isActive;
  var isBestSeller = initial.isBestSeller;
  var isNew = initial.isNew;
  var gender = _normalizeOption(initial.gender, _genderOptions);
  var season = _normalizeOption(initial.season, _seasonOptions);
  var time = _normalizeOption(initial.time, _timeOptions);
  var productType = initial.productType;
  var isSellable = initial.isSellable;
  var unitType = initial.unitType;
  var staffIntelligenceStatus = initial.staffIntelligenceStatus;
  var reviewNeeded = initial.reviewNeeded;
  var staffConfidence = initial.staffConfidence.clamp(1, 3);
  var staffGroupToAdd = 'useCase';
  var staffTagToAdd = _staffTagsForGroup(staffGroupToAdd).first;
  var staffScoreToAdd = 2;

  var occasion = _normalizeOption(initial.occasion, _occasionOptions);
  var intensity = _normalizeOption(initial.intensity, _intensityOptions);
  var fragranceFamily = _normalizeOption(
    initial.fragranceFamily,
    _fragranceFamilyOptions,
  );

  void showMessage(String message) {
    AdminSnackBar.warning(context, message);
  }

  bool validateStep(int step) {
    if (step == 0) {
      if (basicFormKey.currentState?.validate() != true) {
        return false;
      }
      final price = _parsePrice(priceController.text);
      if (price == null) {
        showMessage(l10n.t('inventory.addProductPriceInvalid'));
        return false;
      }
      final salePriceText = salePriceController.text.trim();
      final salePrice = salePriceText.isEmpty
          ? null
          : _parsePrice(salePriceText);
      if (salePriceText.isNotEmpty &&
          (salePrice == null || salePrice <= 0 || salePrice >= price)) {
        showMessage(l10n.t('inventory.addProductSalePriceLessThanPrice'));
        return false;
      }
      return true;
    }

    if (step == 2 &&
        topNotes.isEmpty &&
        middleNotes.isEmpty &&
        baseNotes.isEmpty) {
      showMessage(l10n.t('inventory.addProductNotesRequired'));
      return false;
    }

    if (step == 4 && imageUrls.isEmpty) {
      showMessage(l10n.t('content.productImageRequired'));
      return false;
    }

    return true;
  }

  void addChip(List<String> target, TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (!target.contains(value)) {
      target.add(value);
    }
    controller.clear();
  }

  void markStaffEdited() {
    reviewNeeded = true;
    if (staffIntelligenceStatus == 'trusted') {
      staffIntelligenceStatus = 'draft';
    }
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: !isSaving,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 760,
              height: 560,
              child: Stepper(
                currentStep: currentStep,
                onStepTapped: isSaving
                    ? null
                    : (index) {
                        if (index <= currentStep || validateStep(currentStep)) {
                          setState(() => currentStep = index);
                        }
                      },
                controlsBuilder: (context, details) => const SizedBox.shrink(),
                steps: [
                  Step(
                    title: Text(l10n.t('inventory.addProductStep1Title')),
                    isActive: currentStep >= 0,
                    content: Form(
                      key: basicFormKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: nameController,
                              enabled: !isSaving,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.addProductNameLabel',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? l10n.t('inventory.addProductNameRequired')
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: nameArController,
                              enabled: !isSaving,
                              textDirection: TextDirection.rtl,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.product.arNameLabel',
                                  fallback: 'Arabic product name',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: brandController,
                              enabled: !isSaving,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.addProductBrandLabel',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? l10n.t('inventory.addProductBrandRequired')
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: brandArController,
                              enabled: !isSaving,
                              textDirection: TextDirection.rtl,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.product.arBrandLabel',
                                  fallback: 'Arabic brand name',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: aliasesController,
                              enabled: !isSaving,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.product.enAliasesHint',
                                  fallback: 'English aliases, comma separated',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: aliasesArController,
                              enabled: !isSaving,
                              textDirection: TextDirection.rtl,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.product.arAliasesHint',
                                  fallback: 'Arabic aliases, comma separated',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: descriptionController,
                              enabled: !isSaving,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.addProductDescriptionLabel',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? l10n.t(
                                      'inventory.addProductDescriptionRequired',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: priceController,
                                    enabled: !isSaving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.addProductPriceLabel',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) =>
                                        _parsePrice(value ?? '') == null
                                        ? l10n.t(
                                            'inventory.addProductPriceInvalid',
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: stockController,
                                    enabled: !isSaving,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.addProductInitialStockLabel',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final parsed = int.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (parsed == null) {
                                        return l10n.t(
                                          'inventory.invalidStockAmount',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: sizeController,
                                    enabled: !isSaving,
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.addProductSizeLabel',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: salePriceController,
                                    enabled: !isSaving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.addProductSalePriceLabel',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final rawValue = (value ?? '').trim();
                                      if (rawValue.isEmpty) {
                                        return null;
                                      }
                                      final parsedSale = _parsePrice(rawValue);
                                      if (parsedSale == null) {
                                        return l10n.t(
                                          'inventory.addProductSalePriceInvalid',
                                        );
                                      }

                                      final parsedPrice = _parsePrice(
                                        priceController.text,
                                      );
                                      if (parsedPrice != null &&
                                          parsedSale >= parsedPrice) {
                                        return l10n.t(
                                          'inventory.addProductSalePriceLessThanPrice',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: costPriceController,
                                    enabled: !isSaving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.product.costPriceLabel',
                                        fallback: 'Cost Price',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final rawValue = (value ?? '').trim();
                                      if (rawValue.isEmpty) {
                                        return null;
                                      }
                                      final parsedCost = _parsePrice(rawValue);
                                      if (parsedCost == null) {
                                        return l10n.t(
                                          'inventory.product.costPriceInvalid',
                                          fallback: 'Invalid cost price',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: productType,
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.product.productTypeLabel',
                                        fallback: 'Product Type',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'simple',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.type.simple',
                                            fallback: 'Simple',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'raw_material',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.type.raw',
                                            fallback: 'Raw Material',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'composite',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.type.composite',
                                            fallback: 'Composite (Perfume)',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: isSaving
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(() => productType = val);
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: unitType,
                                    decoration: InputDecoration(
                                      labelText: l10n.t(
                                        'inventory.product.unitTypeLabel',
                                        fallback: 'Unit Type',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'piece',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.unit.piece',
                                            fallback: 'Piece',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ml',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.unit.ml',
                                            fallback: 'ml',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'gram',
                                        child: Text(
                                          l10n.t(
                                            'inventory.product.unit.gram',
                                            fallback: 'gram',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: isSaving
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(() => unitType = val);
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SwitchListTile.adaptive(
                                    value: isSellable,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      l10n.t(
                                        'inventory.product.isSellableLabel',
                                        fallback: 'Is Sellable',
                                      ),
                                    ),
                                    onChanged: isSaving
                                        ? null
                                        : (value) => setState(
                                            () => isSellable = value,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: collectionController,
                              enabled: !isSaving,
                              decoration: InputDecoration(
                                labelText: l10n.t(
                                  'inventory.addProductCollectionLabel',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? l10n.t(
                                      'inventory.addProductCollectionRequired',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              value: isActive,
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.t('content.productActive')),
                              onChanged: isSaving
                                  ? null
                                  : (value) => setState(() => isActive = value),
                            ),
                            SwitchListTile.adaptive(
                              value: isBestSeller,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.t(
                                  'inventory.badge.bestSeller',
                                  fallback: 'Best Seller',
                                ),
                              ),
                              onChanged: isSaving
                                  ? null
                                  : (value) =>
                                        setState(() => isBestSeller = value),
                            ),
                            SwitchListTile.adaptive(
                              value: isNew,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.t('inventory.badge.new', fallback: 'New'),
                              ),
                              onChanged: isSaving
                                  ? null
                                  : (value) => setState(() => isNew = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Step(
                    title: Text(l10n.t('inventory.addProductStep2Title')),
                    isActive: currentStep >= 1,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SingleSelectChips<String>(
                          label: l10n.t('inventory.addProductGenderLabel'),
                          options: _genderOptions,
                          value: gender,
                          enabled: !isSaving,
                          onSelected: (value) => setState(() => gender = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.gender.$value'),
                        ),
                        _SingleSelectChips<String>(
                          label: l10n.t('inventory.addProductSeasonLabel'),
                          options: _seasonOptions,
                          value: season,
                          enabled: !isSaving,
                          onSelected: (value) => setState(() => season = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.season.$value'),
                        ),
                        _SingleSelectChips<String>(
                          label: l10n.t('inventory.addProductTimeLabel'),
                          options: _timeOptions,
                          value: time,
                          enabled: !isSaving,
                          onSelected: (value) => setState(() => time = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.time.$value'),
                        ),
                        _SingleSelectChips<String>(
                          label: l10n.t('inventory.addProductOccasionLabel'),
                          options: _occasionOptions,
                          value: occasion,
                          enabled: !isSaving,
                          onSelected: (value) =>
                              setState(() => occasion = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.occasion.$value'),
                        ),
                        _SingleSelectChips<String>(
                          label: l10n.t('inventory.addProductIntensityLabel'),
                          options: _intensityOptions,
                          value: intensity,
                          enabled: !isSaving,
                          onSelected: (value) =>
                              setState(() => intensity = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.intensity.$value'),
                        ),
                        _SingleSelectChips<String>(
                          label: l10n.t(
                            'inventory.addProductFragranceFamilyLabel',
                          ),
                          options: _fragranceFamilyOptions,
                          value: fragranceFamily,
                          enabled: !isSaving,
                          onSelected: (value) =>
                              setState(() => fragranceFamily = value),
                          optionLabelBuilder: (value) =>
                              l10n.t('inventory.option.fragranceFamily.$value'),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: Text(l10n.t('inventory.addProductStep3Title')),
                    isActive: currentStep >= 2,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StringChipsInput(
                          label: l10n.t('inventory.addProductTopNotesLabel'),
                          hintText: l10n.t(
                            'inventory.addProductChipHint',
                            params: {
                              'label': l10n.t(
                                'inventory.addProductTopNotesLabel',
                              ),
                            },
                          ),
                          controller: topNotesController,
                          values: topNotes,
                          enabled: !isSaving,
                          onAdd: () => setState(
                            () => addChip(topNotes, topNotesController),
                          ),
                          onRemove: (value) =>
                              setState(() => topNotes.remove(value)),
                        ),
                        const SizedBox(height: 10),
                        _StringChipsInput(
                          label: l10n.t('inventory.addProductMiddleNotesLabel'),
                          hintText: l10n.t(
                            'inventory.addProductChipHint',
                            params: {
                              'label': l10n.t(
                                'inventory.addProductMiddleNotesLabel',
                              ),
                            },
                          ),
                          controller: middleNotesController,
                          values: middleNotes,
                          enabled: !isSaving,
                          onAdd: () => setState(
                            () => addChip(middleNotes, middleNotesController),
                          ),
                          onRemove: (value) =>
                              setState(() => middleNotes.remove(value)),
                        ),
                        const SizedBox(height: 10),
                        _StringChipsInput(
                          label: l10n.t('inventory.addProductBaseNotesLabel'),
                          hintText: l10n.t(
                            'inventory.addProductChipHint',
                            params: {
                              'label': l10n.t(
                                'inventory.addProductBaseNotesLabel',
                              ),
                            },
                          ),
                          controller: baseNotesController,
                          values: baseNotes,
                          enabled: !isSaving,
                          onAdd: () => setState(
                            () => addChip(baseNotes, baseNotesController),
                          ),
                          onRemove: (value) =>
                              setState(() => baseNotes.remove(value)),
                        ),
                        const SizedBox(height: 10),
                        _StringChipsInput(
                          label: l10n.t('inventory.addProductTagsLabel'),
                          hintText: l10n.t(
                            'inventory.addProductChipHint',
                            params: {
                              'label': l10n.t('inventory.addProductTagsLabel'),
                            },
                          ),
                          controller: tagsController,
                          values: tags,
                          enabled: !isSaving,
                          onAdd: () =>
                              setState(() => addChip(tags, tagsController)),
                          onRemove: (value) =>
                              setState(() => tags.remove(value)),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Staff Taste'),
                    isActive: currentStep >= 3,
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick staff intelligence',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: staffGroupToAdd,
                                  decoration: const InputDecoration(
                                    labelText: 'Group',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _staffGroupOptions
                                      .map(
                                        (group) => DropdownMenuItem(
                                          value: group,
                                          child: Text(_staffGroupLabel(group)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            staffGroupToAdd = value;
                                            staffTagToAdd = _staffTagsForGroup(
                                              value,
                                            ).first;
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: staffTagToAdd,
                                  decoration: const InputDecoration(
                                    labelText: 'Tag',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _staffTagsForGroup(staffGroupToAdd)
                                      .map(
                                        (tag) => DropdownMenuItem(
                                          value: tag,
                                          child: Text(_staffTagLabel(tag)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(
                                              () => staffTagToAdd = value,
                                            );
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: staffScoreToAdd,
                                  decoration: const InputDecoration(
                                    labelText: 'Score',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text('ضعيف / Weak'),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('متوسط / Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('قوي / Strong'),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(
                                              () => staffScoreToAdd = value,
                                            );
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              AdminPrimaryButton(
                                label: 'Add tag',
                                onPressed: isSaving
                                    ? null
                                    : () => setState(() {
                                        staffTagScores[staffTagToAdd] =
                                            staffScoreToAdd;
                                        markStaffEdited();
                                      }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: staffTagScores.entries
                                .map(
                                  (entry) => InputChip(
                                    label: Text(
                                      '${_staffTagLabel(entry.key)}: ${_staffScoreLabel(entry.value)}',
                                    ),
                                    onDeleted: isSaving
                                        ? null
                                        : () => setState(() {
                                            staffTagScores.remove(entry.key);
                                            markStaffEdited();
                                          }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Warnings',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Wrap(
                            spacing: 8,
                            children: StaffTasteIntelligence.warningTags
                                .map(
                                  (warning) => FilterChip(
                                    label: Text(_staffTagLabel(warning)),
                                    selected: staffWarnings.contains(warning),
                                    onSelected: isSaving
                                        ? null
                                        : (selected) => setState(() {
                                            if (selected) {
                                              staffWarnings.add(warning);
                                            } else {
                                              staffWarnings.remove(warning);
                                            }
                                            markStaffEdited();
                                          }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: staffNoteArController,
                            enabled: !isSaving,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Staff note Arabic',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => markStaffEdited(),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: staffNoteEnController,
                            enabled: !isSaving,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Staff note English',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => markStaffEdited(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Coverage: ${_staffCoverageLabel(StaffTasteIntelligence.calculateCoverage(staffTagScores))}',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: staffIntelligenceStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Review status',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'draft',
                                      child: Text('Draft'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'reviewed',
                                      child: Text('Reviewed'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'trusted',
                                      child: Text('Trusted'),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) => setState(() {
                                          staffIntelligenceStatus =
                                              value ?? 'draft';
                                          reviewNeeded =
                                              staffIntelligenceStatus ==
                                              'draft';
                                        }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: staffConfidence,
                                  decoration: const InputDecoration(
                                    labelText: 'Staff confidence',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text('ضعيف / Low'),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('متوسط / Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('قوي / High'),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) => setState(() {
                                          staffConfidence = value ?? 1;
                                          markStaffEdited();
                                        }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reviewNeeded
                                ? 'Review needed before this data affects scoring.'
                                : 'Approval is accepted only for main admin roles.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          for (final warning in _staffContradictions(
                            staffTagScores,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                warning,
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Step(
                    title: Text(l10n.t('inventory.addProductStep4Title')),
                    isActive: currentStep >= 4,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: imageUrls.isEmpty
                              ? Text(
                                  l10n.t(
                                    'inventory.addProductMediaPlaceholder',
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.t(
                                        'inventory.selectedMediaCount',
                                        params: {
                                          'count': imageUrls.length.toString(),
                                        },
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: AppTheme.primary),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: imageUrls.map((url) {
                                        return Stack(
                                          children: [
                                            AdminNetworkImage(
                                              imageUrl: url,
                                              width: 96,
                                              height: 96,
                                              borderRadius: 10,
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Material(
                                                color: Colors.black.withValues(
                                                  alpha: 0.55,
                                                ),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: isSaving
                                                      ? null
                                                      : () => setState(
                                                          () => imageUrls
                                                              .remove(url),
                                                        ),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        AdminSecondaryButton(
                          label: imageUrls.isEmpty
                              ? l10n.t('inventory.chooseUploadImage')
                              : l10n.t('inventory.addMoreImages'),
                          icon: Icons.photo_library_outlined,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final selection =
                                      await showAdminMediaPickerDialog(
                                        dialogContext,
                                        initialFolder:
                                            AdminMediaFolder.products,
                                      );
                                  if (selection == null) {
                                    return;
                                  }
                                  setState(() {
                                    if (!imageUrls.contains(selection.url)) {
                                      imageUrls.add(selection.url);
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.t('common.cancel')),
              ),
              if (currentStep > 0)
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => setState(() => currentStep -= 1),
                  child: Text(l10n.t('common.back')),
                ),
              AdminPrimaryButton(
                label: isSaving
                    ? l10n.t('common.saving')
                    : currentStep < 4
                    ? l10n.t('common.next')
                    : l10n.t('inventory.addProductConfirm'),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!validateStep(currentStep)) {
                          return;
                        }

                        if (currentStep < 4) {
                          setState(() => currentStep += 1);
                          return;
                        }

                        final stock = int.parse(stockController.text.trim());
                        final price = _parsePrice(priceController.text)!;
                        final salePriceText = salePriceController.text.trim();
                        final salePrice = salePriceText.isEmpty
                            ? null
                            : _parsePrice(salePriceText);
                        final costPriceText = costPriceController.text.trim();
                        final costPrice = costPriceText.isEmpty
                            ? null
                            : _parsePrice(costPriceText);
                        final staffNotes = <String, String>{
                          if (staffNoteArController.text.trim().isNotEmpty)
                            'ar': staffNoteArController.text.trim(),
                          if (staffNoteEnController.text.trim().isNotEmpty)
                            'en': staffNoteEnController.text.trim(),
                        };
                        final staffCoverage =
                            StaffTasteIntelligence.calculateCoverage(
                              staffTagScores,
                            );

                        setState(() => isSaving = true);
                        final saved = await onSubmit(
                          AdminProductEditorResult(
                            name: nameController.text.trim(),
                            nameAr: nameArController.text.trim(),
                            brand: brandController.text.trim(),
                            brandAr: brandArController.text.trim(),
                            aliases: _splitAliases(aliasesController.text),
                            aliasesAr: _splitAliases(aliasesArController.text),
                            description: descriptionController.text.trim(),
                            price: price,
                            size: sizeController.text.trim().isEmpty
                                ? null
                                : sizeController.text.trim(),
                            salePrice: salePrice,
                            categoryName: collectionController.text.trim(),
                            stock: stock,
                            isActive: isActive,
                            isBestSeller: isBestSeller,
                            isNew: isNew,
                            gender: gender,
                            season: season,
                            time: time,
                            occasion: occasion,
                            intensity: intensity,
                            fragranceFamily: fragranceFamily,
                            topNotes: List<String>.from(topNotes),
                            middleNotes: List<String>.from(middleNotes),
                            baseNotes: List<String>.from(baseNotes),
                            tags: List<String>.from(tags),
                            imageUrls: List<String>.from(imageUrls),
                            productType: productType,
                            isSellable: isSellable,
                            unitType: unitType,
                            costPrice: costPrice,
                            variants: initial.variants,
                            staffTagScores: Map<String, int>.from(
                              staffTagScores,
                            ),
                            staffWarnings: List<String>.from(staffWarnings),
                            staffSalesNotes: staffNotes,
                            similarFamousDna: List<String>.from(
                              similarFamousDna,
                            ),
                            staffIntelligenceStatus: staffIntelligenceStatus,
                            reviewNeeded: reviewNeeded,
                            staffConfidence: staffConfidence,
                            staffDataCoverage: staffCoverage,
                            staffTaxonomyVersion:
                                StaffTasteIntelligence.taxonomyVersion,
                          ),
                        );

                        if (!dialogContext.mounted) {
                          return;
                        }
                        if (saved) {
                          final route = ModalRoute.of(dialogContext);
                          if (route != null && route.isCurrent) {
                            Navigator.of(dialogContext).pop();
                          }
                          return;
                        }
                        setState(() => isSaving = false);
                      },
              ),
            ],
          );
        },
      );
    },
  );
}

String _normalizeOption(String value, List<String> options) {
  final normalized = value.trim();
  return options.contains(normalized) ? normalized : options.first;
}

const List<String> _staffGroupOptions = [
  'useCase',
  'vibe',
  'comfort',
  'performance',
  'risk',
  'famousDna',
];

List<String> _staffTagsForGroup(String group) {
  return switch (group) {
    'useCase' => StaffTasteIntelligence.useCaseTags.toList(),
    'vibe' => StaffTasteIntelligence.vibeTags.toList(),
    'comfort' => StaffTasteIntelligence.comfortTags.toList(),
    'performance' => const [
      'long_lasting',
      'moderate_projection',
      'loud_projection',
      'soft_projection',
    ],
    'risk' => const [
      'safe_blind_buy',
      'medium_risk',
      'polarizing',
      'crowd_pleaser',
    ],
    'famousDna' => const [
      'sauvage_like',
      'acqua_di_gio_like',
      'aventus_like',
      'good_girl_like',
      'baccarat_like',
    ],
    _ => StaffTasteIntelligence.useCaseTags.toList(),
  };
}

String _staffGroupLabel(String group) {
  return switch (group) {
    'useCase' => 'Use case',
    'vibe' => 'Vibe',
    'comfort' => 'Comfort',
    'performance' => 'Performance',
    'risk' => 'Risk',
    'famousDna' => 'Famous DNA',
    _ => group,
  };
}

String _staffTagLabel(String tag) {
  return tag
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String _staffScoreLabel(int score) {
  return switch (score) {
    1 => 'ضعيف',
    2 => 'متوسط',
    3 => 'قوي',
    _ => '$score',
  };
}

String _staffCoverageLabel(double coverage) {
  final label = StaffTasteIntelligence.coverageLabel(coverage);
  return '$label (${(coverage * 100).round()}%)';
}

List<String> _staffContradictions(Map<String, int> scores) {
  final warnings = <String>[];
  if ((scores['loud_projection'] ?? 0) >= 2 &&
      (scores['soft_on_nose'] ?? 0) >= 2) {
    warnings.add('Warning: loud projection and soft on nose may conflict.');
  }
  if ((scores['safe_blind_buy'] ?? 0) >= 2 &&
      (scores['polarizing'] ?? 0) >= 2) {
    warnings.add('Warning: safe blind buy and polarizing may conflict.');
  }
  if ((scores['wedding'] ?? 0) >= 2 &&
      (scores['elegant'] ?? 0) == 0 &&
      (scores['luxury'] ?? 0) == 0) {
    warnings.add('Warning: wedding usually needs elegant or luxury support.');
  }
  return warnings;
}

String _formatPriceInput(double price) {
  if (price <= 0) {
    return '';
  }
  return price.toStringAsFixed(2);
}

double? _parsePrice(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

List<String> _splitAliases(String value) {
  return value
      .split(RegExp(r'[,،\n]'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

const List<String> _genderOptions = ['male', 'female', 'unisex'];
const List<String> _seasonOptions = [
  'summer',
  'winter',
  'spring',
  'autumn',
  'all_season',
];
const List<String> _timeOptions = ['day', 'night', 'any'];
const List<String> _occasionOptions = [
  'casual',
  'formal',
  'work',
  'party',
  'special',
];
const List<String> _intensityOptions = ['light', 'moderate', 'strong'];
const List<String> _fragranceFamilyOptions = [
  'floral',
  'woody',
  'oriental',
  'fresh',
  'citrus',
  'gourmand',
  'aromatic',
  'spicy',
];

class _SingleSelectChips<T> extends StatelessWidget {
  const _SingleSelectChips({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.enabled = true,
    this.optionLabelBuilder,
  });

  final String label;
  final List<T> options;
  final T value;
  final bool enabled;
  final ValueChanged<T> onSelected;
  final String Function(T option)? optionLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(
                      optionLabelBuilder?.call(option) ?? option.toString(),
                    ),
                    selected: option == value,
                    onSelected: enabled ? (_) => onSelected(option) : null,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StringChipsInput extends StatelessWidget {
  const _StringChipsInput({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.values,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final List<String> values;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                enabled: enabled,
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: enabled ? (_) => onAdd() : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add_circle),
            ),
          ],
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (entry) => InputChip(
                    label: Text(entry),
                    onDeleted: enabled ? () => onRemove(entry) : null,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
