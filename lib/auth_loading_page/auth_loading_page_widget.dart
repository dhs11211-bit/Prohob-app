import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auth_loading_page_model.dart';
export 'auth_loading_page_model.dart';

class AuthLoadingPageWidget extends StatefulWidget {
  const AuthLoadingPageWidget({super.key});

  static String routeName = 'AuthLoadingPage';
  static String routePath = '/authLoadingPage';

  @override
  State<AuthLoadingPageWidget> createState() => _AuthLoadingPageWidgetState();
}

class _AuthLoadingPageWidgetState extends State<AuthLoadingPageWidget> {
  late AuthLoadingPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuthLoadingPageModel());

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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: custom_widgets.AuthRouterWidge(
            width: double.infinity,
            height: double.infinity,
            onAdminRoute: () async {
              context.pushNamed('AdminDashboard');
            },
            onWorkerRoute: () async {
              context.pushNamed('WorkDashboard');
            },
          ),
        ),
      ),
    );
  }
}
