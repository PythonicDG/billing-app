import 'package:billing_app/billing_provider.dart';
import 'package:billing_app/product_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billing_app/auth_provider.dart';
import 'package:billing_app/settings_provider.dart';
import 'package:billing_app/screens/billing_screen.dart';

class TestProducts extends ProductProvider {
  final Product testProduct;
  TestProducts(this.testProduct);
  @override
  List<Product> get billingProducts => [testProduct];
  @override
  Future<void> fetchProductsForBilling({String? search, int pageSize = 100}) async {}
  @override
  Future<void> fetchCategories() async {}
}

class TestSettings extends SettingsProvider {
  @override
  Future<void> fetchRemoteSettings() async {}
}

Product product({String mode = 'cent', double cents = 2.3, int stock = 69}) =>
    Product.fromJson({
      'id': 'case-product', 'name': 'Test', 'brand': 'Test',
      'selling_price': '100.50', 'entry_mode': mode,
      'stock_quantity': stock, 'cent_in_per_cs': cents, 'no_of_case': 3,
      'total_stock_in_cent': stock / 10,
    });

void main() {
  testWidgets('billing Case toggle sets case quantity and can switch to cent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = BillingProvider();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<BillingProvider>.value(value: provider),
      ChangeNotifierProvider<ProductProvider>(create: (_) => TestProducts(product())),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<SettingsProvider>(create: (_) => TestSettings()),
    ], child: const MaterialApp(home: BillingScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Case'));
    await tester.pumpAndSettle();
    expect(find.text('3 cases left'), findsOneWidget);
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(provider.cart.single.unit, 'CASE');
    expect(provider.cart.single.quantity, 1);
    expect(provider.cart.single.unitPrice, 231.15);
    await tester.tap(find.text('Cent (10x)'));
    await tester.pumpAndSettle();
    expect(provider.cart.single.unit, 'CENT');
    expect(provider.cart.single.unitPrice, 100.50);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('case rate uses inventory cents per case for either pricing mode', () {
    expect(product().piecesPerCase, 23);
    expect(product().priceForUnit('CASE'), 231.15);
    expect(product(mode: 'piece').priceForUnit('CASE'), 2311.50);
    expect(product().priceForUnit('CENT'), 100.50);
    expect(product().priceForUnit('PIECE'), 10.05);
  });

  test('case quantity increments, limits stock, and serializes cases', () {
    final provider = BillingProvider();
    final p = product();
    provider.addToCart(p, unit: 'CASE');
    provider.addToCart(p);
    provider.updateQuantity(p.uuid, 3, p.stockQuantity);
    provider.addToCart(p);
    provider.updateQuantity(p.uuid, 4, p.stockQuantity);
    expect(provider.cart.single.quantity, 3);
    expect(provider.subTotal, 693.45);
    expect(provider.cart.single.toJson(), {
      'product': p.uuid, 'quantity': 3, 'unit_price': 231.15, 'unit': 'CASE',
    });
    provider.updateQuantity(p.uuid, 0, p.stockQuantity);
    expect(provider.cart, isEmpty);
  });

  test('selected unit is applied directly and same-unit clicks keep custom rate', () {
    final provider = BillingProvider();
    final p = product();
    provider.addToCart(p, unit: 'PIECE');
    expect(provider.setUnit(p.uuid, 'CASE'), isTrue);
    expect(provider.cart.single.unitPrice, 231.15);
    provider.updateUnitPrice(p.uuid, 220);
    expect(provider.setUnit(p.uuid, 'CASE'), isTrue);
    expect(provider.cart.single.unitPrice, 220);
    expect(provider.setUnit(p.uuid, 'CENT'), isTrue);
    expect(provider.cart.single.unit, 'CENT');
    provider.updateQuantity(p.uuid, 4, p.stockQuantity);
    expect(provider.setUnit(p.uuid, 'CASE'), isFalse);
    expect(provider.cart.single.unit, 'CENT');
  });

  test('missing, fractional-piece, and insufficient case sizes cannot be added', () {
    for (final p in [product(cents: 0), product(cents: 2.35), product(stock: 22)]) {
      final provider = BillingProvider();
      provider.addToCart(p, unit: 'CASE');
      expect(provider.cart, isEmpty);
    }
  });

  test('case invoices reload quantities, rates and units', () {
    final provider = BillingProvider();
    final p = product();
    provider.loadInvoiceIntoCart({
      'id': 'invoice', 'items': [
        {'product': p.uuid, 'quantity': 2, 'unit_price': '231.15', 'unit': 'CASE'},
      ],
    }, [p]);
    expect(provider.cart.single.unit, 'CASE');
    expect(provider.cart.single.quantity, 2);
    expect(provider.subTotal, 462.30);
  });

  test('editing a sold-out case invoice credits its original stock', () {
    final provider = BillingProvider();
    final p = product(stock: 0);
    provider.loadInvoiceIntoCart({
      'id': 'invoice', 'items': [
        {'product': p.uuid, 'quantity': 2, 'unit_price': '231.15',
         'unit': 'CASE', 'pieces_per_case': 23},
      ],
    }, [p]);
    expect(provider.availableStock(p), 46);
    provider.updateQuantity(p.uuid, 1, p.stockQuantity);
    expect(provider.cart.single.quantity, 1);
    expect(provider.setUnit(p.uuid, 'CENT'), isTrue);
    provider.removeFromCart(p.uuid);
    provider.addToCart(p, unit: 'CASE');
    expect(provider.cart.single.unit, 'CASE');
    provider.clearCart();
    expect(provider.availableStock(p), 0);
  });
}
