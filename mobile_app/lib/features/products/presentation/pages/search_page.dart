import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/features/products/presentation/manager/search_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/search_state.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/widgets/search_field.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If initial query is passed (e.g. from Category), go directly to results?
    // Or just fill it here?
    // Logic: If initialQuery is passed, it implies we want results.
    // But since we split pages, if we got initialQuery, we probably should have gone to SearchResultsPage directly?
    // Let's assume this page is for *typing* new queries.
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _onSearchChangedInternal(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _onSearchChangedInternal(query);
    });
  }

  void _onSearchChangedInternal(String query) {
    // Don't search if less than 2 characters
    if (query.trim().length < 2) {
      context.read<SearchCubit>().reset();
      return;
    }
    context.read<SearchCubit>().search(query);
  }

  void _navigateToResults(String query) {
    final error = validateSearch(query);
    if (error != null) {
      AppSnackBar.showInfo(context, error);
      return;
    }
    context.push(
      Uri(
        path: '/search-results',
        queryParameters: {'query': query.trim()},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: SearchField(
          controller: _controller,
          hintText: l10n.hintSearchPerfumes,
          onChanged: _onSearchChanged,
          onSubmitted: _navigateToResults,
          fontSize: 16,
          height: 40,
          padding: const EdgeInsetsGeometry.only(right: 10),

          // Focus automatically when page opens
          autofocus: true,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: GoBackIcon(navigateTo: () => Navigator.pop(context)),
        leadingWidth: 30,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SearchSuggestionsSkeleton(),
                    );
                  } else if (state is SearchSuccess) {
                    if (state.products.isEmpty) {
                      // Don't show "No products found" heavily here, maybe just nothing or logic
                      // But for suggestions, we show matched products as list.
                      return const SizedBox();
                    }
                    return ListView.separated(
                      itemCount: state.products.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 0, color: Theme.of(context).colorScheme.primary, thickness: 1),
                      itemBuilder: (context, index) {
                        final product = state.products[index];
                        return ListTile(
                          minTileHeight: 10,
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          contentPadding: EdgeInsets.zero,
                          trailing: const Icon(
                            Icons.north_west,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            _navigateToResults(product.name);
                          },
                        );
                      },
                    );
                  } else if (state is SearchError) {
                    // Quiet error for suggestions
                    return const SizedBox();
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
