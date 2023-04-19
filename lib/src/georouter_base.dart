import 'dart:convert';

import 'package:http/http.dart' as http;
import 'models/exceptions.dart';
import 'models/point.dart';

enum TravelMode { driving, walking, cycling, transit }

enum RouteKernal { osrm, valhalla, customize }

class GeoRouter extends _GeoRouterService {
  final TravelMode mode;
  final RouteKernal kernal;

  GeoRouter({required this.mode, required this.kernal});

  Future<List<PolylinePoint>> getDirectionsBetweenPoints(
      List<PolylinePoint> coordinates) async {
    try {
      final polyLines = await _getDirections(kernal, coordinates);
      return polyLines;
    } catch (e) {
      rethrow;
    }
  }

  @override
  String _getTravelMode() {
    switch (mode) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'walking';
      case TravelMode.cycling:
        return 'cycling';
      case TravelMode.transit:
        return 'transit';
      default:
        return 'driving';
    }
  }

  @override
  String _getRouteKernal() {
    switch (kernal) {
      case RouteKernal.osrm:
        return 'driving';
      case RouteKernal.valhalla:
        return 'walking';
      case RouteKernal.customize:
        return 'cycling';
      default:
        return 'driving';
    }
  }
}

abstract class _GeoRouterService {
  // OSRM
  static const String _baseUrl = 'router.project-osrm.org';
  static const String _path = '/route/v1';
  static const String _options = 'overview=full&annotations=true';

  //Valhala
  static const String _baseUrl_valhala = 'valhalla1.openstreetmap.de';
  static const String _path_valhala = '/route?json=';
  static const String _location_valhala = '"locations":[';
  static const String _location_end_valhala = ']';
  static const String _options_valhala = '"costing":"bicycle"';

  Future<List<PolylinePoint>> _getDirections(
    RouteKernal kernal,
    List<PolylinePoint> coordinates,
  ) async {
    switch (kernal) {
      case RouteKernal.osrm:
        final String coordinatesString = _getCoordinatesString(coordinates);
        final Uri url =
            Uri.https(_baseUrl, '$_path/${_getTravelMode()}/$coordinatesString?$_options');
        print('url = $url');
        try {
          final http.Response response = await http.get(url);

          if (response.statusCode == 200) {
            final geometry = jsonDecode(response.body)['routes'][0]['geometry'];
            final List<PolylinePoint> polylines = _decodePolyline(geometry);
            return polylines;
          } else {
            throw HttpException(response.statusCode);
          }
        } on FormatException catch (e) {
          throw FormatException(e.message);
        } catch (e) {
          throw GeoRouterException('Failed to fetch directions: $e');
        }
      case RouteKernal.valhalla:
        final String coordinatesString = _getCoordinatesStringValhala(coordinates);
        final Uri url = Uri.https('valhalla1.openstreetmap.de', '/route', {
          'json': jsonEncode({
            'locations': [
              {'lat': coordinates[0].latitude, 'lon': coordinates[0].longitude},
              {'lat': coordinates[1].latitude, 'lon': coordinates[1].longitude}
            ],
            'costing': 'bicycle',
            'directions_options': {'units': 'kilometers'},
            'exclude': ['motorway', 'toll']
          }),
        });
        print('url = $url');
        try {
          final http.Response response = await http.get(url);

          if (response.statusCode == 200) {
            final geometry = jsonDecode(response.body)['trip'][0]['legs'][0]['shape'];
            final List<PolylinePoint> polylines = _decodePolyline(geometry);
            return polylines;
          } else {
            throw HttpException(response.statusCode);
          }
        } on FormatException catch (e) {
          throw FormatException(e.message);
        } catch (e) {
          throw GeoRouterException('Failed to fetch directions: $e');
        }
      case RouteKernal.customize:
        final String coordinatesString = _getCoordinatesString(coordinates);
        final Uri url =
            Uri.https(_baseUrl, '$_path/${_getTravelMode()}/$coordinatesString?$_options');
        print('url = $url');
        try {
          final http.Response response = await http.get(url);

          if (response.statusCode == 200) {
            final geometry = jsonDecode(response.body)['routes'][0]['geometry'];
            final List<PolylinePoint> polylines = _decodePolyline(geometry);
            return polylines;
          } else {
            throw HttpException(response.statusCode);
          }
        } on FormatException catch (e) {
          throw FormatException(e.message);
        } catch (e) {
          throw GeoRouterException('Failed to fetch directions: $e');
        }
      default:
        final String coordinatesString = _getCoordinatesString(coordinates);
        final Uri url =
            Uri.https(_baseUrl, '$_path/${_getTravelMode()}/$coordinatesString?$_options');
        print('url = $url');
        try {
          final http.Response response = await http.get(url);

          if (response.statusCode == 200) {
            final geometry = jsonDecode(response.body)['routes'][0]['geometry'];
            final List<PolylinePoint> polylines = _decodePolyline(geometry);
            return polylines;
          } else {
            throw HttpException(response.statusCode);
          }
        } on FormatException catch (e) {
          throw FormatException(e.message);
        } catch (e) {
          throw GeoRouterException('Failed to fetch directions: $e');
        }
    }
  }

  String _getTravelMode();

  static String _getCoordinatesString(List<PolylinePoint> coordinates) {
    final List<String> coords =
        coordinates.map((point) => '${point.longitude},${point.latitude}').toList();
    return coords.join(';');
  }

  String _getCoordinatesStringValhala(List coordinates) {
    final List<String> coords = coordinates
        .map((point) => '{"lat":${point.longitude},"lon":${point.latitude}}')
        .toList();
    return coords.join(',');
  }

  static List<PolylinePoint> _decodePolyline(String encoded) {
    final List<PolylinePoint> points = <PolylinePoint>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final PolylinePoint point = PolylinePoint(latitude: lat / 1E5, longitude: lng / 1E5);
      points.add(point);
    }

    return points;
  }
}
