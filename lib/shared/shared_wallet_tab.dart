import 'package:flutter/material.dart';
import 'auth_helpers.dart';
import '../custom_code/widgets/index.dart' as custom_widgets;

class SharedWalletTab extends StatelessWidget {
  const SharedWalletTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (AuthHelpers.isAdmin) {
      return custom_widgets.AdminFinancesWidge(
        width: double.infinity,
        height: double.infinity,
        onLogout: () async {},
      );
    } else {
      return custom_widgets.CustomWallet(
        width: double.infinity,
        height: double.infinity,
      );
    }
  }
}
