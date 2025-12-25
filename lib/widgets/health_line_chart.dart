import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/attendance.dart';

/// 健康データポイント
class HealthDataPoint {
  final String date;
  final int? value;
  final String? label; // 例: "3（普通）"

  HealthDataPoint({
    required this.date,
    this.value,
    this.label,
  });
}

/// 健康データ種別
enum HealthMetricType {
  healthCondition, // 本日の体調
  sleepStatus,     // 睡眠状況
  fatigue,         // 疲労感
  stress,          // 心理的負荷
}

extension HealthMetricTypeExtension on HealthMetricType {
  String get title {
    switch (this) {
      case HealthMetricType.healthCondition:
        return '本日の体調';
      case HealthMetricType.sleepStatus:
        return '睡眠状況';
      case HealthMetricType.fatigue:
        return '疲労感';
      case HealthMetricType.stress:
        return '心理的負荷';
    }
  }

  Color get color {
    switch (this) {
      case HealthMetricType.healthCondition:
        return Colors.green;
      case HealthMetricType.sleepStatus:
        return Colors.blue;
      case HealthMetricType.fatigue:
        return Colors.orange;
      case HealthMetricType.stress:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case HealthMetricType.healthCondition:
        return Icons.favorite;
      case HealthMetricType.sleepStatus:
        return Icons.bedtime;
      case HealthMetricType.fatigue:
        return Icons.battery_alert;
      case HealthMetricType.stress:
        return Icons.psychology;
    }
  }

  /// 値が良いほど高いか低いか
  bool get higherIsBetter {
    switch (this) {
      case HealthMetricType.healthCondition:
      case HealthMetricType.sleepStatus:
        return true;
      case HealthMetricType.fatigue:
      case HealthMetricType.stress:
        return false;
    }
  }
}

/// Attendanceから健康データポイントを抽出
List<HealthDataPoint> extractHealthData(
  List<Attendance> attendances,
  HealthMetricType type,
) {
  return attendances.map((a) {
    String? rawValue;
    switch (type) {
      case HealthMetricType.healthCondition:
        rawValue = a.healthCondition;
        break;
      case HealthMetricType.sleepStatus:
        rawValue = a.sleepStatus;
        break;
      case HealthMetricType.fatigue:
        rawValue = a.fatigue;
        break;
      case HealthMetricType.stress:
        rawValue = a.stress;
        break;
    }

    return HealthDataPoint(
      date: a.date,
      value: _extractNumber(rawValue),
      label: rawValue,
    );
  }).toList();
}

/// 文字列から数値を抽出（例: "3（普通）" -> 3）
int? _extractNumber(String? value) {
  if (value == null || value.isEmpty) return null;
  final match = RegExp(r'^\d+').firstMatch(value);
  if (match != null) {
    return int.tryParse(match.group(0)!);
  }
  return null;
}

/// ミニ折れ線グラフ（カード用）
class MiniHealthLineChart extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;
  final HealthMetricType type;
  final double height;
  final double width;
  final VoidCallback? onTap;

  const MiniHealthLineChart({
    super.key,
    required this.dataPoints,
    required this.type,
    this.height = 40,
    this.width = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 有効なデータポイントのみ抽出
    final validPoints = dataPoints.where((p) => p.value != null).toList();

    if (validPoints.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            '--',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ),
      );
    }

    // 直近の値を表示用に取得
    final latestValue = validPoints.isNotEmpty ? validPoints.last.value : null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: SizedBox(
          width: width,
          height: height,
          child: Row(
            children: [
              // グラフ
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 3, // 1, 4, 7, 10に線を表示
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade400,
                          strokeWidth: 0.5,
                        );
                      },
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    clipData: const FlClipData.all(),
                    minY: 1,
                    maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _createSpots(validPoints),
                      isCurved: false, // 直線で結ぶ
                      color: Colors.blue.shade600,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.blue.shade600,
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false), // 塗りつぶしなし
                    ),
                  ],
                ),
              ),
            ),
            // 直近の値
            if (latestValue != null)
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Text(
                  '$latestValue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getValueColor(latestValue, type),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _createSpots(List<HealthDataPoint> points) {
    return points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value!.toDouble());
    }).toList();
  }

  Color _getValueColor(int value, HealthMetricType type) {
    if (type.higherIsBetter) {
      if (value >= 4) return Colors.green;
      if (value >= 3) return Colors.orange;
      return Colors.red;
    } else {
      if (value <= 2) return Colors.green;
      if (value <= 3) return Colors.orange;
      return Colors.red;
    }
  }
}

