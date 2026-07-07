import '../../auth/laravel_auth_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_schedule_model.dart';
export 'admin_schedule_model.dart';

class AdminScheduleWidget extends StatefulWidget {
  const AdminScheduleWidget({super.key});

  static String routeName = 'AdminSchedule';
  static String routePath = '/adminSchedule';

  @override
  State<AdminScheduleWidget> createState() => _AdminScheduleWidgetState();
}

class _AdminScheduleWidgetState extends State<AdminScheduleWidget> {
  late AdminScheduleModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminScheduleModel());

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
          child: custom_widgets.AdminScheduleWidge(
            width: double.infinity,
            height: double.infinity,
            onLogout: () async {
              GoRouter.of(context).prepareAuthEvent();
              await LaravelAuthManager.signOut();
              GoRouter.of(context).clearRedirectLocation();

              context.pushNamedAuth(SignInWidget.routeName, context.mounted);
            },
          ),
        ),
      ),
    );
  }
}
