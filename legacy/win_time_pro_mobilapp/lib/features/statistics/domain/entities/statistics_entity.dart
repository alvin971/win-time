import 'package:equatable/equatable.dart';

class StatisticsEntity extends Equatable {
  final String restaurantId;
  final DateTime periodStart;
  final DateTime periodEnd;

  final DailySummary todaySummary;
  final PeriodSummary weekSummary;
  final PeriodSummary monthSummary;

  final List<TopProduct> topProducts;
  final List<CategorySales> categorySales;
  final List<HourlyData> hourlyData;

  final PerformanceMetrics performance;

  final DateTime generatedAt;

  const StatisticsEntity({
    required this.restaurantId,
    required this.periodStart,
    required this.periodEnd,
    required this.todaySummary,
    required this.weekSummary,
    required this.monthSummary,
    required this.topProducts,
    required this.categorySales,
    required this.hourlyData,
    required this.performance,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [
        restaurantId,
        periodStart,
        periodEnd,
        todaySummary,
        weekSummary,
        monthSummary,
        topProducts,
        categorySales,
        hourlyData,
        performance,
        generatedAt,
      ];
}

class DailySummary extends Equatable {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final double averageOrderValue;
  final int activeOrders;

  const DailySummary({
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.activeOrders,
  });

  @override
  List<Object?> get props => [
        totalOrders,
        completedOrders,
        cancelledOrders,
        totalRevenue,
        averageOrderValue,
        activeOrders,
      ];
}

class PeriodSummary extends Equatable {
  final int totalOrders;
  final double totalRevenue;
  final double averageOrderValue;
  final double growthRate;
  final int comparisonPeriodOrders;
  final double comparisonPeriodRevenue;

  const PeriodSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.growthRate,
    required this.comparisonPeriodOrders,
    required this.comparisonPeriodRevenue,
  });

  @override
  List<Object?> get props => [
        totalOrders,
        totalRevenue,
        averageOrderValue,
        growthRate,
        comparisonPeriodOrders,
        comparisonPeriodRevenue,
      ];
}

class TopProduct extends Equatable {
  final String productId;
  final String productName;
  final String? imageUrl;
  final int quantitySold;
  final double revenue;
  final double percentage;

  const TopProduct({
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
        productId,
        productName,
        imageUrl,
        quantitySold,
        revenue,
        percentage,
      ];
}

class CategorySales extends Equatable {
  final String categoryId;
  final String categoryName;
  final double revenue;
  final int orderCount;
  final double percentage;

  const CategorySales({
    required this.categoryId,
    required this.categoryName,
    required this.revenue,
    required this.orderCount,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        revenue,
        orderCount,
        percentage,
      ];
}

class HourlyData extends Equatable {
  final int hour;
  final int orderCount;
  final double revenue;

  const HourlyData({
    required this.hour,
    required this.orderCount,
    required this.revenue,
  });

  @override
  List<Object?> get props => [hour, orderCount, revenue];
}

class PerformanceMetrics extends Equatable {
  final double averagePreparationTime;
  final double averageAcceptanceTime;
  final double acceptanceRate;
  final double cancellationRate;
  final double customerRating;
  final int totalReviews;

  const PerformanceMetrics({
    required this.averagePreparationTime,
    required this.averageAcceptanceTime,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.customerRating,
    required this.totalReviews,
  });

  @override
  List<Object?> get props => [
        averagePreparationTime,
        averageAcceptanceTime,
        acceptanceRate,
        cancellationRate,
        customerRating,
        totalReviews,
      ];
}
