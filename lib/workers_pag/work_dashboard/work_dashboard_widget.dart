import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'work_dashboard_model.dart';
export 'work_dashboard_model.dart';

class WorkDashboardWidget extends StatefulWidget {
  const WorkDashboardWidget({super.key});

  static String routeName = 'WorkDashboard';
  static String routePath = '/workDashboard';

  @override
  State<WorkDashboardWidget> createState() => _WorkDashboardWidgetState();
}

class _WorkDashboardWidgetState extends State<WorkDashboardWidget> {
  late WorkDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WorkDashboardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFF0F172A),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: MediaQuery.sizeOf(context).height * 1.0,
                child: custom_widgets.ClockInTracker(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                ),
              ),
              Align(
                alignment: AlignmentDirectional(0.0, -1.0),
                child: Container(
                  width: double.infinity,
                  height: 150.0,
                  child: custom_widgets.CustomHeader(
                    width: double.infinity,
                    height: 150.0,
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional(0.0, 1.0),
                child: Container(
                  width: double.infinity,
                  height: 90.0,
                  child: custom_widgets.CustomNavBar(
                    width: double.infinity,
                    height: 90.0,
                    currentIndex: 0,
                    onHome: () async {},
                    onSchedule: () async {
                      context.pushNamed(SchedulePageWidget.routeName);
                    },
                    onWallet: () async {
                      context.pushNamed(WalletPageWidget.routeName);
                    },
                    onInbox: () async {
                      context.pushNamed(ChatPageWidget.routeName);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
