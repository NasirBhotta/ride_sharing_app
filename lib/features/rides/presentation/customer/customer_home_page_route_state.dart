part of 'customer_home_page.dart';

enum _RouteState {
  idle,
  loading,
  success,
  noApiKey,
  missingCoords,
  apiError,
  emptyResult,
  exception,
}
