/// Templates for the Local setup variant of the settings bundle: the
/// mode page that saves the backend address and finds servers on the
/// network with Bonsoir (portrait or landscape), the api_config.dart
/// it saves the address in, and the PressScale widget its buttons use.
/// Pure strings on purpose — GenerateService writes the files and wires
/// up pubspec.yaml, main.dart and the platform permissions.
///
/// The templates are raw strings, so the Dart inside them keeps its own
/// `$` interpolation as-is.
library;

class LocalSetupGenerator {
  /// `<uses-permission>`s Android needs for Bonsoir discovery and for
  /// reaching the backend on the LAN.
  static const List<String> androidPermissions = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.CHANGE_WIFI_MULTICAST_STATE',
  ];

  /// Info.plist keys (with their already-indented values) iOS 14+ needs
  /// before Bonsoir may browse the local network, plus the ATS exception
  /// for plain-http calls to a LAN IP. The service type has to match
  /// `_serviceType` in the mode page.
  static const Map<String, String> iosPlistEntries = {
    'NSBonjourServices':
        '\t<array>\n\t\t<string>_http._tcp</string>\n\t</array>\n',
    'NSLocalNetworkUsageDescription':
        '\t<string>Used to find and connect to the server on the local network.</string>\n',
    'NSAppTransportSecurity':
        '\t<dict>\n\t\t<key>NSAllowsLocalNetworking</key>\n\t\t<true/>\n\t</dict>\n',
  };

  /// mode.dart for the Local setup. Both orientations share everything
  /// except `build()` and the MODE panel: landscape puts MODE and NEXT
  /// on the left and SERVER on the right, with TESTING / LIVE stacked
  /// as two tall buttons so the left column has no empty gap.
  static String modePage({required bool landscape}) => [
        _modeTop,
        landscape ? _landscapeSizesDoc : _portraitSizesDoc,
        _modeState,
        landscape ? _landscapeBuild : _portraitBuild,
        _modeHeaderFooter,
        landscape ? _landscapeModePanel : _portraitModePanel,
        _modePieces,
      ].join();

  static const String apiConfig = r'''
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _ipKey = "api_ip";
const String _portKey = "api_port";

/// Port shown as the hint and used when nothing has been saved yet.
const String defaultApiPort = "3055";

/// Backend host, e.g. "192.168.0.12". Empty until the staff set it up.
final ValueNotifier<String> apiIp = ValueNotifier<String>("");

/// Backend port, e.g. "8000".
final ValueNotifier<String> apiPort = ValueNotifier<String>(defaultApiPort);

/// Base URL every request goes to, e.g. "http://192.168.0.12:8000".
String get apiUrl => "http://${apiIp.value}:${apiPort.value}";

/// Reads the server saved on the device. Call once before the first frame.
Future<void> loadSavedApi() async {
  final prefs = await SharedPreferences.getInstance();
  apiIp.value = prefs.getString(_ipKey) ?? "";
  apiPort.value = prefs.getString(_portKey) ?? defaultApiPort;
  debugPrint("Api Config: loaded '$apiUrl' from device");
}

/// Saves the server on the device so it survives restarts.
Future<void> saveApi({required String ip, required String port}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_ipKey, ip);
  await prefs.setString(_portKey, port);
  apiIp.value = ip;
  apiPort.value = port;
  debugPrint("Api Config: saved '$apiUrl' on device");
}
''';

  static const String pressScale = r'''
import 'package:flutter/material.dart';

/// Shrinks its child a little while pressed, so taps feel physical.
/// Passing a null [onTap] disables it.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
''';

  /// Imports and the class doc up to the line naming the design size.
  static const String _modeTop = r'''
import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../pages/Homepage.dart';
import '../widgets/press_scale.dart';
import 'api_config.dart';
import 'app_mode.dart';

/// First screen on every app start (local setup): pick TESTING or LIVE and
/// point the app at the backend — either by typing the IP and port or by
/// picking a service Bonsoir found on the local network.
///
/// Every choice is saved on the device, so the previous setup comes back
/// already filled in and keeps being used until it is changed.
///
''';

  static const String _portraitSizesDoc =
      '/// Sizes use ScreenUtil from main.dart (design 835 x 1194, portrait).\n';

  static const String _landscapeSizesDoc =
      '/// Sizes use ScreenUtil from main.dart (design 1194 x 835, landscape).\n';

  /// The widget, its state and every non-layout method, up to `build()`.
  static const String _modeState = r'''
class ModePage extends StatefulWidget {
  const ModePage({super.key});

  @override
  State<ModePage> createState() => _ModePageState();
}

class _ModePageState extends State<ModePage> {
  /// The service type the backend advertises itself with.
  static const String _serviceType = '_http._tcp';

  /// Used for everything that is selected or actionable.
  static const Color _red = Color(0xFFEF2938);

  /// Marks the one service the fields are currently pointing at.
  static const Color _yellow = Color(0xFFFFC400);

  /// null until the saved value is read, so nothing looks selected too early.
  bool? _isTesting;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;
  final List<BonsoirService> _services = [];
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _isTesting = isTestingMode.value;
    _ipController.text = apiIp.value;
    _portController.text = apiPort.value;

    // The picked-service highlight is read straight off the fields, so typing
    // an address by hand has to repaint the list as well.
    _ipController.addListener(_onAddressChanged);
    _portController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _discovery?.stop();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  // ===========================================================
  // MODE
  // ===========================================================

  Future<void> _select(bool testing) async {
    await saveMode(testing);
    if (!mounted) return;
    setState(() {
      _isTesting = testing;
    });
  }

  // ===========================================================
  // API ADDRESS
  // ===========================================================

  /// Saves what is in the two fields. Returns false (and complains) when
  /// either one is still empty.
  Future<bool> _saveApi() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      _toast("Please enter IP and Port");
      return false;
    }

    await saveApi(ip: ip, port: port);
    if (mounted) setState(() {});
    return true;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontSize: 16.sp)),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
  }

  Future<void> _next() async {
    if (!await _saveApi()) return;
    if (!mounted) return;

    await _stopDiscovery();
    if (!mounted) return;

    debugPrint("Mode Page: continuing in '$modeName' mode on '$apiUrl'.");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  // ===========================================================
  // NETWORK DISCOVERY
  // ===========================================================

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;

    final discovery = BonsoirDiscovery(type: _serviceType);
    await discovery.initialize();
    if (!mounted) {
      await discovery.stop();
      return;
    }

    setState(() {
      _discovery = discovery;
      _isDiscovering = true;
      _services.clear();
    });

    _subscription = discovery.eventStream!.listen((event) {
      if (!mounted) return;
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          // Only a resolved service carries the host address and port.
          event.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent():
          setState(() {
            _services
              ..removeWhere((s) => s.name == event.service.name)
              ..add(event.service);
          });
        case BonsoirDiscoveryServiceUpdatedEvent():
          setState(() {
            _services
              ..removeWhere((s) => s.name == event.service.name)
              ..add(event.service);
          });
        case BonsoirDiscoveryServiceLostEvent():
          setState(() {
            _services.removeWhere((s) => s.name == event.service.name);
          });
        default:
          break;
      }
    });

    await discovery.start();
  }

  Future<void> _stopDiscovery() async {
    await _subscription?.cancel();
    await _discovery?.stop();
    _subscription = null;
    _discovery = null;
    if (!mounted) return;
    setState(() {
      _isDiscovering = false;
    });
  }

  /// The address to talk to the service on.
  ///
  /// A service usually reports several addresses, and the IPv6 link-local one
  /// ("fe80::1429:7e50:b87b:4b8d%en0") often comes first — that is useless as
  /// an API host, so only the plain "192.168.0.12" style address is taken.
  /// Returns null while the service has no IPv4 address at all.
  String? _hostOf(BonsoirService service) {
    for (final address in service.hostAddresses) {
      if (InternetAddress.tryParse(address)?.type == InternetAddressType.IPv4) {
        return address;
      }
    }
    return null;
  }

  /// True for the service whose address is sitting in the fields right now —
  /// that is the one the app will talk to.
  bool _isPicked(BonsoirService service) {
    final String? host = _hostOf(service);
    if (host == null) return false;

    return host == _ipController.text.trim() &&
        service.port.toString() == _portController.text.trim();
  }

  void _useService(BonsoirService service) {
    final host = _hostOf(service);
    if (host == null) return;

    setState(() {
      _ipController.text = host;
      _portController.text = service.port.toString();
    });
    _toast("Using ${service.name}");
  }

  // ===========================================================
  // BUILD
  // ===========================================================

''';

  static const String _portraitBuild = r'''
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Same backdrop the game screens use, so this does not look like a
          // different app.
          // Positioned.fill(
          //   child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          // ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(40.w, 30.h, 40.w, 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  SizedBox(height: 28.h),
                  _modePanel(),
                  SizedBox(height: 24.h),

                  // Takes whatever height is left, so the page always fills
                  // the portrait screen without scrolling.
                  Expanded(child: _serverPanel()),

                  SizedBox(height: 24.h),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

''';

  static const String _landscapeBuild = r'''
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Same backdrop the game screens use, so this does not look like a
          // different app.
          // Positioned.fill(
          //   child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          // ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(40.w, 30.h, 40.w, 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  SizedBox(height: 28.h),

                  // MODE and NEXT on the left, SERVER on the right. Both
                  // columns take whatever height is left, so the page always
                  // fills the landscape screen without scrolling.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _modePanel()),
                              SizedBox(height: 24.h),
                              _footer(),
                            ],
                          ),
                        ),
                        SizedBox(width: 24.w),
                        Expanded(flex: 3, child: _serverPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

''';

  /// Header, mode chip and footer, up to the first panel.
  static const String _modeHeaderFooter = r'''
  // ===========================================================
  // HEADER / FOOTER
  // ===========================================================

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 44.sp,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  children: const [
                    TextSpan(
                      text: "Local ",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: "Setup",
                      style: TextStyle(color: _red),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Set this iPad up before the players arrive.",
                style: TextStyle(color: Colors.white54, fontSize: 17.sp),
              ),
            ],
          ),
        ),
        _modeChip(),
      ],
    );
  }

  /// Small badge in the header corner echoing the current mode, so the state
  /// is readable at a glance without hunting for the selected button.
  Widget _modeChip() {
    final bool testing = _isTesting ?? false;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: testing ? Colors.orange : const Color(0xFF08AA68),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Text(
        testing ? "TESTING" : "LIVE",
        style: TextStyle(
          color: Colors.white,
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _footer() {
    final bool hasTarget = apiIp.value.isNotEmpty;

    return Row(
      children: [
        Icon(
          hasTarget ? Icons.check_circle : Icons.error_outline,
          color: hasTarget ? const Color(0xFF08AA68) : Colors.white38,
          size: 22.r,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            hasTarget ? apiUrl : "No server saved yet",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasTarget ? Colors.white70 : Colors.white38,
              fontSize: 16.sp,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        PressScale(
          onTap: _next,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 34.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "NEXT",
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(width: 10.w),
                Icon(Icons.arrow_forward, color: Colors.white, size: 22.r),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // PANELS
  // ===========================================================

''';

  static const String _portraitModePanel = r'''
  Widget _modePanel() {
    return _panel(
      children: [
        _sectionLabel("MODE"),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: _modeButton(
                title: "TESTING",
                subtitle: "practice runs",
                icon: Icons.science_outlined,
                value: true,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: _modeButton(
                title: "LIVE",
                subtitle: "real event",
                icon: Icons.rocket_launch_outlined,
                value: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

''';

  static const String _landscapeModePanel = r'''
  /// TESTING above LIVE, both stretched to fill the left column.
  Widget _modePanel() {
    return _panel(
      children: [
        _sectionLabel("MODE"),
        SizedBox(height: 14.h),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _modeButton(
                  title: "TESTING",
                  subtitle: "practice runs",
                  icon: Icons.science_outlined,
                  value: true,
                ),
              ),
              SizedBox(height: 14.h),
              Expanded(
                child: _modeButton(
                  title: "LIVE",
                  subtitle: "real event",
                  icon: Icons.rocket_launch_outlined,
                  value: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

''';

  /// The SERVER panel and every building block, to the end of the file.
  static const String _modePieces = r'''
  Widget _serverPanel() {
    return _panel(
      children: [
        _sectionLabel("SERVER"),
        SizedBox(height: 14.h),
        _apiFields(),

        SizedBox(height: 26.h),
        _divider(),
        SizedBox(height: 20.h),

        Row(
          children: [
            Expanded(child: _sectionLabel("ON THIS NETWORK")),
            PressScale(
              onTap: _isDiscovering ? _stopDiscovery : _startDiscovery,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _isDiscovering ? _red : Colors.white10,
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(
                    color: _isDiscovering ? _red : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDiscovering ? Icons.stop : Icons.wifi_find_outlined,
                      color: Colors.white,
                      size: 18.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _isDiscovering ? "STOP" : "SCAN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 14.h),

        // Takes the rest of the panel and scrolls on its own, so a long list
        // never pushes the page out of shape.
        Expanded(child: _serviceList()),
      ],
    );
  }

  // ===========================================================
  // PIECES
  // ===========================================================

  /// The frosted block the panels are drawn on.
  Widget _panel({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 22.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Small red-tagged caption that opens each section of a panel.
  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 4.w, height: 16.h, color: _red),
        SizedBox(width: 10.w),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(height: 1, color: Colors.white12);

  Widget _modeButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
  }) {
    final bool isSelected = _isTesting == value;

    return PressScale(
      onTap: () => _select(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: isSelected ? _red : Colors.white10,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? _red : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Column(
          // Keeps the content centred when the button is stretched taller
          // than it needs to be.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 30.r,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            SizedBox(height: 10.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.white38,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "http://" + IP + port, in one bordered row like an address bar.
  Widget _apiFields() {
    final TextStyle fieldStyle = TextStyle(color: Colors.white, fontSize: 18.sp);
    final TextStyle hintStyle = TextStyle(color: Colors.white24, fontSize: 18.sp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 16.w, right: 4.w),
                child: Text(
                  "http://",
                  style: TextStyle(
                    color: _red,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.url,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    hintText: "192.168.0.12",
                    hintStyle: hintStyle,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 18.h,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 26.h, color: Colors.white24),
              SizedBox(
                width: 100.w,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    hintText: defaultApiPort,
                    hintStyle: hintStyle,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 18.h),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 14.h),

        PressScale(
          onTap: () async {
            if (await _saveApi()) _toast("Server address saved");
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_outlined, color: Colors.white, size: 20.r),
                SizedBox(width: 10.w),
                Text(
                  "SAVE SERVER",
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Everything Bonsoir has found so far, or a hint about what to do.
  Widget _serviceList() {
    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDiscovering) ...[
              SizedBox(
                width: 28.r,
                height: 28.r,
                child: const CircularProgressIndicator(
                  color: _red,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 14.h),
            ] else ...[
              Icon(
                Icons.wifi_tethering,
                color: Colors.white.withValues(alpha: 0.18),
                size: 44.r,
              ),
              SizedBox(height: 12.h),
            ],
            Text(
              _isDiscovering
                  ? "Looking for the game server..."
                  : "Tap SCAN to find the server automatically",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _services.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) => _serviceRow(_services[index]),
    );
  }

  Widget _serviceRow(BonsoirService service) {
    final String? host = _hostOf(service);
    final bool canUse = host != null;

    // The one that was tapped stays lit in yellow, so it is obvious which of
    // several servers on the network this iPad is pointed at.
    final bool isPicked = _isPicked(service);

    // No IPv4 yet: either still resolving, or the service only answered with
    // an IPv6 address, which the backend cannot be reached on.
    final String subtitle = canUse
        ? "$host:${service.port}"
        : (service.hostAddresses.isEmpty ? "Resolving..." : "No IPv4 address");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isPicked
            ? _yellow.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isPicked ? _yellow : Colors.white12,
          width: isPicked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dns_outlined,
            color: isPicked
                ? _yellow
                : (canUse ? Colors.white70 : Colors.white24),
            size: 22.r,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPicked ? _yellow : Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isPicked ? Colors.white70 : Colors.white54,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),

          // Already picked: the pill turns into a yellow "USED" badge rather
          // than a button, since tapping it again would change nothing.
          PressScale(
            onTap: (canUse && !isPicked) ? () => _useService(service) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: isPicked ? _yellow : (canUse ? _red : Colors.white12),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPicked) ...[
                    Icon(Icons.check, color: Colors.black, size: 15.r),
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    isPicked ? "USED" : "USE",
                    style: TextStyle(
                      color: isPicked
                          ? Colors.black
                          : (canUse ? Colors.white : Colors.white24),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''';
}
