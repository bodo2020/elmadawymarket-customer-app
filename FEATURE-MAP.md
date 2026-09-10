# خريطة تحويل تطبيق العملاء

المرجع: `bodo2020/suq-arabi-mobile-market` / `main` / `5caa03569ca48f236f54f57fae5e8121f088e4bb`.

| تدفق React المرجعي | تنفيذ Flutter | الربط |
|---|---|---|
| Index، البانرات والمجموعات | StoreHome، CollectionsSection | banners، product_collections |
| Categories، CategoryDetail، CategoryProducts، SubcategoryDetail | CategoriesPage، CategoryPage، CatalogPage | main_categories، subcategories، branch catalog |
| Search، CompanyProducts، BannerProducts، BulkProducts | CatalogPage، CompaniesPage، openBanner | فلاتر السيرفر ووحدات البيع |
| ProductDetail | ProductPage، ProductDetails | السعر والعرض والجملة والوزن والمخزون والمفضلة |
| BarcodeScanner وaliases | ScannerPage | mobile_scanner + بحث الباركود الفعلي |
| Cart وCartProvider | CartPage، MarketStore | سلة محلية/حساب، حفظ ومزامنة وتسعير السيرفر |
| Payment، OrderSuccess، CheckoutAttemptRecovery | CheckoutPage، ReceiptPage، MarketStore.place/reconcile | نفس quote/place/reconcile RPCs |
| PhoneLogin، PhoneVerify | AuthPage | Supabase Auth SMS OTP وكلمة المرور |
| Register، ForgotPassword، UpdatePassword، ChangePhone | AuthPage، ProfilePage | Supabase Auth مع رابط عودة للهاتف |
| Account، EditAccount | AccountPage، ProfilePage | customers وAuth metadata |
| Address، AddressManager، AddressRegistration | AddressPage، AddressesPage | خريطة وموقع وحفظ وعنوان افتراضي |
| Favorites | FavoritesPage | favorites وset_customer_favorite_unit |
| PurchaseHistory (المسار الفعلي /orders) | OrdersPage | فواتير الفرع والأونلاين عبر get_my_purchase_history |
| OrderTimeline | OrderTimeline | الحالة وتواريخ order_status_history |
| Notifications | NotificationsPage | customer_notifications والقراءة الفردية/الكل |
| Vouchers وبطاقة العضوية | LoyaltyPage | باركود العضوية ونقاط وقسائم وسجل النقاط |
| ReturnRequests، CreateReturnRequest | ReturnsPage، ReturnFormPage | RPC واحد + رفع صور المستخدم |

## اختلافات معروفة عن الويب

- شاشات Flutter أصلية تستخدم Cairo المضمّن والأخضر #005931 وخلفية #f6f8f7 من الويب. تم تعديل البحث والتنقل العائم والأقسام ومجموعات المنتجات والأزرار وشاشة الدخول وصفحة العنوان وفق المصدر. لا يزال التطابق الكامل بكسلًا لكل الشاشات غير مثبت.
- الخريطة المرئية من OpenStreetMap بدل Google JavaScript Maps. تحديد أهلية التوصيل يستخدم نفس `route-distance` الحالي.
- تحديث الطلبات والإشعارات عبر Realtime مع تحديث كل 30 ثانية كمسار احتياطي وتحديث يدوي. لا توجد Push خلفية مضافة.
- الروابط الخارجية للبانرات تُفتح في المتصفح؛ تم ربط روابط المنتجات والأقسام والشركات والبحث والجملة المعروفة داخليًا. أي رابط داخلي مخصص خارجها يحتاج إضافته قبل استخدامه في بانر.
- الأقسام الفرعية تعرض نتائج منتجاتها مباشرة، وصفحة تفاصيل المنتج تعرض المنتجات المشابهة.
- يمكن اختيار القسيمة في الدفع من القائمة أو إدخال الكود والقيمة؛ بطاقة الولاء والقسائم وإنشاؤها موجودة بصفحة العضوية.
- بعض التواريخ/قيم الحالات غير المترجمة تظهر بصيغ السيرفر. اكتمال الاسم مطلوب قبل الدفع، وليس حاجزًا أمام كل التصفح.
- مسارات الويب البديلة وSEO وstructured-data خاصة بواجهة الويب، ولا تدخل في واجهة الهاتف الأصلية.
- لا يدّعي هذا التسليم تكافؤًا مُثبتًا لكل تفصيل أو جاهزية نشر إنتاجي؛ يجب إكمال اختبار حساب حقيقي على أجهزة Android/iOS ومراجعة التفاصيل أعلاه قبل الإطلاق.

## حماية النسخة الحالية

لم يُعدل GitHub، ولم يُستبدل main، ولم تُنشر نسخة Lovable أو Flutter. ملفات المصدر المرجعية قُرئت فقط. لا migrations ولا تغيير RLS ولا Edge Functions ولا تعديل إعدادات Supabase تم تطبيقه.

## الاتجاه البصري الحالي

طلب المستخدم لاحقًا تطوير الشكل ليكون عصريًا وسلسًا؛ النسخة الحالية تطوير بصري لهوية المعداوي وليست محاولة تطابق حرفي مع React.
