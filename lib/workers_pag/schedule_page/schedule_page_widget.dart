import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'schedule_page_model.dart';
export 'schedule_page_model.dart';

class SchedulePageWidget extends StatefulWidget {
  const SchedulePageWidget({super.key});

  static String routeName = 'SchedulePage';
  static String routePath = '/schedulePage';

  @override
  State<SchedulePageWidget> createState() => _SchedulePageWidgetState();
}

class _SchedulePageWidgetState extends State<SchedulePageWidget> {
  late SchedulePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SchedulePageModel());

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
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              child: custom_widgets.CustomSchedule(
                width: double.infinity,
                height: double.infinity,
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
                  currentIndex: 1,
                  onHome: () async {
                    context.goNamed(WorkDashboardWidget.routeName);
                  },
                  onSchedule: () async {},
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
    );
  }
}
