import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class ProductCard extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath; // Asset path or Network URL
  final double rating;
  final int count;
  final VoidCallback onViewMore;

  const ProductCard({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.rating,
    required this.count,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1), // The green border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book Image with Shadow
          Container(
            width: 80,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(imagePath), // Make sure this asset exists
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary, // Green title
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                // Rating Row
                Row(
                  children: [
                    ...List.generate(5, (index) => Icon(
                      Icons.star,
                      size: 14,
                      color: index < 4 ? Colors.amber : Colors.grey[300],
                    )),
                    const SizedBox(width: 8),
                    Text(
                      "$count books",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // View More Button
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: onViewMore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text(
                          "View More",
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Favorite Icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}