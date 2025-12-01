import '../constants/app_constants.dart';
import '../network/api_client.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  // Get events
  Future<List<Map<String, dynamic>>> getEvents({
    String? search,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (search != null && search.isNotEmpty) query['q'] = search;
      if (type != null && type.isNotEmpty) query['event_type'] = type;
      if (startDate != null) query['start_date'] = startDate.toIso8601String();
      if (endDate != null) query['end_date'] = endDate.toIso8601String();

      final response = await _apiClient.get(
        AppConstants.eventsEndpoint,
        queryParameters: query,
      );
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      print('Error getting events: $e');
      rethrow;
    }
  }

  // Create event
  Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> eventData) async {
    try {
      final response = await _apiClient.post(
        AppConstants.eventsEndpoint,
        data: eventData,
      );
      return response.data['data'];
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  // Update event
  Future<Map<String, dynamic>> updateEvent(
    String id,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final response = await _apiClient.put(
        '${AppConstants.eventsEndpoint}/$id',
        data: eventData,
      );
      return response.data['data'];
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // Delete event
  Future<void> deleteEvent(String id) async {
    try {
      await _apiClient.delete('${AppConstants.eventsEndpoint}/$id');
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // Sync events
  Future<Map<String, dynamic>> syncEvents(
    List<Map<String, dynamic>> localEvents, {
    DateTime? lastSyncTime,
  }) async {
    try {
      final response = await _apiClient.post(
        '${AppConstants.eventsEndpoint}/sync',
        data: {
          'events': localEvents,
          'lastSyncTime':
              (lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .toIso8601String(),
        },
      );
      return Map<String, dynamic>.from(response.data['data'] ?? response.data);
    } catch (e) {
      print('Error syncing events: $e');
      rethrow;
    }
  }
}
