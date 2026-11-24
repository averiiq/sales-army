import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';

void main() {
  test('city / state / pincode survive toMap -> fromMap and copyWith', () {
    final shop = ShopModel(
      shopId: 's1',
      shopName: 'Walk-in Counter',
      ownerName: 'Guest',
      sellerCategory: 'Walk-in Customer',
      address: 'Shop 4, Market Road',
      city: 'Pune',
      state: 'Maharashtra',
      pincode: '411001',
    );
    final back = ShopModel.fromMap(shop.toMap(), 's1');
    expect(back.city, 'Pune');
    expect(back.state, 'Maharashtra');
    expect(back.pincode, '411001');
    expect(back.sellerCategory, 'Customer'); // legacy value is renamed
    expect(back.copyWith(city: 'Mumbai').city, 'Mumbai');

    // Supabase rows use snake_case / numeric pincode.
    final row = ShopModel.fromMap({'shop_name': 'X', 'pincode': 560001}, 's2');
    expect(row.pincode, '560001');
  });

  test('fullAddress joins only the parts that are present', () {
    ShopModel s({String? a, String? c, String? st, String? p}) =>
        ShopModel(shopId: 'x', shopName: 'x', ownerName: 'x', address: a, city: c, state: st, pincode: p);

    expect(s(a: 'Market Rd', c: 'Pune', st: 'MH', p: '411001').fullAddress, 'Market Rd, Pune, MH - 411001');
    expect(s(a: 'Market Rd').fullAddress, 'Market Rd');
    expect(s(c: 'Pune', p: '411001').fullAddress, 'Pune - 411001');
    expect(s().fullAddress, '');
  });
}
