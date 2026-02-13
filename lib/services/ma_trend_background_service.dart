import 'package:flutter/material.dart';
import 'log_service.dart';

/// 移动平均线趋势背景服务
class MaTrendBackgroundService {
  static final MaTrendBackgroundService _instance = MaTrendBackgroundService._internal();
  factory MaTrendBackgroundService() => _instance;
  MaTrendBackgroundService._internal();

  static MaTrendBackgroundService get instance => _instance;

  /// 计算基于移动平均线的趋势背景颜色
  /// 浅绿色：13均线 > 60均线 > 300均线（上升趋势）
  /// 浅红色：13均线 < 60均线 < 300均线（下降趋势）
  /// 返回null表示无趋势或数据不足
  Color? calculateTrendBackgroundColor({
    required List<double> ma13,
    required List<double> ma60,
    required List<double> ma300,
    required int index,
  }) {
    if (ma13.isEmpty || ma60.isEmpty || ma300.isEmpty) {
      LogService.instance.warning('MaTrendBackgroundService', '移动平均线数据为空');
      return null;
    }

    if (index < 0 || index >= ma13.length || index >= ma60.length || index >= ma300.length) {
      LogService.instance.warning('MaTrendBackgroundService', '索引超出范围: index=$index, ma13.length=${ma13.length}, ma60.length=${ma60.length}, ma300.length=${ma300.length}');
      return null;
    }

    final double ma13Value = ma13[index];
    final double ma60Value = ma60[index];
    final double ma300Value = ma300[index];

    // 检查是否有NaN值
    if (ma13Value.isNaN || ma60Value.isNaN || ma300Value.isNaN) {
      return null;
    }

    // 判断趋势
    // 上升趋势：13均线 > 60均线 > 300均线
    if (ma13Value > ma60Value && ma60Value > ma300Value) {
      return const Color(0xFF4CAF50).withValues(alpha: 0.1); // 浅绿色，透明度10%
    }
    
    // 下降趋势：13均线 < 60均线 < 300均线
    if (ma13Value < ma60Value && ma60Value < ma300Value) {
      return const Color(0xFFF44336).withValues(alpha: 0.1); // 浅红色，透明度10%
    }

    // 其他情况（无明确趋势）返回null
    return null;
  }

  /// 批量计算趋势背景颜色
  List<Color?> calculateTrendBackgroundColors({
    required List<double> ma13,
    required List<double> ma60,
    required List<double> ma300,
  }) {
    if (ma13.isEmpty || ma60.isEmpty || ma300.isEmpty) {
      return [];
    }

    final int length = [ma13.length, ma60.length, ma300.length].reduce((a, b) => a < b ? a : b);
    final List<Color?> colors = [];

    for (int i = 0; i < length; i++) {
      colors.add(calculateTrendBackgroundColor(
        ma13: ma13,
        ma60: ma60,
        ma300: ma300,
        index: i,
      ));
    }

    return colors;
  }

  /// 获取趋势背景颜色的描述
  String getTrendDescription(Color? color) {
    if (color == null) return '无趋势';
    
    final red = (color.r * 255.0).round() & 0xff;
    final green = (color.g * 255.0).round() & 0xff;
    final blue = (color.b * 255.0).round() & 0xff;
    
    if (red > blue && green > blue) {
      return '上升趋势（13>60>300）';
    } else if (red > green && blue < red) {
      return '下降趋势（13<60<300）';
    }
    
    return '其他趋势';
  }
}

/// 移动平均线趋势背景结果
class MaTrendBackgroundResult {
  final List<Color?> backgroundColors;
  final int totalPoints;
  final int risingTrendPoints;
  final int fallingTrendPoints;
  final double risingTrendPercentage;
  final double fallingTrendPercentage;

  const MaTrendBackgroundResult({
    required this.backgroundColors,
    required this.totalPoints,
    required this.risingTrendPoints,
    required this.fallingTrendPoints,
    required this.risingTrendPercentage,
    required this.fallingTrendPercentage,
  });
}
