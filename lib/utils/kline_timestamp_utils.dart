import '../models/price_data.dart';
import '../models/timeframe.dart';

/// K线时间戳工具类
/// 用于在不同时间周期之间进行时间戳转换和K线定位
class KlineTimestampUtils {
  
  /// 根据时间戳在K线数据中查找对应的索引
  /// 如果找不到精确匹配，返回最接近的索引
  static int? findKlineIndexByTimestamp(List<PriceData> data, int timestamp) {
    if (data.isEmpty) return null;
    
    // 二分查找最接近的时间戳
    int left = 0;
    int right = data.length - 1;
    int closestIndex = -1;
    int minDiff = 9223372036854775807; // int.maxFinite equivalent
    
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      int midTimestamp = data[mid].timestamp;
      
      int diff = (midTimestamp - timestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = mid;
      }
      
      if (midTimestamp == timestamp) {
        return mid; // 精确匹配
      } else if (midTimestamp < timestamp) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    
    // 如果没有精确匹配，检查最接近的时间戳是否在合理范围内
    if (closestIndex != -1) {
      final closestTimestamp = data[closestIndex].timestamp;
      final timeDiff = (closestTimestamp - timestamp).abs();
      
      // 如果时间差在5分钟内，认为是同一个K线
      if (timeDiff <= 5 * 60 * 1000) { // 5分钟 = 5 * 60 * 1000 毫秒
        return closestIndex;
      }
    }
    
    return null;
  }
  
  /// 根据时间戳在K线数据中查找对应的K线
  static PriceData? findKlineByTimestamp(List<PriceData> data, int timestamp) {
    final index = findKlineIndexByTimestamp(data, timestamp);
    if (index != null && index >= 0 && index < data.length) {
      return data[index];
    }
    return null;
  }
  
  /// 将时间戳对齐到指定时间周期的开始时间
  /// 例如：5分钟周期会将时间戳对齐到5分钟的整数倍
  static int alignTimestampToTimeframe(int timestamp, Timeframe timeframe) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    
    switch (timeframe) {
      case Timeframe.m5:
        // 对齐到5分钟的整数倍
        final minute = (dateTime.minute ~/ 5) * 5;
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          minute,
          0,
        ).millisecondsSinceEpoch;
      
      case Timeframe.m15:
        // 对齐到15分钟的整数倍
        final minute = (dateTime.minute ~/ 15) * 15;
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          minute,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.m30:
        // 对齐到30分钟的整数倍
        final minute = (dateTime.minute ~/ 30) * 30;
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          minute,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.h1:
        // 对齐到1小时的整数倍
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          0,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.h2:
        // 对齐到2小时的整数倍
        final hour = (dateTime.hour ~/ 2) * 2;
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          hour,
          0,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.h4:
        // 对齐到4小时的整数倍
        final hour = (dateTime.hour ~/ 4) * 4;
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          hour,
          0,
          0,
        ).millisecondsSinceEpoch;
    }
  }
  
  /// 检查时间戳是否在指定时间周期内
  static bool isTimestampInTimeframe(int timestamp, Timeframe timeframe) {
    final alignedTimestamp = alignTimestampToTimeframe(timestamp, timeframe);
    return alignedTimestamp == timestamp;
  }
  
  /// 获取时间戳对应的下一个时间周期开始时间
  static int getNextTimeframeTimestamp(int timestamp, Timeframe timeframe) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    
    switch (timeframe) {
      case Timeframe.m5:
        // 下一个5分钟
        final nextMinute = ((dateTime.minute ~/ 5) + 1) * 5;
        if (nextMinute >= 60) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour + 1,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            nextMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.m15:
        // 下一个15分钟
        final nextMinute = ((dateTime.minute ~/ 15) + 1) * 15;
        if (nextMinute >= 60) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour + 1,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            nextMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.m30:
        // 下一个30分钟
        final nextMinute = ((dateTime.minute ~/ 30) + 1) * 30;
        if (nextMinute >= 60) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour + 1,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            nextMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.h1:
        // 下一个1小时
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour + 1,
          0,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.h2:
        // 下一个2小时
        final nextHour = ((dateTime.hour ~/ 2) + 1) * 2;
        if (nextHour >= 24) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day + 1,
            0,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            nextHour,
            0,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.h4:
        // 下一个4小时
        final nextHour = ((dateTime.hour ~/ 4) + 1) * 4;
        if (nextHour >= 24) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day + 1,
            0,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            nextHour,
            0,
            0,
          ).millisecondsSinceEpoch;
        }
        
    }
  }
  
  /// 获取时间戳对应的上一个时间周期开始时间
  static int getPreviousTimeframeTimestamp(int timestamp, Timeframe timeframe) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    
    switch (timeframe) {
      case Timeframe.m5:
        // 上一个5分钟
        final prevMinute = ((dateTime.minute ~/ 5) - 1) * 5;
        if (prevMinute < 0) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour - 1,
            55,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            prevMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.m15:
        // 上一个15分钟
        final prevMinute = ((dateTime.minute ~/ 15) - 1) * 15;
        if (prevMinute < 0) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour - 1,
            45,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            prevMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.m30:
        // 上一个30分钟
        final prevMinute = ((dateTime.minute ~/ 30) - 1) * 30;
        if (prevMinute < 0) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour - 1,
            30,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            prevMinute,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.h1:
        // 上一个1小时
        return DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour - 1,
          0,
          0,
        ).millisecondsSinceEpoch;
        
      case Timeframe.h2:
        // 上一个2小时
        final prevHour = ((dateTime.hour ~/ 2) - 1) * 2;
        if (prevHour < 0) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day - 1,
            22,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            prevHour,
            0,
            0,
          ).millisecondsSinceEpoch;
        }
        
      case Timeframe.h4:
        // 上一个4小时
        final prevHour = ((dateTime.hour ~/ 4) - 1) * 4;
        if (prevHour < 0) {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day - 1,
            20,
            0,
            0,
          ).millisecondsSinceEpoch;
        } else {
          return DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            prevHour,
            0,
            0,
          ).millisecondsSinceEpoch;
        }
        
    }
  }
  
  /// 格式化时间戳为可读的时间字符串
  static String formatTimestamp(int timestamp, {bool includeSeconds = false}) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    if (includeSeconds) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// 计算两个时间戳之间的时间差（以毫秒为单位）
  static int getTimeDifference(int timestamp1, int timestamp2) {
    return (timestamp1 - timestamp2).abs();
  }
  
  /// 检查时间戳是否在指定范围内
  static bool isTimestampInRange(int timestamp, int startTimestamp, int endTimestamp) {
    return timestamp >= startTimestamp && timestamp <= endTimestamp;
  }
}
