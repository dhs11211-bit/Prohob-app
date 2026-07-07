import '../../auth/laravel_auth_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_map_model.dart';
export 'admin_map_model.dart';

class AdminMapWidget extends StatefulWidget {
  const AdminMapWidget({super.key});

  static String routeName = 'AdminMap';
  static String routePath = '/adminMap';

  @override
  State<AdminMapWidget> createState() => _AdminMapWidgetState();
}

class _AdminMapWidgetState extends State<AdminMapWidget> {
  late AdminMapModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminMapModel());

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
          child: custom_widgets.AdminMapWidge(
            width: double.infinity,
            height: double.infinity,
            onLogout: () async {
              context.pushNamedAuth(SignInWidget.routeName, context.mounted);

              GoRouter.of(context).prepareAuthEvent();
              await LaravelAuthManager.signOut();
              GoRouter.of(context).clearRedirectLocation();
            },
          ),
        ),
      ),
    );
  }
}
