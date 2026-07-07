import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'wallet_page_model.dart';
export 'wallet_page_model.dart';

class WalletPageWidget extends StatefulWidget {
  const WalletPageWidget({super.key});

  static String routeName = 'WalletPage';
  static String routePath = '/walletPage';

  @override
  State<WalletPageWidget> createState() => _WalletPageWidgetState();
}

class _WalletPageWidgetState extends State<WalletPageWidget> {
  late WalletPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WalletPageModel());

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
              child: custom_widgets.CustomWallet(
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
                  currentIndex: 2,
                  onHome: () async {
                    context.pushNamed(WorkDashboardWidget.routeName);
                  },
                  onSchedule: () async {
                    context.pushNamed(SchedulePageWidget.routeName);
                  },
                  onWallet: () async {},
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
