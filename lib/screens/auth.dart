import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/ui.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final identifier = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController(),
      name = TextEditingController();
  String mode = 'otp';
  bool sent = false;
  @override
  void dispose() {
    for (final c in [identifier, password, code, name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final auth = market.db.auth;
    final input = identifier.text.trim();
    if (input.isEmpty) {
      message(context, 'اكتب رقم الموبايل أو البريد');
      return;
    }
    if (mode == 'otp') {
      if (!sent) {
        await auth.signInWithOtp(phone: phoneNumber(input));
        if (mounted) setState(() => sent = true);
        return;
      }
      await auth.verifyOTP(
        phone: phoneNumber(input),
        token: code.text.trim(),
        type: OtpType.sms,
      );
    } else if (mode == 'login') {
      await auth.signInWithPassword(
        email: input.contains('@') ? input : null,
        phone: input.contains('@') ? null : phoneNumber(input),
        password: password.text,
      );
    } else if (mode == 'register') {
      if (name.text.trim().length < 2 || password.text.length < 8) {
        message(context, 'اكتب اسمك وكلمة مرور ٨ أحرف على الأقل');
        return;
      }
      await auth.signUp(
        email: input.contains('@') ? input : null,
        phone: input.contains('@') ? null : phoneNumber(input),
        password: password.text,
        data: {'name': name.text.trim(), 'first_name': name.text.trim()},
      );
      if (!mounted) return;
      if (market.user == null) {
        message(context, 'راجع البريد أو رمز SMS لتأكيد الحساب');
        if (!input.contains('@')) {
          setState(() {
            mode = 'otp';
            sent = true;
          });
        }
        return;
      }
    } else {
      if (!input.contains('@')) {
        setState(() {
          mode = 'otp';
          sent = false;
        });
        message(context, 'استرجع حسابك بكود الموبايل وبعدها غيّر كلمة المرور');
        return;
      }
      await auth.resetPasswordForEmail(
        input,
        redirectTo: 'com.elmadawy.market://auth-callback',
      );
      if (!mounted) return;
      message(context, 'لو البريد مسجل هيوصلك رابط الاستعادة');
      return;
    }
    await market.load();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'أهلًا بيك في المعداوي',
    SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: const Border(
              top: BorderSide(color: Color(0xff005931), width: 5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10003c21),
                blurRadius: 48,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo.png', height: 64),
              heading('كل احتياجات بيتك في مكان واحد'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('رمز الموبايل'),
                    selected: mode == 'otp',
                    onSelected: (_) => setState(() {
                      mode = 'otp';
                      sent = false;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('كلمة المرور'),
                    selected: mode == 'login',
                    onSelected: (_) => setState(() => mode = 'login'),
                  ),
                  ChoiceChip(
                    label: const Text('حساب جديد'),
                    selected: mode == 'register',
                    onSelected: (_) => setState(() => mode = 'register'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: identifier,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: mode == 'otp'
                      ? 'رقم الموبايل'
                      : 'الموبايل أو البريد الإلكتروني',
                ),
              ),
              const SizedBox(height: 16),
              if (mode == 'register')
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم بالكامل'),
                ),
              if (mode == 'register') const SizedBox(height: 16),
              if (mode == 'login' || mode == 'register')
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                ),
              if (mode == 'otp' && sent)
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'رمز التحقق'),
                ),
              const SizedBox(height: 20),
              ActionButton(
                mode == 'otp' && !sent
                    ? 'إرسال رمز التحقق'
                    : mode == 'reset'
                    ? 'إرسال رابط الاستعادة'
                    : 'متابعة',
                submit,
              ),
              if (sent)
                TextButton(
                  onPressed: () => setState(() => sent = false),
                  child: const Text('تغيير الرقم أو إعادة الإرسال'),
                ),
              TextButton(
                onPressed: () => setState(() => mode = 'reset'),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController(
        text:
            '${market.profile?['name'] ?? market.user?.userMetadata?['name'] ?? ''}',
      ),
      password = TextEditingController(),
      phone = TextEditingController(),
      code = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    for (final c in [name, password, phone, code]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'بيانات حسابي',
    ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'الاسم بالكامل'),
        ),
        const SizedBox(height: 12),
        ActionButton('حفظ الاسم', () async {
          if (name.text.trim().length < 2) {
            message(context, 'اكتب الاسم بالكامل');
            return;
          }
          await market.db.auth.updateUser(
            UserAttributes(
              data: {'name': name.text.trim(), 'first_name': name.text.trim()},
            ),
          );
          await market.rpc('link_profile_to_customer');
          await market.db
              .from('customers')
              .update({'name': name.text.trim()})
              .eq('user_id', market.user!.id);
          await market.load();
          if (context.mounted) message(context, 'تم حفظ الاسم');
        }),
        heading('تغيير كلمة المرور'),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        ActionButton('حفظ كلمة المرور', () async {
          if (password.text.length < 8) {
            message(context, 'استخدم ٨ أحرف على الأقل');
            return;
          }
          await market.db.auth.updateUser(
            UserAttributes(password: password.text),
          );
          password.clear();
          if (context.mounted) message(context, 'تم تغيير كلمة المرور');
        }),
        heading('تغيير رقم الموبايل'),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'الرقم الجديد'),
        ),
        if (sent)
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'رمز التحقق'),
          ),
        ActionButton(sent ? 'تأكيد الرقم' : 'إرسال رمز للرقم الجديد', () async {
          if (!sent) {
            await market.db.auth.updateUser(
              UserAttributes(phone: phoneNumber(phone.text)),
            );
            setState(() => sent = true);
          } else {
            await market.db.auth.verifyOTP(
              phone: phoneNumber(phone.text),
              token: code.text.trim(),
              type: OtpType.phoneChange,
            );
            await market.load();
            if (context.mounted) message(context, 'تم تغيير الرقم');
          }
        }),
      ],
    ),
  );
}
