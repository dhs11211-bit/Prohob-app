import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_customers_model.dart';
export 'admin_customers_model.dart';

class AdminCustomersWidget extends StatefulWidget {
  const AdminCustomersWidget({
    super.key,
    this.openCreateJobModal = false,
    this.openCreateCustomerModal = false,
  });

  static String routeName = 'AdminCustomers';
  static String routePath = '/adminCustomers';
  final bool openCreateJobModal;
  final bool openCreateCustomerModal;

  @override
  State<AdminCustomersWidget> createState() => _AdminCustomersWidgetState();
}

class _AdminCustomersWidgetState extends State<AdminCustomersWidget> {
  late AdminCustomersModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminCustomersModel());

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
          child: custom_widgets.AdminCustomersView(
            width: double.infinity,
            height: double.infinity,
            openCreateJobModal: widget.openCreateJobModal,
            openCreateCustomerModal: widget.openCreateCustomerModal,
            onLogout: () async {
              context.pushNamed(SignInWidget.routeName);
            },
          ),
        ),
      ),
    );
  }
}
