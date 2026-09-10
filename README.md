# المعداوي ماركت — Flutter

تطبيق Flutter/Dart أصلي للعملاء، منفصل عن نسخة React. لا يستخدم WebView. مبني على المستودع `bodo2020/suq-arabi-mobile-market`، فرع `main` عند commit `5caa03569ca48f236f54f57fae5e8121f088e4bb` بتاريخ 9 سبتمبر 2026.

## التشغيل

تمت تجربة Flutter 3.32.8 وDart 3.8.1. الحزم مثبتة بإصدارات محددة ومعها `pubspec.lock`. إعداد Android يحدد NDK `29.0.13846066`؛ ثبته من SDK Manager إذا لم يكن موجودًا.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=config.json
flutter build apk --debug --dart-define-from-file=config.json
flutter build appbundle --release --dart-define-from-file=config.json
```

انسخ `config.example.json` إلى `config.json` ثم ضع عنوان مشروع Supabase ومفتاح `anon` العام. ملف `config.json` مستبعد من Git حتى تبقى إعدادات كل بيئة محلية. لا تضف `service_role` أو أي مفتاح سري إلى تطبيق العميل.

نسخة الويب الناتجة من Flutter للمعاينة والاختبار؛ Android وiOS يستخدمان شاشات Flutter الأصلية نفسها والكاميرا والموقع عبر plugins.

## التنظيم

- `lib/core/models.dart`: المنتجات، الكميات، الوزن بالجرام، العبوات والتنسيق.
- `lib/core/store.dart`: Supabase، تحديد فرع التوصيل، حفظ السلة ومزامنتها ومحاولات الطلب.
- `lib/screens/catalog.dart`: الرئيسية والأقسام والشركات والبحث والباركود وتفاصيل المنتج.
- `lib/screens/auth.dart`: OTP وكلمة المرور والتسجيل وتعديل الحساب.
- `lib/screens/address.dart`: خريطة العنوان وإدارته وتحديد الفرع حسب الطريق الفعلي.
- `lib/screens/checkout.dart`: السلة والتسعير والمراجعة والتأكيد والإيصال.
- `lib/screens/account.dart`: المفضلة والمشتريات والتتبع والإشعارات والولاء والقسائم.
- `lib/screens/returns.dart`: الاسترجاع والصور وحالة المراجعة.
- `test/`: اختبارات كميات وأسعار واستعادة الطلب ومنع التكرار.

## الربط الحالي

نفس مشروع Supabase: `qzvpayjaadbmpayeglon`.

الكتالوج يستخدم `get_customer_branch_catalog` و`get_customer_branch_products_by_ids` وفق فرع العنوان. العناوين تستخدم `find_delivery_branch` ثم Edge Function `route-distance`؛ الخريطة المرئية OpenStreetMap، وحساب الطريق الفعلي نفس الخدمة الحالية.

الطلبات تستخدم `quote_customer_cart` و`quote_customer_order` ثم `place_customer_order_with_voucher`. لا توجد كتابة مباشرة لإنشاء الطلبات أو تحديد سعرها أو خصم المخزون في العميل. يحفظ التطبيق request UUID والتفاصيل قبل الإرسال ويستخدم `reconcile_customer_checkout_attempt` عند استعادة محاولة غير محسومة. لو النتيجة غير مؤكدة، لا يُحذف الطلب المعلّق لمجرد أن الاتصال فشل. هذا القفل داخل instance واحد؛ لا يُدّعى اختبار تعدد أجهزة أو تبويبات Flutter Web.

السلة تستخدم `replace_customer_cart` مع `p_expected_user_id`؛ المفضلة `set_customer_favorite_unit`، والعنوان الافتراضي `set_default_customer_address`. بعد نجاح المزامنة يقرأ التشغيل التالي نسخة السيرفر كي تظهر تعديلات الأجهزة الأخرى. تبقى التعديلات التي فشلت مزامنتها على الجهاز.

المشتريات تجمع فواتير الفرع والأونلاين عبر `get_my_purchase_history`، مع Realtime والتحديث كل 30 ثانية وأزرار تحديث وسجل `order_status_history`. الإشعارات داخل التطبيق تستخدم Realtime وتُحدث كل 30 ثانية؛ لا توجد إضافة جديدة لإشعارات Push في الخلفية.

الاسترجاع يستخدم `create_customer_return_request` وصورًا تحت مسار المستخدم داخل bucket `returns`. لا ينشئ bucket ولا يعدّل سياسات الإنتاج. عدم التأكد من نتيجة إرسال الاسترجاع يوقف الإرسال المتكرر ويوجه لمراجعة الطلبات.

## إعدادات Android وiOS

- أذونات الإنترنت والكاميرا والموقع مضافة. طلب الموقع اختياري؛ يمكن اختيار النقطة يدويًا.
- اسم المتجر والشعار الأصلي مضافان.
- رابط عودة المصادقة: `com.elmadawy.market://auth-callback` مسجل في Android وiOS. يلزم إدراجه في Supabase Auth Redirect URLs قبل اختبار استعادة كلمة المرور بالبريد على الهاتف؛ لم نغيّر إعدادات الإنتاج.
- يحتاج بناء iOS جهاز macOS وXcode وCocoaPods وحساب توقيع. لم يُبنَ iOS على Windows.
- إعداد توقيع release ما زال إعداد Flutter التجريبي. لا تنشر ملفًا للإنتاج قبل إعداد keystore/provisioning وتوقيع المتجر المناسب.
- التطبيق يدعم Android وiOS وFlutter Web. مجلدات Windows/macOS/Linux غير مولدة.

## التحقق وحدوده

راجع `TEST-REPORT.md` و`FEATURE-MAP.md` و`DESIGN-REVIEW.md`. نجاح compile واختبارات mocks لا يعني اختبار شراء حقيقي أو إثبات سياسات RLS. لم تُنشأ طلبات إنتاج أو حسابات اختبار أو مرتجعات، ولم نرسل SMS أو ننشر أي نسخة إلى المتاجر أو نعدّل بيانات الإنتاج.

## هوية الواجهة

ملف `lib/core/design.dart` يثبت ألوان الويب الأصلية (#005931 و#f6f8f7) وأشكال الأزرار والحقول. خط Cairo مضمّن في assets/fonts مع رخصته، ويعمل دون تنزيل وقت التشغيل.
