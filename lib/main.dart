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
import 'package:flutter_speed_dial/flutter_speed_dial.dart';


import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();


  await LaravelAuthManager.initialize();
  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

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
      scaffoldMessengerKey: globalMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Workers',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

/// This is the private State class that goes with NavBarPage.
class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'AdminDashboard';
  late Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  SpeedDial _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 3,
      childPadding: const EdgeInsets.all(5),
      spaceBetweenChildren: 4,
      backgroundColor: const Color(0xFF3B82F6), // Primary color
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
            setState(() {
              _currentPageName = 'AdminFinances';
              _currentPage = AdminFinancesWidget(key: UniqueKey());
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
              _currentPageName = 'AdminCustomers';
              _currentPage = AdminCustomersWidget(key: UniqueKey(), openCreateCustomerModal: true);
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
              _currentPageName = 'AdminTeam';
              _currentPage = AdminTeamWidget(key: UniqueKey(), openCreateWorkerModal: true);
            });
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.task_alt),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          label: 'Create Task',
          onTap: () {
            setState(() {
              _currentPageName = 'AdminSchedule';
              _currentPage = AdminScheduleWidget(key: UniqueKey());
            });
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.work),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          label: 'Create Job',
          onTap: () {
            // Switch to AdminCustomers tab and open modal
            setState(() {
              _currentPageName = 'AdminCustomers';
              _currentPage = AdminCustomersWidget(key: UniqueKey(), openCreateJobModal: true);
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'AdminDashboard': AdminDashboardWidget(),
      'AdminSchedule': AdminScheduleWidget(),
      'AdminTeam': AdminTeamWidget(),
      'AdminCustomers': AdminCustomersWidget(),
      'AdminFinances': AdminFinancesWidget(),
      'AdminMap': AdminMapWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return WillPopScope(
      onWillPop: () async {
        if (_currentPageName != 'AdminDashboard') {
          setState(() {
            _currentPageName = 'AdminDashboard';
            _currentPage = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
        body: _currentPage ?? tabs[_currentPageName],
      floatingActionButton: _buildSpeedDial(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => safeSetState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
        }),
        backgroundColor: Color(0xFF1E293B),
        selectedItemColor: Color(0xFF3B82F6),
        unselectedItemColor: Color(0xFF94A3B8),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.dashboard,
              size: 24.0,
            ),
            label: 'Home',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_today,
              size: 24.0,
            ),
            label: 'Schedule',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.people_outlined,
              size: 24.0,
            ),
            label: 'Team',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.contacts_outlined,
              size: 24.0,
            ),
            label: 'Customers',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.monetization_on_outlined,
              size: 24.0,
            ),
            label: 'Finances',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.map_outlined,
              size: 24.0,
            ),
            label: 'Map',
            tooltip: '',
          )
        ],
      ),
    ), // Scaffold
    ); // WillPopScope
  }
}
