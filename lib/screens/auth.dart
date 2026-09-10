import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'address.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final phone = TextEditingController();
  final code = TextEditingController();
  final codeFocus = FocusNode();
  Timer? timer;

  bool sent = false;
  bool busy = false;
  int resendSeconds = 0;
  String country = 'EG';

  static const countries = <String, ({String name, String dial, String flag})>{
    'EG': (name: 'مصر', dial: '+20', flag: '🇪🇬'),
    'SA': (name: 'السعودية', dial: '+966', flag: '🇸🇦'),
    'AE': (name: 'الإمارات', dial: '+971', flag: '🇦🇪'),
  };

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  String get normalizedPhone {
    var digits = _normalizeDigits(phone.text).replaceAll(RegExp(r'\D'), '');
    final selected = countries[country]!;
    final dialDigits = selected.dial.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }
    if (country == 'EG' && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+$dialDigits$digits';
  }

  bool _validPhone() {
    var digits = _normalizeDigits(phone.text).replaceAll(RegExp(r'\D'), '');
    final dialDigits = countries[country]!.dial.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(dialDigits)) digits = digits.substring(dialDigits.length);
    if (country == 'EG' && digits.startsWith('0')) digits = digits.substring(1);

    if (digits.isEmpty) {
      message(context, 'اكتب رقم الموبايل');
      return false;
    }
    if (country == 'EG' && (digits.length != 10 || !digits.startsWith('1'))) {
      message(context, 'اكتب رقم مصري صحيح مثل 01012345678');
      return false;
    }
    return true;
  }

  void _startTimer() {
    timer?.cancel();
    setState(() => resendSeconds = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (value) {
      if (!mounted) return;
      if (resendSeconds <= 1) {
        value.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (busy || (resend && resendSeconds > 0) || !_validPhone()) return;
    setState(() => busy = true);
    try {
      await market.db.auth.signInWithOtp(
        phone: normalizedPhone,
        shouldCreateUser: true,
        channel: OtpChannel.sms,
      );
      if (!mounted) return;
      code.clear();
      setState(() => sent = true);
      _startTimer();
      message(
        context,
        resend ? 'تم إعادة إرسال رمز التحقق' : 'تم إرسال رمز التحقق',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) codeFocus.requestFocus();
      });
    } catch (error) {
      if (!mounted) return;
      final text = '$error';
      message(
        context,
        text.contains('429') || text.contains('over_sms_send_rate_limit')
            ? 'تم طلب رموز كثيرة. انتظر قليلًا قبل المحاولة مرة أخرى.'
            : friendlyError(error),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    if (busy) return;
    final otp = _normalizeDigits(code.text).replaceAll(RegExp(r'\D'), '');
    if (otp.length != 6) {
      message(context, 'اكتب رمز التحقق المكون من 6 أرقام');
      return;
    }
    setState(() => busy = true);
    try {
      final response = await market.db.auth.verifyOTP(
        phone: normalizedPhone,
        token: otp,
        type: OtpType.sms,
      );
      if (response.user == null) throw StateError('AUTH_REQUIRED');
      await market.load();
      if (!mounted) return;

      final profileName = '${market.profile?['name'] ?? ''}'.trim();
      if (market.profile == null || profileName.length < 2) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfilePage(firstRun: true)),
        );
        return;
      }
      if (market.address == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const AddressPage(requiredAddress: true),
          ),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) message(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _changePhone() {
    timer?.cancel();
    code.clear();
    setState(() {
      sent = false;
      resendSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(sent ? 'تأكيد رقمك' : 'أهلًا بيك في المعداوي'),
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  tooltip: 'رجوع',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                )
              : null,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MarketColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: MarketColors.divider),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MarketColors.primarySurface,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Image.asset('assets/logo.png'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        sent ? 'أدخل رمز التحقق' : 'دخول سريع برقم موبايلك',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        sent
                            ? 'بعتنا رمز من 6 أرقام إلى $normalizedPhone'
                            : 'مفيش كلمة مرور. هنرسل لك رمز تحقق لمرة واحدة، والحساب الجديد بيتعمل بنفس الرقم.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: MarketColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!sent) ...[
                        LayoutBuilder(
                          builder: (context, box) {
                            final narrow = box.maxWidth < 330 ||
                                MediaQuery.textScalerOf(context).scale(14) > 20;
                            final selector = DropdownButtonFormField<String>(
                              value: country,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'الدولة',
                              ),
                              items: countries.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        '${entry.value.flag} ${entry.value.name} ${entry.value.dial}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() => country = value!),
                            );
                            final phoneField = TextField(
                              controller: phone,
                              enabled: !busy,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              onSubmitted: (_) => _sendOtp(),
                              decoration: InputDecoration(
                                labelText: 'رقم الموبايل',
                                hintText: country == 'EG' ? '01012345678' : 'رقم الهاتف',
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                            );
                            if (narrow) {
                              return Column(
                                children: [
                                  selector,
                                  const SizedBox(height: 12),
                                  phoneField,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 160, child: selector),
                                const SizedBox(width: 10),
                                Expanded(child: phoneField),
                              ],
                            );
                          },
                        ),
                        if (country == 'EG') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'اكتب رقمك عادي 010… أو الصقه بكود الدولة +20.',
                            style: TextStyle(
                              fontSize: 11,
                              color: MarketColors.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        ActionButton(
                          'إرسال رمز التحقق',
                          () => _sendOtp(),
                          icon: Icons.sms_outlined,
                          enabled: !busy,
                        ),
                      ] else ...[
                        _OtpField(
                          controller: code,
                          focusNode: codeFocus,
                          enabled: !busy,
                          onCompleted: _verify,
                        ),
                        const SizedBox(height: 18),
                        ActionButton(
                          'التحقق من الرمز',
                          _verify,
                          icon: Icons.verified_outlined,
                          enabled: !busy,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: busy || resendSeconds > 0
                              ? null
                              : () => _sendOtp(resend: true),
                          child: Text(
                            resendSeconds > 0
                                ? 'إعادة الإرسال بعد $resendSeconds ثانية'
                                : 'إعادة إرسال الرمز',
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : _changePhone,
                          child: const Text('تغيير رقم الهاتف'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _OtpField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final Future<void> Function() onCompleted;

  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = _normalizeDigits(widget.controller.text)
        .replaceAll(RegExp(r'\D'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'رمز التحقق',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) {
            if (value.length == 6) widget.onCompleted();
          },
          decoration: const InputDecoration(
            hintText: '●  ●  ●  ●  ●  ●',
            counterText: '',
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: List.generate(6, (index) {
            final filled = index < value.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 7,
              decoration: BoxDecoration(
                color: filled ? MarketColors.primary : MarketColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  final bool firstRun;
  const ProfilePage({super.key, this.firstRun = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController name;
  final phone = TextEditingController();
  final code = TextEditingController();
  bool phoneCodeSent = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: '${market.profile?['name'] ?? market.user?.userMetadata?['name'] ?? ''}',
    );
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final fullName = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (fullName.length < 2) {
      message(context, 'اكتب اسمك، حرفين على الأقل');
      return;
    }
    final user = market.user;
    if (user == null || user.phone == null) throw StateError('AUTH_REQUIRED');
    final parts = fullName.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

    await market.db.auth.updateUser(
      UserAttributes(data: {'name': fullName, 'first_name': firstName}),
    );
    await market.db.from('customers').upsert({
      'user_id': user.id,
      'name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'phone': user.phone!.startsWith('+') ? user.phone : '+${user.phone}',
    }, onConflict: 'user_id');
    await market.load();
    if (!mounted) return;

    if (widget.firstRun) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AddressPage(requiredAddress: true),
        ),
      );
    } else {
      message(context, 'تم حفظ بياناتك');
    }
  }

  Future<void> _changePhone() async {
    final normalized = phoneNumber(phone.text);
    if (!phoneCodeSent) {
      if (normalized.replaceAll(RegExp(r'\D'), '').length < 10) {
        message(context, 'اكتب رقم الموبايل الجديد بشكل صحيح');
        return;
      }
      await market.db.auth.updateUser(UserAttributes(phone: normalized));
      if (mounted) setState(() => phoneCodeSent = true);
      return;
    }
    final otp = _normalizeDigits(code.text).replaceAll(RegExp(r'\D'), '');
    if (otp.length != 6) {
      message(context, 'اكتب رمز التحقق المكون من 6 أرقام');
      return;
    }
    await market.db.auth.verifyOTP(
      phone: normalized,
      token: otp,
      type: OtpType.phoneChange,
    );
    await market.load();
    if (mounted) {
      setState(() {
        phoneCodeSent = false;
        phone.clear();
        code.clear();
      });
      message(context, 'تم تغيير رقم الموبايل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
      children: [
        if (widget.firstRun) ...[
          const Icon(
            Icons.verified_user_outlined,
            size: 54,
            color: MarketColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'خلّينا نتعرف عليك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'رقمك اتأكد. اكتب اسمك، وبعدها هنحدد عنوان التوصيل عشان طلباتك توصل لبابك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.6,
              color: MarketColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: MarketColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'رقمك اتأكد · ${market.user?.phone ?? ''}',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: MarketColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const Text(
            'بيانات حسابي',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'حدّث اسمك أو رقم الموبايل المرتبط بالحساب.',
            style: TextStyle(color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          controller: name,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(),
          decoration: const InputDecoration(
            labelText: 'اسمك',
            hintText: 'الاسم اللي تحب نناديك بيه',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        ActionButton(
          widget.firstRun ? 'حفظ ومتابعة' : 'حفظ البيانات',
          _saveName,
          icon: widget.firstRun
              ? Icons.arrow_back_rounded
              : Icons.save_outlined,
        ),
        if (!widget.firstRun) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 18),
          const Text(
            'تغيير رقم الموبايل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'الرقم الحالي: ${market.user?.phone ?? '—'}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'الرقم الجديد',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          if (phoneCodeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رمز التحقق',
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: 12),
          ActionButton(
            phoneCodeSent ? 'تأكيد الرقم الجديد' : 'إرسال رمز للرقم الجديد',
            _changePhone,
            icon: phoneCodeSent
                ? Icons.verified_outlined
                : Icons.sms_outlined,
          ),
        ],
      ],
    );

    if (widget.firstRun) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(centerTitle: true, title: const Text('إكمال الحساب')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: body,
              ),
            ),
          ),
        ),
      );
    }
    return PageFrame('بيانات حسابي', body);
  }
}

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final ai = arabic.indexOf(char);
    final pi = persian.indexOf(char);
    if (ai >= 0) {
      buffer.write(ai);
    } else if (pi >= 0) {
      buffer.write(pi);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}
