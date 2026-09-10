import 'dart:convert';
import 'package:intl/intl.dart';

typedef JsonMap = Map<String, dynamic>;
double number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
JsonMap row(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<JsonMap> rows(dynamic value) =>
    value is List ? value.map(row).toList() : [];
String money(dynamic value) =>
    '${NumberFormat('#,##0.00', 'ar_EG').format(number(value))} ج.م';
String phoneNumber(String input) {
  var s = input.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('0')) s = '+20${s.substring(1)}';
  return s.startsWith('+') ? s : '+$s';
}

class Product {
  final JsonMap data;
  Product(this.data);
  String get id => '${data['id']}';
  String get name => '${data['name'] ?? ''}';
  bool get weighted =>
      data['barcode_type'] == 'scale' ||
      {
        'weight',
        'kg',
        'kgs',
        'kilogram',
        'kilograms',
        'كيلو',
        'كيلو جرام',
        'كيلوجرام',
        'كجم',
        'كغ',
      }.contains('${data['unit_of_measure']}'.trim().toLowerCase());
  bool get bulk =>
      !weighted &&
      data['bulk_enabled'] == true &&
      number(data['bulk_quantity']) > 0 &&
      number(data['bulk_price']) >= 0;
  int get step =>
      (number(data['default_weight_grams']) > 0
              ? number(data['default_weight_grams']).round()
              : 250)
          .clamp(1, 100000);
  double get price {
    final p = number(data['price']), o = number(data['offer_price']);
    return o > 0 && o < p ? o : p;
  }

  double unitPrice(bool bulk) => bulk ? number(data['bulk_price']) : price;
  String title(bool bulk) =>
      bulk && '${data['bulk_name'] ?? ''}'.trim().isNotEmpty
      ? '${data['bulk_name']}'
      : name;
  String picture(bool bulk) {
    if (bulk && '${data['bulk_image_url'] ?? ''}'.isNotEmpty) {
      return '${data['bulk_image_url']}';
    }
    final images = data['image_urls'];
    return images is List && images.isNotEmpty ? '${images.first}' : '';
  }

  int maxQuantity(bool bulk) => weighted
      ? (number(data['quantity']) * 1000).floor()
      : (number(data['quantity']) / (bulk ? number(data['bulk_quantity']) : 1))
            .floor();
}

class CartLine {
  final Product product;
  final int quantity;
  final bool bulk;
  CartLine(this.product, this.quantity, {this.bulk = false});
  String get key => '${product.id}:$bulk:${product.weighted}';
  double get total =>
      product.unitPrice(bulk) * quantity / (product.weighted ? 1000 : 1);
  String get amount =>
      product.weighted ? '$quantity جم' : '$quantity ${bulk ? 'عبوة' : 'قطعة'}';
  JsonMap checkout() => {
    'product_id': product.id,
    'quantity': quantity,
    'is_bulk': bulk,
    'unit_of_measure': product.weighted ? 'weight' : 'piece',
  };
  JsonMap persistence() => {
    'product_id': product.id,
    'quantity': quantity,
    'metadata': {
      'is_bulk': bulk,
      'unit_of_measure': product.weighted ? 'weight' : 'piece',
    },
  };
  JsonMap toJson() => {
    'product': product.data,
    'quantity': quantity,
    'bulk': bulk,
  };
  factory CartLine.fromJson(JsonMap value) {
    final q = number(value['quantity']);
    if (q <= 0 || q != q.round() || row(value['product'])['id'] == null) {
      throw const FormatException('INVALID_CART');
    }
    return CartLine(
      Product(row(value['product'])),
      q.toInt(),
      bulk: value['bulk'] == true,
    );
  }
}

List<JsonMap> checkoutLines(List<CartLine> cart) {
  final result = cart.map((e) => e.checkout()).toList();
  result.sort(
    (a, b) => '${a['product_id']}:${a['is_bulk']}'.compareTo(
      '${b['product_id']}:${b['is_bulk']}',
    ),
  );
  return result;
}

List<CartLine> decodeCart(String? value) => value == null
    ? []
    : rows(jsonDecode(value)).map(CartLine.fromJson).toList();
const statusLabels = {
  'pending': 'تم استلام الطلب',
  'confirmed': 'تم تأكيد الطلب',
  'preparing': 'جاري التجهيز',
  'ready': 'الطلب جاهز',
  'shipped': 'في الطريق إليك',
  'delivered': 'تم التسليم',
  'cancelled': 'تم الإلغاء',
  'store_completed': 'شراء من الفرع',
  'approved': 'مقبول',
  'rejected': 'مرفوض',
  'paid': 'مدفوع',
  'failed': 'فشل الدفع',
  'refunded': 'تم رد المبلغ',
};
String friendlyError(Object error) {
  final text = error.toString();
  const messages = {
    'PENDING_CHECKOUT': 'كمّل محاولة الطلب المحفوظة قبل تعديل السلة',
    'AUTH_REQUIRED': 'سجّل دخولك الأول',
    'PROFILE_REQUIRED': 'كمّل بيانات حسابك',
    'ADDRESS_REQUIRED': 'اختار عنوان توصيل محفوظ',
    'DELIVERY_UNAVAILABLE': 'العنوان خارج نطاق التوصيل',
    'ROUTE_DISTANCE_UNAVAILABLE': 'تعذر حساب طريق التوصيل. حاول تاني',
    'INSUFFICIENT_STOCK': 'الكمية المطلوبة مش متاحة. راجع السلة',
    'QUOTE_CHANGED': 'السعر أو العنوان اتغير. راجع الملخص وأكّد تاني',
    'CHECKOUT_NOT_READY': 'تأكيد الطلبات غير متاح حاليًا',
    'PRODUCT_UNAVAILABLE': 'منتج في السلة لم يعد متاحًا',
    'VOUCHER_UNAVAILABLE': 'القسيمة غير متاحة',
    'Invalid login credentials': 'بيانات الدخول غير صحيحة',
    'SocketException': 'راجع اتصال الإنترنت وحاول تاني',
  };
  for (final entry in messages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return 'تعذر إتمام العملية. حاول تاني.';
}

String displayDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '—';
  return DateFormat('d/M/y • HH:mm', 'ar_EG').format(date.toLocal());
}
