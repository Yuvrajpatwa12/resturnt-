import 'package:flutter/material.dart';
import 'purchase_report_screen.dart';
import 'reports/stock_food_report_screen.dart';
import 'reports/stock_kitchen_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/items_sales_report_screen.dart';
import 'reports/waiters_sales_report_screen.dart';
import 'reports/delivery_sales_report_screen.dart';
import 'reports/order_source_report_screen.dart';
import 'reports/cash_register_report_screen.dart';
import 'reports/sale_by_table_report_screen.dart';

class ReportManagementScreen extends StatelessWidget {
  final String mode;
  const ReportManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case "Purchase Report":
        return const PurchaseReportScreen();
      case "Stock Report (Food Items)":
        return const StockFoodReportScreen();
      case "Stock Report (Kitchen)":
        return const StockKitchenReportScreen();
      case "Sales Report":
        return const SalesReportScreen();
      case "Items Sales Report":
        return const ItemsSalesReportScreen();
      case "Waiters Sales Report":
        return const WaitersSalesReportScreen();
      case "Delivery Type Sales Report":
        return const DeliverySalesReportScreen();
      case "Order Source Report":
        return const OrderSourceReportScreen();
      case "Cash Register Report":
        return const CashRegisterReportScreen();
      case "Sale By Table":
        return const SaleByTableReportScreen();
      default:
        return const SalesReportScreen();
    }
  }
}
