import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'landing_pricing_first_model.dart';
export 'landing_pricing_first_model.dart';

class LandingPricingFirstWidget extends StatefulWidget {
  const LandingPricingFirstWidget({super.key});

  static String routeName = 'LandingPricingFirst';
  static String routePath = '/landingPricingFirst';

  @override
  State<LandingPricingFirstWidget> createState() =>
      _LandingPricingFirstWidgetState();
}

class _LandingPricingFirstWidgetState extends State<LandingPricingFirstWidget> {
  late LandingPricingFirstModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LandingPricingFirstModel());

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
          child: custom_widgets.LandingPricingWidget(
            width: double.infinity,
            height: double.infinity,
            onSignInTap: () async {
              context.pushNamed(SignInWidget.routeName);
            },
            onSelectPlan: (planName) async {},
          ),
        ),
      ),
    );
  }
}
