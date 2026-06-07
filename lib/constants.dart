class ApiConstants {
  static const String baseUrl = 'https://api.vighnahartafataka.chickenkiller.com'; // Production URL
  static const String loginUrl = '/api/login/';
  static const String productsUrl = '/api/products/';
  static const String staffListUrl = '/api/staff/list/';
  static const String staffCreateUrl = '/api/staff/create/';
  static const String invoicesUrl = '/api/billing/invoices/';
  static const String invoicePreviewUrl = '/api/billing/invoices/preview/';
  static const String customersUrl = '/api/customers/';

  static String invoiceDetailUrl(String id) => '/api/billing/invoices/$id/';
  static String invoiceDownloadPdfUrl(String id) => '/api/billing/invoices/$id/download_pdf/';
  static String invoicePrintHtmlUrl(String id) => '/api/billing/invoices/$id/print_html/';
  static String invoiceThermalReceiptUrl(String id) => '/api/billing/invoices/$id/thermal_receipt_pdf/';
  static String deactivateStaffUrl(int userId) => '/api/staff/$userId/deactivate/';
  static String productDetailUrl(String uuid) => '/api/products/$uuid/';
}
