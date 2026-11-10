import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'api_service.dart';

class LocationState extends ChangeNotifier {
  static final LocationState instance = LocationState._();
  LocationState._();

  double? _lat;
  double? _lng;
  String _label = '';
  String _source = 'none'; // 'gps', 'custom', or 'none'
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  double? get lat => _lat;
  double? get lng => _lng;
  String get label => _label;
  String get source => _source;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasLocation => _lat != null && _lng != null && _source != 'none';

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> init() async {
    _loading = true;
    _safeNotify();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble('dawa_custom_lat');
      final savedLng = prefs.getDouble('dawa_custom_lng');
      final savedLabel = prefs.getString('dawa_custom_label');

      if (savedLat != null && savedLng != null && savedLabel != null && savedLabel.isNotEmpty) {
        _lat = savedLat;
        _lng = savedLng;
        _label = savedLabel;
        _source = 'custom';
        _loading = false;
        _error = null;
        _safeNotify();
        return;
      }
    } catch (_) {}

    await useCurrentLocation();
  }

  Future<void> useCurrentLocation() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _source = 'none';
        _error = 'Location services are disabled';
        _loading = false;
        _safeNotify();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _source = 'none';
          _error = 'Location permission denied';
          _loading = false;
          _safeNotify();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _source = 'none';
        _error = 'Location permission permanently denied';
        _loading = false;
        _safeNotify();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lat = pos.latitude;
      _lng = pos.longitude;
      _source = 'gps';
      _error = null;

      // Reverse geocode to get label
      final rev = await ApiService.instance.reverseGeocode(pos.latitude, pos.longitude);
      if (rev != null && rev['short_label'] != null && rev['short_label'].toString().isNotEmpty) {
        _label = rev['short_label'].toString();
      } else {
        _label = '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
      }

      _loading = false;
      _safeNotify();
    } catch (e) {
      _source = 'none';
      _error = 'Could not determine GPS position';
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> setCustom(double lat, double lng, String label) async {
    _lat = lat;
    _lng = lng;
    _label = label;
    _source = 'custom';
    _loading = false;
    _error = null;
    _safeNotify();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('dawa_custom_lat', lat);
      await prefs.setDouble('dawa_custom_lng', lng);
      await prefs.setString('dawa_custom_label', label);
    } catch (_) {}
  }
}

Future<void> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 580),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => const LocationPickerModal(),
  );
}

class LocationPickerModal extends StatefulWidget {
  const LocationPickerModal({super.key});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.length < 3) {
      setState(() {
        _query = trimmed;
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _query = trimmed;
      _searching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final res = await ApiService.instance.searchPlaces(trimmed);
      if (!mounted || _query != trimmed) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Location', style: t(18, w: FontWeight.w800, c: C.indigo)),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: C.sub),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 1. Use My Current Location Tile
          DawaSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () async {
              Navigator.pop(context);
              await LocationState.instance.useCurrentLocation();
            },
            child: Row(
              children: [
                const IconChip(Icons.my_location_rounded, size: 38, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Use my current location', style: t(14.5, w: FontWeight.w700, c: C.text)),
                      Text('Detect via device GPS', style: t(12, c: C.sub)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.sub, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 2. Search Box
          TextField(
            controller: _searchCtrl,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search city, street or area worldwide...',
              hintStyle: t(13.5, c: const Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search_rounded, color: C.purple, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: C.sub),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onChanged('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          // 3. Search Results or Status
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: _searching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
                    ),
                  )
                : _query.length >= 3 && _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No places found', style: t(14, c: C.sub)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1EDFF)),
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          final short = item['short_label'] ?? '';
                          final full = item['label'] ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: const Icon(Icons.location_on_outlined, color: C.purple, size: 20),
                            title: Text(short, style: t(14, w: FontWeight.w700, c: C.text)),
                            subtitle: Text(full, style: t(12, c: C.sub), maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              final lat = (item['lat'] as num).toDouble();
                              final lng = (item['lng'] as num).toDouble();
                              LocationState.instance.setCustom(lat, lng, short.isNotEmpty ? short : full);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
