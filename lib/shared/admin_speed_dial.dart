import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../components/create_invoice_modal.dart';
import '../custom_code/widgets/index.dart' as custom_widgets;
import '../tasks/tasks_list_screen.dart';
import 'create_quote_screen.dart';
import '../main.dart';

/// Reusable Admin SpeedDial floating action button with all global creation capabilities.
class AdminSpeedDial extends StatelessWidget {
  final VoidCallback? onTaskCreated;
  final VoidCallback? onJobCreated;
  final VoidCallback? onCustomerCreated;
  final VoidCallback? onWorkerCreated;
  final VoidCallback? onInvoiceCreated;

  /// Optional in-shell navigation callback when hosted directly inside NavBarPage.
  final void Function(Widget page, int tabIndex)? onNavigateInShell;

  const AdminSpeedDial({
    Key? key,
    this.onTaskCreated,
    this.onJobCreated,
    this.onCustomerCreated,
    this.onWorkerCreated,
    this.onInvoiceCreated,
    this.onNavigateInShell,
  }) : super(key: key);

  void _handleCreateInvoice(BuildContext context) {
    showCreateInvoiceModal(context, onInvoiceCreated: () {
      onInvoiceCreated?.call();
    });
  }

  void _handleCreateCustomer(BuildContext context) {
    if (onNavigateInShell != null) {
      onNavigateInShell!(
        custom_widgets.AdminCustomersView(
          key: UniqueKey(),
          width: double.infinity,
          height: double.infinity,
          openCreateCustomerModal: true,
          onLogout: () async {},
        ),
        4,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => NavBarPage(
            initialIndex: 4,
            page: custom_widgets.AdminCustomersView(
              key: UniqueKey(),
              width: double.infinity,
              height: double.infinity,
              openCreateCustomerModal: true,
              onLogout: () async {},
            ),
          ),
        ),
        (r) => false,
      );
    }
  }

  void _handleCreateWorker(BuildContext context) {
    if (onNavigateInShell != null) {
      onNavigateInShell!(
        custom_widgets.AdminTeamWidge(
          key: UniqueKey(),
          width: double.infinity,
          height: double.infinity,
          openCreateWorkerModal: true,
          onLogout: () async {},
          onChatWithWorker: (workerId, workerName) async {},
          onChatTap: (chatId, chatName) async {},
        ),
        4,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => NavBarPage(
            initialIndex: 4,
            page: custom_widgets.AdminTeamWidge(
              key: UniqueKey(),
              width: double.infinity,
              height: double.infinity,
              openCreateWorkerModal: true,
              onLogout: () async {},
              onChatWithWorker: (workerId, workerName) async {},
              onChatTap: (chatId, chatName) async {},
            ),
          ),
        ),
        (r) => false,
      );
    }
  }

  void _handleCreateJob(BuildContext context) {
    if (onNavigateInShell != null) {
      onNavigateInShell!(
        custom_widgets.AdminCustomersView(
          key: UniqueKey(),
          width: double.infinity,
          height: double.infinity,
          openCreateJobModal: true,
          onLogout: () async {},
          onJobCreated: () {
            onJobCreated?.call();
          },
        ),
        1,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => NavBarPage(
            initialIndex: 1,
            page: custom_widgets.AdminCustomersView(
              key: UniqueKey(),
              width: double.infinity,
              height: double.infinity,
              openCreateJobModal: true,
              onLogout: () async {},
              onJobCreated: () {
                onJobCreated?.call();
              },
            ),
          ),
        ),
        (r) => false,
      );
    }
  }

  void _handleCreateTask(BuildContext context) {
    CreateTaskBottomSheet.show(context, onTaskCreated: onTaskCreated);
  }

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 3,
      childPadding: const EdgeInsets.all(5),
      spaceBetweenChildren: 4,
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 8.0,
      animationCurve: Curves.elasticInOut,
      isOpenOnStart: false,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.request_quote_rounded),
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          label: 'Create Estimate',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateQuoteScreen()),
          ),
        ),
        SpeedDialChild(
          child: const Icon(Icons.receipt),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          label: 'Create Invoice',
          onTap: () => _handleCreateInvoice(context),
        ),
        SpeedDialChild(
          child: const Icon(Icons.person_add),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          label: 'Create Customer',
          onTap: () => _handleCreateCustomer(context),
        ),
        SpeedDialChild(
          child: const Icon(Icons.engineering),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          label: 'Create Worker',
          onTap: () => _handleCreateWorker(context),
        ),
        SpeedDialChild(
          child: const Icon(Icons.work),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          label: 'Create Job',
          onTap: () => _handleCreateJob(context),
        ),
        SpeedDialChild(
          child: const Icon(Icons.check_box_outlined),
          backgroundColor: const Color(0xFFEC4899),
          foregroundColor: Colors.white,
          label: 'Create Task',
          onTap: () => _handleCreateTask(context),
        ),
      ],
    );
  }
}
