import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class FilterSection extends StatefulWidget {
  final Function(String? gender, String? season, String? family) onApply;
  final String? initialGender;
  final String? initialSeason;
  final String? initialFamily;

  const FilterSection({
    super.key,
    required this.onApply,
    this.initialGender,
    this.initialSeason,
    this.initialFamily,
  });

  @override
  State<FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<FilterSection> {
  String? _selectedGender;
  String? _selectedSeason;
  String? _selectedFamily;

  final List<String> genders = ['Men', 'Women', 'Unisex'];
  final List<String> seasons = [
    'Summer',
    'Winter',
    'Spring',
    'Autumn',
    'All Season',
  ];
  final List<String> families = [
    'Floral',
    'Woody',
    'Oriental',
    'Fresh',
    'Citrus',
    'Fruity',
    'Gourmand',
    'Leather',
    'Oud',
  ];

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
    _selectedSeason = widget.initialSeason;
    _selectedFamily = widget.initialFamily;
  }

  bool get _hasActiveFilters =>
      _selectedGender != null ||
      _selectedSeason != null ||
      _selectedFamily != null;

  int get _activeFilterCount => [
    _selectedGender,
    _selectedSeason,
    _selectedFamily,
  ].where((v) => v != null).length;

  String _getOptionLabel(BuildContext context, String option) {
    final l10n = AppLocalizations.of(context);
    switch (option) {
      case 'Men':
        return l10n.labelGenderMen;
      case 'Women':
        return l10n.labelGenderWomen;
      case 'Unisex':
        return l10n.labelGenderUnisex;
      case 'Summer':
        return l10n.labelOptionSummer;
      case 'Winter':
        return l10n.labelOptionWinter;
      case 'Spring':
        return l10n.labelOptionSpring;
      case 'Autumn':
        return l10n.labelOptionAutumn;
      case 'All Season':
        return l10n.labelOptionAllSeason;
      case 'Floral':
        return l10n.labelOptionFloral;
      case 'Woody':
        return l10n.labelOptionWoody;
      case 'Oriental':
        return l10n.labelOptionOriental;
      case 'Fresh':
        return l10n.labelOptionFresh;
      case 'Citrus':
        return l10n.labelOptionCitrus;
      case 'Fruity':
        return l10n.labelOptionFruity;
      case 'Gourmand':
        return l10n.labelOptionGourmand;
      case 'Leather':
        return l10n.labelOptionLeather;
      case 'Oud':
        return l10n.labelOptionOud;
      default:
        return option;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          _buildHeader(l10n),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSectionLabel(l10n.labelGender),
                  const SizedBox(height: 10),
                  _buildChipGroup(
                    genders,
                    _selectedGender,
                    (val) => setState(() => _selectedGender = val),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel(l10n.labelSeason),
                  const SizedBox(height: 10),
                  _buildChipGroup(
                    seasons,
                    _selectedSeason,
                    (val) => setState(() => _selectedSeason = val),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel(l10n.labelFragranceFamily),
                  const SizedBox(height: 10),
                  _buildChipGroup(
                    families,
                    _selectedFamily,
                    (val) => setState(() => _selectedFamily = val),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          _buildActionButtons(l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.labelFilterBy,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$_activeFilterCount active',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedGender = null;
                      _selectedSeason = null;
                      _selectedFamily = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: AppTheme.primary,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.btnReset,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          height: 1,
          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildChipGroup(
    List<String> options,
    String? selectedValue,
    Function(String?) onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((option) {
            final isSelected = selectedValue == option;
            return GestureDetector(
              onTap: () => onSelect(isSelected ? null : option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppTheme.primary
                          : AppTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        isSelected
                            ? AppTheme.primary
                            : AppTheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  _getOptionLabel(context, option),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.onPrimary : AppTheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Clear & Close
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                widget.onApply(null, null, null);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.onSurface,
                side: BorderSide(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                l10n.labelClearFilters,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Apply
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(
                  _selectedGender,
                  _selectedSeason,
                  _selectedFamily,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.btnApplyFilters,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.onPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
