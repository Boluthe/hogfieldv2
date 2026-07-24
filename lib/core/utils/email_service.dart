import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../data/hive_database.dart';
import '../../features/billing/data/models/order_model.dart';
import 'package:intl/intl.dart';

class EmailService {
  static Future<bool> sendEodReport(List<OrderModel> orders) async {
    final box = HiveDatabase.settingsBox;
    final host = box.get('smtp_host', defaultValue: '');
    final portStr = box.get('smtp_port', defaultValue: '587');
    final user = box.get('smtp_user', defaultValue: '');
    final pass = box.get('smtp_pass', defaultValue: '');
    final target = box.get('smtp_target', defaultValue: '');

    if (host.isEmpty || user.isEmpty || pass.isEmpty || target.isEmpty) {
      return false; // Not configured
    }

    final port = int.tryParse(portStr) ?? 587;

    final smtpServer = SmtpServer(host, port: port, username: user, password: pass, allowInsecure: port != 465);

    double totalRevenue = 0;
    int totalItems = 0;
    for (var o in orders) {
      totalRevenue += o.total;
      for (var i in o.items) {
        totalItems += i.quantity;
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final message = Message()
      ..from = Address(user, 'Billing App Report')
      ..recipients.add(target)
      ..subject = 'End of Day Report - $dateStr'
      ..html = '''
      <h2>End of Day Report</h2>
      <p><b>Date:</b> $dateStr</p>
      <p><b>Total Revenue:</b> ₦${totalRevenue.toStringAsFixed(2)}</p>
      <p><b>Total Orders:</b> ${orders.length}</p>
      <p><b>Total Items Sold:</b> $totalItems</p>
      <br/>
      <h3>Order Breakdown:</h3>
      <ul>
        ${orders.map((o) => '<li>Order ${o.id.substring(0, 6)} - ₦${o.total.toStringAsFixed(2)} (${o.items.length} items) - ${DateFormat('hh:mm a').format(o.date)}</li>').join('\n')}
      </ul>
      ''';

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('SMTP Error: $e');
      return false;
    }
  }
}
