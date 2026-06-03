import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProductDetailsShimmer extends StatelessWidget {
  const ProductDetailsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Placeholder
              Container(
                width: double.infinity,
                height: 350,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              const SizedBox(height: 20),
              
              // Details Sheet Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand
                    Container(
                      width: 100,
                      height: 14,
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    const SizedBox(height: 10),
                    
                    // Name
                    Container(
                      width: 250,
                      height: 24,
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price & Stock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80,
                          height: 22,
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        ),
                        Container(
                          width: 100,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    
                    // Description Title
                    Container(
                      width: 120,
                      height: 18,
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    const SizedBox(height: 12),
                    
                    // Description Body
                    Container(width: double.infinity, height: 14, color: Theme.of(context).colorScheme.surfaceContainerLowest,),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 14, color: Theme.of(context).colorScheme.surfaceContainerLowest,),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 14, color: Theme.of(context).colorScheme.surfaceContainerLowest,),
                    
                    const SizedBox(height: 30),
                    
                    // Button
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
