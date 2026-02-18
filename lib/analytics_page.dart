import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _totalProducts = 0;
  double _totalValue = 0;
  double _averagePrice = 0;
  double _averageRating = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  Map<String, int> _categoryData = {};
  List<Map<String, dynamic>> _topProducts = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      
      if (snapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      double totalValue = 0;
      double totalRating = 0;
      int ratingCount = 0;
      int lowStock = 0;
      int outOfStock = 0;
      Map<String, int> categories = {};
      List<Map<String, dynamic>> allProducts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Price calculations
        final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
        totalValue += price;

        // Rating calculations
        final rating = (data['rating'] ?? 0).toDouble();
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }

        // Stock calculations
        final stock = data['stock'] ?? 0;
        if (stock == 0) {
          outOfStock++;
        } else if (stock < 10) {
          lowStock++;
        }

        // Category counting
        final category = data['category'] ?? 'Other';
        categories[category] = (categories[category] ?? 0) + 1;

        // Store for top products
        allProducts.add({
          'title': data['title'] ?? 'Unknown',
          'price': price,
          'rating': rating,
          'stock': stock,
        });
      }

      // Sort products by price for top products
      allProducts.sort((a, b) => b['price'].compareTo(a['price']));
      
      setState(() {
        _totalProducts = snapshot.docs.length;
        _totalValue = totalValue;
        _averagePrice = _totalProducts > 0 ? totalValue / _totalProducts : 0;
        _averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;
        _lowStockCount = lowStock;
        _outOfStockCount = outOfStock;
        _categoryData = categories;
        _topProducts = allProducts.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Products',
                            _totalProducts.toString(),
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Value',
                            '\$${_totalValue.toStringAsFixed(0)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stats Cards Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Avg Price',
                            '\$${_averagePrice.toStringAsFixed(0)}',
                            Icons.calculate,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Rating',
                            _averageRating.toStringAsFixed(1),
                            Icons.star,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stats Cards Row 3
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Low Stock',
                            _lowStockCount.toString(),
                            Icons.warning,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Out of Stock',
                            _outOfStockCount.toString(),
                            Icons.error,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Pie Chart - Products by Category
                    if (_categoryData.isNotEmpty) ...[
                      _buildSectionHeader('Products by Category'),
                      const SizedBox(height: 16),
                      Container(
                        height: 250,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildPieChart(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Bar Chart - Top Products
                    if (_topProducts.isNotEmpty) ...[
                      _buildSectionHeader('Top 5 Products by Price'),
                      const SizedBox(height: 16),
                      Container(
                        height: 300,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildBarChart(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Category Legend
                    if (_categoryData.isNotEmpty) ...[
                      _buildSectionHeader('Category Breakdown'),
                      const SizedBox(height: 8),
                      ..._categoryData.entries.map((entry) {
                        final percentage = (_totalProducts > 0)
                            ? (entry.value / _totalProducts * 100).toDouble()
                            : 0.0;
                        return _buildCategoryLegend(
                          entry.key,
                          entry.value,
                          percentage,
                          _getCategoryColor(entry.key),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPieChart() {
    final sections = _categoryData.entries.map((entry) {
      final percentage = (_totalProducts > 0)
          ? (entry.value / _totalProducts * 100)
          : 0;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        color: _getCategoryColor(entry.key),
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: -90,
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _topProducts.isNotEmpty
            ? _topProducts.first['price'] * 1.2
            : 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${_topProducts[group.x.toInt()]['title']}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '\$${rod.toY.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= _topProducts.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _topProducts[value.toInt()]['title']
                        .toString()
                        .split(' ')
                        .first,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _topProducts.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value['price'],
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryLegend(String category, int count, double percentage, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Electronics': Colors.blue,
      'Fashion': Colors.pink,
      'Home & Kitchen': Colors.orange,
      'Sports & Outdoors': Colors.green,
      'Books & Stationery': Colors.purple,
      'Toys & Games': Colors.red,
      'Automotive': Colors.grey,
      'Health & Beauty': Colors.teal,
      'Grocery & Food': Colors.lime,
      'Other': Colors.brown,
    };
    return colors[category] ?? Colors.grey;
  }
}