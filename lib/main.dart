import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/laravel_auth_manager.dart';
import 'auth/base_auth_user_provider.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/shared/index.dart' as shared;
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'app_state.dart';
import '/backend/api_service.dart';
import '/shared/toast_service.dart';
import '/components/create_invoice_modal.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background messaging handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// ─────────────────────────────────────────────────────────────────────────────
// Global role helper — checks the authenticated user's role slug
// ─────────────────────────────────────────────────────────────────────────────
bool get isAdminUser => shared.AuthHelpers.isAdmin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Task 10.8: Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await LaravelAuthManager.initialize();
  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  try {
      await shared.BackgroundGpsService.initializeService();
  } catch(e) {
      print('Background GPS Service Init Error: $e');
  }

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = LaravelAuthManager.userStream
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Workers',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        bottomSheetTheme: const BottomSheetThemeData(
          // Globally enforce that ALL bottom sheet modals respect
          // the system bottom safe area (gesture bar / nav bar).
          showDragHandle: false,
          clipBehavior: Clip.none,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        bottomSheetTheme: const BottomSheetThemeData(
          showDragHandle: false,
          clipBehavior: Clip.none,
        ),
      ),
      themeMode: _themeMode,
      routerConfig: _router,
      builder: (context, child) {
        // Ensure the entire app respects the system UI safe areas
        // (status bar, notch, bottom navigation / gesture bar).
        // This is the global configuration-level fix — no screen should
        // ever be hidden under the top/bottom system navigation.
        final mediaQuery = MediaQuery.of(context);
        return Theme(
          data: Theme.of(context).copyWith(
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              elevation: 100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: MediaQuery(
            data: mediaQuery,
            child: Overlay(
              key: globalOverlayKey,
              initialEntries: [
                OverlayEntry(
                  builder: (context) {
                    return ScaffoldMessenger(
                      key: globalMessengerKey,
                      child: child!,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Smart entry-point that routes to the correct nav experience based on role.
class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.initialIndex,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final int? initialIndex;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  int _currentIndex = 0;
  String? _adminMoreTabInitialSection;
  Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page;

    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    } else {
      final p = widget.initialPage ?? '';
      if (p == 'AdminDashboard' || p == 'WorkDashboard') {
        _currentIndex = 0;
      } else if (p == 'AdminSchedule' || p == 'SchedulePage') {
        _currentIndex = 1;
      } else if (p == 'ChatPage') {
        _currentIndex = 2;
      } else if (p == 'AdminFinances' || p == 'WalletPage') {
        _currentIndex = 3;
      } else if (p == 'AdminTeam' || p == 'AdminCustomers' || p == 'AdminMap') {
        _currentIndex = 4;
      } else {
        _currentIndex = 0;
      }
    }
  }

  SpeedDial _buildAdminSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 3,
      childPadding: const EdgeInsets.all(5),
      spaceBetweenChildren: 4,
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 8.0,
      animationCurve: Curves.elasticInOut,
      isOpenOnStart: false,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.receipt),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          label: 'Create Invoice',
          onTap: () {
            showCreateInvoiceModal(context, onInvoiceCreated: () {
              // Optionally trigger a refresh if we are on the finance page
              if (_currentIndex == 3) {
                setState(() {
                  _currentPage = custom_widgets.AdminFinancesWidge(
                    key: UniqueKey(),
                    width: double.infinity,
                    height: double.infinity,
                    onLogout: () async {},
                  );
                });
              }
            });
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.person_add),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          label: 'Create Customer',
          onTap: () {
            setState(() {
              _currentIndex = 4;
              _currentPage = custom_widgets.AdminCustomersView(
                key: UniqueKey(),
                width: double.infinity,
                height: double.infinity,
                openCreateCustomerModal: true,
                onLogout: () async {},
              );
            });
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.engineering),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          label: 'Create Worker',
          onTap: () {
            setState(() {
              _currentIndex = 4;
              _currentPage = custom_widgets.AdminTeamWidge(
                key: UniqueKey(),
                width: double.infinity,
                height: double.infinity,
                openCreateWorkerModal: true,
                onLogout: () async {},
                onChatWithWorker: (workerId, workerName) async {},
                onChatTap: (chatId, chatName) async {},
              );
            });
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.work),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          label: 'Create Job',
          onTap: () {
            setState(() {
              _currentIndex = 1;
              _currentPage = custom_widgets.AdminCustomersView(
                key: UniqueKey(),
                width: double.infinity,
                height: double.infinity,
                openCreateJobModal: true,
                onLogout: () async {},
                onJobCreated: () {
                  safeSetState(() {
                    _currentPage = null;
                    _currentIndex = 1;
                  });
                },
              );
            });
          },
        ),
      ],
    );
  }

  void _openEvidenceFlow() async {
    try {
      final jobs = await ApiService.instance.getTodayJobs();
      if (jobs.isEmpty) {
        if (mounted) {
          ToastService.warning(context, 'You have no scheduled jobs today');
        }
        return;
      }
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true,
          builder: (context) => const custom_widgets.CustomEvidenceModal(),
        );
      }
    } catch (e) {
      print("Error opening evidence flow: $e");
    }
  }

  Widget _tabBody() {
    final bool isAdmin = shared.AuthHelpers.isAdmin;
    switch (_currentIndex) {
      case 0:
        return shared.SharedHomeTab(
          onNavigateToFinances: () => safeSetState(() {
            _currentPage = null;
            _currentIndex = 3;
          }),
          onNavigateToTeam: () => safeSetState(() {
            _currentPage = null;
            _adminMoreTabInitialSection = 'team';
            _currentIndex = 4;
          }),
          onNavigateToJobs: () => safeSetState(() {
            _currentPage = null;
            _currentIndex = 1;
          }),
        );
      case 1:
        return shared.SharedJobListPage(showWorkerFilter: isAdmin);
      case 2:
        return custom_widgets.CustomInbox(
            width: double.infinity, height: double.infinity);
      case 3:
        return const shared.SharedWalletTab();
      case 4:
        return isAdmin
            ? shared.AdminMoreTab(initialSection: _adminMoreTabInitialSection)
            : const shared.SharedHomeTab();
      default:
        return const shared.SharedHomeTab();
    }
  }

  Widget _buildUnifiedShell() {
    final bool isAdmin = shared.AuthHelpers.isAdmin;
    return WillPopScope(
      onWillPop: () async {
        if (_currentPage != null) {
          setState(() => _currentPage = null);
          return false;
        }
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
        extendBody: false,
        extendBodyBehindAppBar: false,
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            const shared.SharedCustomHeader(),
            Expanded(
              child: _currentPage ?? _tabBody(),
            ),
          ],
        ),
        floatingActionButton: isAdmin ? _buildAdminSpeedDial() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: shared.UnifiedNavBar(
          currentIndex: _currentIndex,
          isAdmin: isAdmin,
          onTabSelected: (i) => safeSetState(() {
            _currentPage = null;
            if (i == 4) {
              _adminMoreTabInitialSection = null;
            }
            _currentIndex = i;
          }),
          onCameraPressed: isAdmin ? null : _openEvidenceFlow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildUnifiedShell();
  }
}
