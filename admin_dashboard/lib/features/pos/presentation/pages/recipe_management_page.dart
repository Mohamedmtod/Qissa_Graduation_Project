import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/pos/domain/entities/composite_recipe.dart';
import 'package:perfume_app_admin_dashboard/features/pos/data/services/admin_recipe_service.dart';

class RecipeManagementPage extends StatefulWidget {
  const RecipeManagementPage({super.key});

  @override
  State<RecipeManagementPage> createState() => _RecipeManagementPageState();
}

class _RecipeManagementPageState extends State<RecipeManagementPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<InventoryItem> _products = [];
  List<InventoryItem> _compositeProducts = [];
  List<InventoryItem> _componentProducts = [];
  List<CompositeRecipe> _recipes = [];

  InventoryItem? _selectedProduct;
  CompositeRecipe? _editingRecipe;
  List<RecipeComponent> _editingComponents = [];

  final _recipeService = AdminRecipeService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  InventoryItem _mapDocToInventoryItem(String id, Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unknown Product';
    final categoryName = (data['categoryName'] as String?) ?? 'Uncategorized';
    final rawImageUrls = data['imageUrls'] as List<dynamic>? ?? [];
    final imageUrl = rawImageUrls.isNotEmpty ? (rawImageUrls.first as String?) ?? '' : '';
    final rawStock = data['stock'];
    final int units = rawStock is int ? rawStock : (rawStock is double ? rawStock.toInt() : 0);
    final lowStock = InventoryItem.determineLowStock(units);
    final rawVariants = data['variants'] as List<dynamic>?;
    final List<ProductVariant> variantsList;
    if (rawVariants != null && rawVariants.isNotEmpty) {
      variantsList = rawVariants
          .map((v) => ProductVariant.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    } else {
      variantsList = [
        ProductVariant(
          id: 'default',
          label: (data['size'] as String?) ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          salePrice: (data['salePrice'] as num?)?.toDouble(),
          costPrice: (data['costPrice'] as num?)?.toDouble(),
          unitType: (data['unitType'] as String?) ?? 'piece',
          stock: units.toDouble(),
          isActive: (data['isActive'] as bool?) ?? true,
        )
      ];
    }
    final productType = (data['productType'] as String?) ?? 'simple';
    final isSellable = (data['isSellable'] as bool?) ?? true;
    final unitType = (data['unitType'] as String?) ?? 'piece';

    return InventoryItem(
      id: id,
      name: name,
      collection: categoryName,
      imageUrl: imageUrl,
      units: units,
      waitingUsers: 0,
      trend: InventoryTrend.up,
      lowStock: lowStock,
      productType: productType,
      isSellable: isSellable,
      unitType: unitType,
      variants: variantsList,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
      final products = productsSnapshot.docs.map((doc) {
        return _mapDocToInventoryItem(doc.id, doc.data());
      }).toList();

      final recipes = await _recipeService.fetchRecipes();

      setState(() {
        _products = products;
        _compositeProducts = products.where((p) => p.productType == 'composite').toList();
        _componentProducts = products.where((p) => p.productType != 'composite').toList();
        _recipes = recipes;
        _isLoading = false;

        if (_compositeProducts.isNotEmpty) {
          _selectProduct(_compositeProducts.first);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  void _selectProduct(InventoryItem product) {
    setState(() {
      _selectedProduct = product;
      final existingRecipe = _recipes.firstWhere(
        (r) => r.productId == product.id && r.isActive,
        orElse: () => CompositeRecipe(
          id: '',
          productId: product.id,
          name: product.name,
          nameAr: product.name,
          recipeVersion: 0,
          isActive: true,
          components: [],
        ),
      );
      _editingRecipe = existingRecipe;
      _editingComponents = List.from(existingRecipe.components);
    });
  }

  InventoryItem _emptyItem() {
    return const InventoryItem(
      id: '',
      name: 'Unknown Component',
      collection: '',
      imageUrl: '',
      units: 0,
      waitingUsers: 0,
      trend: InventoryTrend.up,
      productType: 'simple',
      isSellable: false,
      unitType: 'piece',
      variants: [],
    );
  }

  double _calculateTotalCost() {
    double total = 0.0;
    for (final comp in _editingComponents) {
      final prod = _componentProducts.firstWhere((p) => p.id == comp.productId, orElse: () => _emptyItem());
      final cost = prod.variants.isNotEmpty ? (prod.variants.first.costPrice ?? 0.0) : 0.0;
      total += comp.quantity * cost;
    }
    return total;
  }

  List<String> _generateWarnings() {
    final warnings = <String>[];
    for (final comp in _editingComponents) {
      final prod = _componentProducts.firstWhere(
        (p) => p.id == comp.productId,
        orElse: () => _emptyItem(),
      );
      if (prod.id.isEmpty) {
        warnings.add('Component "${comp.name}" not found in inventory.');
      } else {
        final costPrice = prod.variants.isNotEmpty ? prod.variants.first.costPrice : null;
        if (costPrice == null || costPrice <= 0.0) {
          warnings.add('Missing cost price for "${prod.name}".');
        }
        if (prod.units < comp.quantity) {
          warnings.add('Low stock warning: "${prod.name}" has only ${prod.units} units (requires ${comp.quantity}).');
        }
      }
    }
    return warnings;
  }

  Future<void> _saveRecipe() async {
    if (_selectedProduct == null || _editingRecipe == null) return;

    if (_editingComponents.isEmpty) {
      AdminSnackBar.warning(context, 'Recipe must have at least one ingredient');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newVersion = _editingRecipe!.recipeVersion + 1;
      final updatedRecipe = CompositeRecipe(
        id: _editingRecipe!.id.isEmpty
            ? FirebaseFirestore.instance.collection('recipes').doc().id
            : _editingRecipe!.id,
        productId: _selectedProduct!.id,
        name: _selectedProduct!.name,
        nameAr: _selectedProduct!.name,
        recipeVersion: newVersion,
        isActive: true,
        components: _editingComponents,
      );

      await _recipeService.saveRecipe(updatedRecipe);

      final recipes = await _recipeService.fetchRecipes();
      setState(() {
        _recipes = recipes;
        final matching = recipes.firstWhere((r) => r.id == updatedRecipe.id);
        _editingRecipe = matching;
        _editingComponents = List.from(matching.components);
        _isLoading = false;
      });

      if (mounted) {
        AdminSnackBar.success(context, 'Recipe saved successfully as Version $newVersion');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AdminSnackBar.error(context, 'Failed to save recipe: $e');
      }
    }
  }

  void _addComponent() {
    if (_componentProducts.isEmpty) {
      AdminSnackBar.warning(context, 'No component products available in inventory.');
      return;
    }
    final firstProd = _componentProducts.first;
    setState(() {
      _editingComponents.add(
        RecipeComponent(
          id: UniqueKey().toString(),
          productId: firstProd.id,
          name: firstProd.name,
          nameAr: firstProd.name,
          quantity: 1.0,
          type: 'fixed',
          priceDelta: 0.0,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();

    if (_isLoading && _products.isEmpty) {
      return Scaffold(
        body: AdminLoadingState(
          title: l10n.t('pos.recipes.loading', fallback: 'Loading Recipes'),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: AdminErrorState(
          title: 'Error loading page',
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final sellingPrice = _selectedProduct != null && _selectedProduct!.variants.isNotEmpty
        ? _selectedProduct!.variants.first.price
        : 0.0;
    final totalCost = _calculateTotalCost();
    final profit = sellingPrice - totalCost;
    final marginPercent = sellingPrice > 0 ? (profit / sellingPrice) * 100 : 0.0;
    final warnings = _generateWarnings();

    return Scaffold(
      body: Column(
        children: [
          SharedTopbar(
            title: l10n.t('pos.recipes.topbarTitle', fallback: 'Recipe Management'),
            searchHint: 'Search recipes...',
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: AppTheme.surfaceContainerHighest,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: _compositeProducts.length,
                      itemBuilder: (context, index) {
                        final prod = _compositeProducts[index];
                        final isSelected = _selectedProduct?.id == prod.id;
                        final currentRec = _recipes.firstWhere(
                          (r) => r.productId == prod.id && r.isActive,
                          orElse: () => _emptyRecipe(),
                        );
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          title: Text(
                            prod.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            currentRec.recipeVersion > 0
                                ? 'Version ${currentRec.recipeVersion}'
                                : 'No recipe',
                          ),
                          trailing: currentRec.recipeVersion > 0
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                              : const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                          onTap: () => _selectProduct(prod),
                        );
                      },
                    ),
                  ),
                ),
                if (_selectedProduct != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AdminSurfaceCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedProduct!.name,
                                                  style: Theme.of(context).textTheme.titleLarge,
                                                ),
                                                Text(
                                                  'Current Recipe: ${_editingRecipe!.recipeVersion > 0 ? "Version ${_editingRecipe!.recipeVersion}" : "None"}',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                            AdminSecondaryButton(
                                              label: 'Add Ingredient',
                                              icon: Icons.add,
                                              onPressed: _addComponent,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        if (_editingComponents.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 40),
                                            child: Center(
                                              child: Text(
                                                'No ingredients added yet. Click "Add Ingredient" to begin.',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: AppTheme.onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          )
                                        else
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _editingComponents.length,
                                            separatorBuilder: (context, index) => const Divider(),
                                            itemBuilder: (context, index) {
                                              final comp = _editingComponents[index];
                                              return _buildIngredientRow(comp, index);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      AdminPrimaryButton(
                                        label: _editingRecipe!.recipeVersion > 0
                                            ? 'Save & Increment Version'
                                            : 'Create & Activate Recipe',
                                        icon: Icons.save,
                                        onPressed: _isLoading ? null : _saveRecipe,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  AdminSurfaceCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Recipe Preview',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildPreviewRow('Target Selling Price', '\$${sellingPrice.toStringAsFixed(2)}'),
                                        const SizedBox(height: 8),
                                        _buildPreviewRow('Estimated Total Cost', '\$${totalCost.toStringAsFixed(2)}', isCost: true),
                                        const Divider(height: 24),
                                        _buildPreviewRow(
                                          'Estimated Net Profit',
                                          '\$${profit.toStringAsFixed(2)}',
                                          valueColor: profit >= 0 ? Colors.green : Colors.red,
                                          isBold: true,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildPreviewRow(
                                          'Estimated Margin',
                                          '${marginPercent.toStringAsFixed(1)}%',
                                          valueColor: profit >= 0 ? Colors.green : Colors.red,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (warnings.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    AdminSurfaceCard(
                                      color: Colors.orange.shade50,
                                      border: Border.all(color: Colors.orange.shade200),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Warnings (${warnings.length})',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: warnings.map((w) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.arrow_right, size: 16, color: Colors.orange.shade800),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        w,
                                                        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text('No composite products found in inventory.'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CompositeRecipe _emptyRecipe() {
    return CompositeRecipe(id: '', productId: '', name: '', nameAr: '', recipeVersion: 0, isActive: false, components: []);
  }

  Widget _buildPreviewRow(String label, String value, {bool isCost = false, Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isCost ? Colors.amber.shade900 : AppTheme.onSurface),
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(RecipeComponent comp, int index) {
    return Padding(
      key: ValueKey(comp.id),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: comp.productId,
              decoration: const InputDecoration(
                labelText: 'Ingredient',
                border: OutlineInputBorder(),
              ),
              items: _componentProducts.map((p) {
                return DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final prod = _componentProducts.firstWhere((p) => p.id == val);
                setState(() {
                  _editingComponents[index] = RecipeComponent(
                    id: comp.id,
                    productId: prod.id,
                    name: prod.name,
                    nameAr: prod.name,
                    quantity: comp.quantity,
                    type: comp.type,
                    priceDelta: comp.priceDelta,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: comp.type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                DropdownMenuItem(value: 'oil', child: Text('Perfume Oil')),
                DropdownMenuItem(value: 'selectable', child: Text('Selectable')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _editingComponents[index] = RecipeComponent(
                    id: comp.id,
                    productId: comp.productId,
                    name: comp.name,
                    nameAr: comp.nameAr,
                    quantity: comp.quantity,
                    type: val,
                    priceDelta: comp.priceDelta,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: comp.quantity.toString(),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                final double q = double.tryParse(val) ?? 0.0;
                setState(() {
                  _editingComponents[index] = RecipeComponent(
                    id: comp.id,
                    productId: comp.productId,
                    name: comp.name,
                    nameAr: comp.nameAr,
                    quantity: q,
                    type: comp.type,
                    priceDelta: comp.priceDelta,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          if (comp.type == 'selectable') ...[
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: comp.priceDelta.toString(),
                decoration: const InputDecoration(
                  labelText: 'Price Delta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  final double d = double.tryParse(val) ?? 0.0;
                  setState(() {
                    _editingComponents[index] = RecipeComponent(
                      id: comp.id,
                      productId: comp.productId,
                      name: comp.name,
                      nameAr: comp.nameAr,
                      quantity: comp.quantity,
                      type: comp.type,
                      priceDelta: d,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _editingComponents.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }
}