/// 詳細折れ線グラフ（詳細画面用）
class HealthLineChartCard extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;
  final HealthMetricType type;
  final VoidCallback? onTap;

  const HealthLineChartCard({
    super.key,
    required this.dataPoints,
    required this.type,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final validPoints = dataPoints.where((p) => p.value != null).toList();
    final average = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a + b) / validPoints.length
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  Icon(type.icon, color: type.color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (average != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '平均 ${average.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: type.color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // グラフ
              SizedBox(
                height: 80,
                child: validPoints.isEmpty
                    ? Center(
                        child: Text(
                          'データなし',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < validPoints.length) {
                                    final date = validPoints[index].date;
                                    // MM/DD形式に変換
                                    final parts = date.split('/');
                                    if (parts.length >= 3) {
                                      return Text(
                                        '${parts[1]}/${parts[2]}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    }
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 20,
                                getTitlesWidget: (value, meta) {
                                  if (value == 1 || value == 3 || value == 5) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 6,
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: validPoints.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.value!.toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: type.color,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: type.color,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: type.color.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              // タップヒント
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'タップで詳細表示',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// グラフ詳細ダイアログ
class HealthChartDetailDialog extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;
  final HealthMetricType type;

  const HealthChartDetailDialog({
    super.key,
    required this.dataPoints,
    required this.type,
  });

  static void show(
    BuildContext context, {
    required List<HealthDataPoint> dataPoints,
    required HealthMetricType type,
  }) {
    showDialog(
      context: context,
      builder: (context) => HealthChartDetailDialog(
        dataPoints: dataPoints,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = dataPoints.where((p) => p.value != null).toList();
    final average = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a + b) / validPoints.length
        : null;
    final maxValue = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a > b ? a : b)
        : null;
    final minValue = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a < b ? a : b)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: type.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(type.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${type.title} - 過去${dataPoints.length}回分',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 統計情報
            if (average != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: type.color.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('平均', average.toStringAsFixed(1)),
                    _buildStatItem('最高', maxValue?.toString() ?? '--'),
                    _buildStatItem('最低', minValue?.toString() ?? '--'),
                  ],
                ),
              ),

            // グラフ
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 150,
                child: validPoints.isEmpty
                    ? const Center(child: Text('データがありません'))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 1,
                            verticalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              );
                            },
                            getDrawingVerticalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < validPoints.length) {
                                    final date = validPoints[index].date;
                                    final parts = date.split('/');
                                    if (parts.length >= 3) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          '${parts[1]}/${parts[2]}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  if (value >= 1 && value <= 5) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          minY: 0,
                          maxY: 6,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final index = spot.x.toInt();
                                  if (index >= 0 && index < validPoints.length) {
                                    final point = validPoints[index];
                                    return LineTooltipItem(
                                      '${point.date}\n${point.label ?? point.value}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return null;
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: validPoints.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.value!.toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: type.color,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: type.color,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: type.color.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // 履歴一覧
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: dataPoints.length,
                itemBuilder: (context, index) {
                  final point = dataPoints[index];
                  return _buildHistoryItem(point, index == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: type.color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(HealthDataPoint point, bool isLatest) {
    final hasValue = point.value != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 日付
          SizedBox(
            width: 80,
            child: Text(
              _formatDate(point.date),
              style: TextStyle(
                fontSize: 13,
                color: isLatest ? type.color : Colors.grey.shade700,
                fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // 値
          Expanded(
            child: Text(
              point.label ?? '--',
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
          // インジケーター
          if (hasValue)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getValueColor(point.value!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '${point.value}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getValueColor(point.value!),
                ),
              ),
            ),
          if (isLatest)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '最新',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final parts = date.split('/');
    if (parts.length >= 3) {
      return '${parts[1]}/${parts[2]}';
    }
    return date;
  }

  Color _getValueColor(int value) {
    if (type.higherIsBetter) {
      if (value >= 4) return Colors.green;
      if (value >= 3) return Colors.orange;
      return Colors.red;
    } else {
      if (value <= 2) return Colors.green;
      if (value <= 3) return Colors.orange;
      return Colors.red;
    }
  }
}
