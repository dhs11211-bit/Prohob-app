import '../../auth/laravel_auth_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_team_model.dart';
export 'admin_team_model.dart';

class AdminTeamWidget extends StatefulWidget {
  const AdminTeamWidget({
    super.key,
    this.openCreateWorkerModal = false,
  });

  static String routeName = 'AdminTeam';
  static String routePath = '/adminTeam';
  final bool openCreateWorkerModal;

  @override
  State<AdminTeamWidget> createState() => _AdminTeamWidgetState();
}

class _AdminTeamWidgetState extends State<AdminTeamWidget> {
  late AdminTeamModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminTeamModel());

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
          child: custom_widgets.AdminTeamWidge(
            width: double.infinity,
            height: double.infinity,
            openCreateWorkerModal: widget.openCreateWorkerModal,
            onLogout: () async {
              GoRouter.of(context).prepareAuthEvent();
              await LaravelAuthManager.signOut();
              GoRouter.of(context).clearRedirectLocation();

              context.pushNamedAuth(SignInWidget.routeName, context.mounted);
            },
            onChatWithWorker: (workerId, workerName) async {},
            onChatTap: (chatId, chatName) async {},
          ),
        ),
      ),
    );
  }
}
