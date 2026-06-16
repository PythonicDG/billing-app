class ApiConstants {
  static const String baseUrl = 'https://api.vighnahartafataka.chickenkiller.com'; // Production URL (HTTPS)
  static const String loginUrl = '/api/login/';
  static const String changePasswordUrl = '/api/change-password/';
  static const String productsUrl = '/api/products/';
  static const String frequentProductsUrl = '/api/products/frequent/';
  static const String staffListUrl = '/api/staff/list/';
  static const String staffCreateUrl = '/api/staff/create/';
  static const String invoicesUrl = '/api/billing/invoices/';
  static const String invoicePreviewUrl = '/api/billing/invoices/preview/';
  static const String customersUrl = '/api/customers/';
  static String customerLedgerUrl(String id) => '/api/customers/$id/ledger/';
  static String customerBulkPaymentUrl(String id) => '/api/customers/$id/record_bulk_payment/';
  static String customerDownloadStatementUrl(String id) => '/api/customers/$id/download_statement/';

  // Dashboard
  static const String dashboardSummaryUrl = '/api/dashboard/summary/';

  // Dashboard PIN
  static const String dashboardPinStatusUrl = '/api/core/dashboard-pin/status/';
  static const String dashboardPinSetUrl = '/api/core/dashboard-pin/set_pin/';
  static const String dashboardPinVerifyUrl = '/api/core/dashboard-pin/verify/';
  static const String dashboardPinRevokeUrl = '/api/core/dashboard-pin/revoke/';
  static const String dashboardPinRemoveUrl = '/api/core/dashboard-pin/remove_pin/';

  static String invoiceDetailUrl(String id) => '/api/billing/invoices/$id/';
  static String invoiceDownloadPdfUrl(String id) => '/api/billing/invoices/$id/download_pdf/';
  static String invoicePrintHtmlUrl(String id) => '/api/billing/invoices/$id/print_html/';
  static String invoiceThermalReceiptUrl(String id) => '/api/billing/invoices/$id/thermal_receipt_pdf/';
  static String deactivateStaffUrl(int userId) => '/api/staff/$userId/deactivate/';
  static String productDetailUrl(String uuid) => '/api/products/$uuid/';
}
