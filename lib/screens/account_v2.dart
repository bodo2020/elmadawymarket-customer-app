import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'account.dart';
import 'auth.dart';

class AccountV2Page extends StatelessWidget {
  const AccountV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    if (market.user != null) {
      return const AccountPage();
    }

    return ListView(
      key: const PageStorageKey('guest-account-v2'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
              decoration: BoxDecoration(
                color: MarketColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: MarketColors.divider),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
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
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MarketColors.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: MarketColors.primary,
                        size: 31,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أهلًا بيك في المعداوي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجّل برقم موبايلك عشان تتابع مشترياتك ونقاطك وتحفظ عناوينك ومنتجاتك المفضلة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.75,
                      color: MarketColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => open(context, const AuthPage()),
                    icon: const Icon(Icons.phone_android_rounded, size: 19),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Text('تسجيل الدخول أو إنشاء حساب'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => openShellTab(context, 0),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('كمّل تصفح المنتجات'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
