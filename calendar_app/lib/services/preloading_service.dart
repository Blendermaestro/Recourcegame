import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:flutter/foundation.dart';

class PreloadingService {
  static const int _preloadRange = 6; // ±6 weeks = ~3 months total
  
  /// Preload assignments for multiple weeks around the current week
  /// Returns a stream of progress (0.0 to 1.0)
  static Stream<double> preloadAroundCurrentWeek(int currentWeek) async* {
    print('🚀 PreloadingService: Starting mass preload around week $currentWeek');
    
    // Calculate weeks to preload (current ± range)
    final weeksToLoad = <int>[];
    for (int offset = -_preloadRange; offset <= _preloadRange; offset++) {
      final targetWeek = currentWeek + offset;
      if (targetWeek >= 1 && targetWeek <= 52) {
        // Only add if not already loaded
        if (SharedAssignmentData.getWeekAssignmentCount(targetWeek) == 0) {
          weeksToLoad.add(targetWeek);
        }
      }
    }
    
    if (weeksToLoad.isEmpty) {
      print('🚀 PreloadingService: All weeks already loaded, skipping preload');
      yield 1.0;
      return;
    }
    
    print('🚀 PreloadingService: Preloading ${weeksToLoad.length} weeks: $weeksToLoad');
    
    // Load weeks with progress updates
    for (int i = 0; i < weeksToLoad.length; i++) {
      final week = weeksToLoad[i];
      
      try {
        // Yield progress before loading
        yield (i + 0.5) / weeksToLoad.length;
        
        final assignments = await SharedDataService.loadAssignments(week);
        SharedAssignmentData.updateAssignmentsForWeek(week, assignments);
        
        print('🚀 PreloadingService: ✅ Loaded week $week (${assignments.length} assignments)');
        
        // Yield progress after loading
        yield (i + 1.0) / weeksToLoad.length;
        
        // Small delay between loads to prevent overwhelming database
        if (i < weeksToLoad.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
      } catch (e) {
        print('🚀 PreloadingService: ❌ Failed to load week $week: $e');
        // Continue with other weeks even if one fails
      }
    }
    
    print('🚀 PreloadingService: ✅ Mass preload complete! Loaded ${weeksToLoad.length} weeks');
    
    // Force refresh to update all views
    SharedAssignmentData.forceRefresh();
  }
  
  /// Check how many weeks around current week are already cached
  static int getCachedWeeksCount(int currentWeek) {
    int cachedCount = 0;
    for (int offset = -_preloadRange; offset <= _preloadRange; offset++) {
      final targetWeek = currentWeek + offset;
      if (targetWeek >= 1 && targetWeek <= 52) {
        if (SharedAssignmentData.getWeekAssignmentCount(targetWeek) > 0) {
          cachedCount++;
        }
      }
    }
    return cachedCount;
  }
  
  /// Get total weeks that should be cached
  static int getTotalWeeksToCache(int currentWeek) {
    int totalCount = 0;
    for (int offset = -_preloadRange; offset <= _preloadRange; offset++) {
      final targetWeek = currentWeek + offset;
      if (targetWeek >= 1 && targetWeek <= 52) {
        totalCount++;
      }
    }
    return totalCount;
  }
} 