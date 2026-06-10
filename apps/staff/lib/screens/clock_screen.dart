import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/staff_api_service.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Map<String, dynamic>? _attendance;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  String? _gpsStatus;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StaffApiService.getTodayAttendance();
      setState(() => _attendance = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Position?> _getLocation() async {
    setState(() => _gpsStatus = 'Requesting location...');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _gpsStatus = 'GPS disabled — clocking without location');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsStatus = 'Location denied — clocking without location');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsStatus = 'Location permanently denied');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _gpsStatus = '📍 ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      return pos;
    } catch (e) {
      setState(() => _gpsStatus = 'GPS error — clocking without location');
      return null;
    }
  }

  Future<void> _clockIn() async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final pos = await _getLocation();
      await StaffApiService.clockIn(
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      await _loadAttendance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Clocked in successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _clockOut() async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final pos = await _getLocation();
      await StaffApiService.clockOut(
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      await _loadAttendance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('👋 Clocked out. Have a good rest!'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '--';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a').format(dt);
  }

  Duration? _workedDuration() {
    if (_attendance == null) return null;
    final inTime = DateTime.tryParse(_attendance!['clockIn'] as String? ?? '');
    if (inTime == null) return null;
    final outRaw = _attendance!['clockOut'] as String?;
    final outTime = outRaw != null ? DateTime.tryParse(outRaw) : DateTime.now();
    if (outTime == null) return null;
    return outTime.difference(inTime);
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  bool get _isClockedIn => _attendance != null && _attendance!['clockOut'] == null;
  bool get _isClockedOut => _attendance != null && _attendance!['clockOut'] != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAttendance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Status card
                    _buildStatusCard(),
                    const SizedBox(height: 20),

                    // GPS info
                    if (_gpsStatus != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_gpsStatus!, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    if (!_actionLoading) ...[
                      if (!_isClockedIn && !_isClockedOut)
                        _bigButton(
                          label: 'Clock In',
                          icon: Icons.login,
                          color: Colors.green,
                          onTap: _clockIn,
                        ),
                      if (_isClockedIn)
                        _bigButton(
                          label: 'Clock Out',
                          icon: Icons.logout,
                          color: Colors.red,
                          onTap: _clockOut,
                        ),
                      if (_isClockedOut) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Shift completed for today!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Getting GPS & recording...'),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Today's summary
                    _buildTodaySummary(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    Color bgColor;
    Color textColor;
    String statusText;
    IconData statusIcon;

    if (_isClockedIn) {
      bgColor = Colors.green;
      textColor = Colors.white;
      statusText = 'Currently Working';
      statusIcon = Icons.work;
    } else if (_isClockedOut) {
      bgColor = Colors.blue;
      textColor = Colors.white;
      statusText = 'Shift Complete';
      statusIcon = Icons.check_circle;
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.black87;
      statusText = 'Not Clocked In';
      statusIcon = Icons.schedule;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: textColor, size: 40),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d').format(DateTime.now()),
            style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    if (_attendance == null) return const SizedBox();
    final worked = _workedDuration();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Shift", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _row(Icons.login, 'Clock In', _fmtTime(_attendance!['clockIn'] as String?)),
            const Divider(height: 20),
            _row(Icons.logout, 'Clock Out', _fmtTime(_attendance!['clockOut'] as String?)),
            if (worked != null) ...[
              const Divider(height: 20),
              _row(Icons.timer, 'Time Worked', _fmtDuration(worked)),
            ],
            if (_attendance!['latIn'] != null) ...[
              const Divider(height: 20),
              _row(Icons.location_on, 'In Location',
                '${double.parse(_attendance!['latIn'].toString()).toStringAsFixed(4)}, '
                '${double.parse(_attendance!['lngIn'].toString()).toStringAsFixed(4)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.black54)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        icon: Icon(icon, size: 26),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
    );
  }
}
