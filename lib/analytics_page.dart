import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  int _totalProducts = 0;
  double _totalValue = 0;
  double _averagePrice = 0;
  double _averageRating = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  Map<String, int> _categoryData = {};
  List<Map<String, dynamic>> _topProducts = [];
  
  bool _isLoading = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        
        final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
        totalValue += price;

        final rating = (data['rating'] ?? 0).toDouble();
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }

        final stock = data['stock'] ?? 0;
        if (stock == 0) {
          outOfStock++;
        } else if (stock < 10) {
          lowStock++;
        }

        final category = data['category'] ?? 'Other';
        categories[category] = (categories[category] ?? 0) + 1;

        allProducts.add({
          'title': data['title'] ?? 'Unknown',
          'price': price,
          'rating': rating,
          'stock': stock,
        });
      }

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
        title: const Text(
          'Analytics & Insights',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3C72),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              color: const Color(0xFF1E3C72),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12), // REDUCED from 16 to 12
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards Grid - FIXED OVERFLOW
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.4, // INCREASED from 1.2 to 1.4
                          crossAxisSpacing: 10, // REDUCED from 12 to 10
                          mainAxisSpacing: 10, // REDUCED from 12 to 10
                          children: [
                            _buildStatCard(
                              'Total Products',
                              _totalProducts.toString(),
                              Icons.inventory_2,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Total Value',
                              '\$${_totalValue.toStringAsFixed(0)}',
                              Icons.attach_money,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'Avg Price',
                              '\$${_averagePrice.toStringAsFixed(0)}',
                              Icons.calculate,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'Avg Rating',
                              _averageRating.toStringAsFixed(1),
                              Icons.star,
                              Colors.amber,
                            ),
                            _buildStatCard(
                              'Low Stock',
                              _lowStockCount.toString(),
                              Icons.warning,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'Out of Stock',
                              _outOfStockCount.toString(),
                              Icons.error,
                              Colors.red,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20), // REDUCED from 24 to 20

                        // Pie Chart
                        if (_categoryData.isNotEmpty) ...[
                          _buildSectionHeader('Products by Category'),
                          const SizedBox(height: 12), // REDUCED from 16 to 12
                          Container(
                            height: 250, // REDUCED from 280 to 250
                            padding: const EdgeInsets.all(12), // REDUCED from 16 to 12
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildPieChart(),
                          ),
                          const SizedBox(height: 20), // REDUCED from 24 to 20
                        ],

                        // Bar Chart
                        if (_topProducts.isNotEmpty) ...[
                          _buildSectionHeader('Top 5 Products by Price'),
                          const SizedBox(height: 12), // REDUCED from 16 to 12
                          Container(
                            height: 280, // REDUCED from 320 to 280
                            padding: const EdgeInsets.all(12), // REDUCED from 16 to 12
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildBarChart(),
                          ),
                          const SizedBox(height: 20), // REDUCED from 24 to 20
                        ],

                        // Category Legend
                        if (_categoryData.isNotEmpty) ...[
                          _buildSectionHeader('Category Breakdown'),
                          const SizedBox(height: 8), // REDUCED from 12 to 8
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
              ),
            ),
    );
  }

  // FIXED: More compact stat card
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // REDUCED from 16 to 12
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // ADDED
          children: [
            // Smaller icon container
            Container(
              padding: const EdgeInsets.all(8), // REDUCED from 12 to 8
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22), // REDUCED from 28 to 22
            ),
            const SizedBox(height: 8), // REDUCED from 12 to 8
            
            // Value with FittedBox
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18, // REDUCED from 22 to 18
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2), // REDUCED from 4 to 2
            
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 10, // REDUCED from 12 to 10
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Smaller section header
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22, // REDUCED from 28 to 22
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10), // REDUCED from 12 to 10
        Text(
          title,
          style: const TextStyle(
            fontSize: 18, // REDUCED from 20 to 18
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3C72),
          ),
        ),
      ],
    );
  }

  // Smaller pie chart
  Widget _buildPieChart() {
    final sections = _categoryData.entries.map((entry) {
      final percentage = (_totalProducts > 0)
          ? (entry.value / _totalProducts * 100)
          : 0;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 70, // REDUCED from 85 to 70
        titleStyle: const TextStyle(
          fontSize: 10, // REDUCED from 12 to 10
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 35, // REDUCED from 45 to 35
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
        ),
      ),
    );
  }

  // Smaller bar chart
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
                '',
                const TextStyle(),
                children: [
                  TextSpan(
                    text: '${_topProducts[group.x.toInt()]['title']}\n',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10, // REDUCED from 12 to 10
                    ),
                  ),
                  TextSpan(
                    text: '\$${rod.toY.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9, // REDUCED from 11 to 9
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
                  padding: const EdgeInsets.only(top: 6), // REDUCED from 8 to 6
                  child: Text(
                    _topProducts[value.toInt()]['title']
                        .toString()
                        .split(' ')
                        .first,
                    style: TextStyle(
                      fontSize: 8, // REDUCED from 10 to 8
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35, // REDUCED from 40 to 35
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}k',
                  style: TextStyle(
                    fontSize: 8, // REDUCED from 10 to 8
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: 1000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        barGroups: _topProducts.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value['price'],
                color: Colors.blue,
                width: 20, // REDUCED from 24 to 20
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

  // Smaller category legend
  Widget _buildCategoryLegend(String category, int count, double percentage, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6), // REDUCED from 8 to 6
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // REDUCED vertical from 14 to 8
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Smaller color indicator
          Container(
            width: 10, // REDUCED from 14 to 10
            height: 10, // REDUCED from 14 to 10
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8), // REDUCED from 12 to 8
          
          // Category name
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13, // REDUCED from 15 to 13
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          
          // Smaller count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, // REDUCED from 12 to 8
              vertical: 4, // REDUCED from 6 to 4
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: color,
                fontSize: 10, // REDUCED from 12 to 10
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Category Colors
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