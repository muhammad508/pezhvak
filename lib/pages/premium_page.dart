import 'package:flutter/material.dart';
import 'package:pezhvak/services/purchase_service.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/utils/history_tools.dart';

/// Opens the subscription screen. Screens that care about the result listen to
/// [PremiumService.status]; there is nothing to await.
Future<void> openPremiumPage(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumPage()),
    );

/// Subscription plans, purchase and restore.
class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _loadingMonthly = false;
  bool _loadingYearly = false;
  bool _loadingRestore = false;
  DateTime? _expiry;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final expiry = await PremiumService.getExpiry();
    final premium = await PremiumService.isPremium();
    if (mounted) {
      setState(() {
        _expiry = expiry;
        _isPremium = premium;
      });
    }
  }

  Future<void> _purchase(String sku) async {
    final isMonthly = sku == skuMonthly;
    setState(() {
      if (isMonthly) {
        _loadingMonthly = true;
      } else {
        _loadingYearly = true;
      }
    });

    final result = await PurchaseService.purchase(sku);

    if (!mounted) return;
    setState(() {
      if (isMonthly) {
        _loadingMonthly = false;
      } else {
        _loadingYearly = false;
      }
    });

    if (result.success) {
      await _loadStatus();
      _showSuccess(
        'خرید موفق!',
        'اشتراک پریمیوم شما تا ${jalaliDate(result.expiry!)} فعال است.',
      );
    } else {
      _showError(result.errorMessage ?? 'خرید ناموفق بود');
    }
  }

  Future<void> _restore() async {
    setState(() => _loadingRestore = true);
    final result = await PurchaseService.restore();
    if (!mounted) return;
    setState(() => _loadingRestore = false);

    switch (result.status) {
      case RestoreStatus.success:
        await _loadStatus();
        _showSuccess(
          'بازیابی موفق!',
          'اشتراک پریمیوم شما تا ${jalaliDate(result.expiry!)} فعال است.',
        );
        break;
      case RestoreStatus.expired:
        _showError(
          'اشتراک قبلی شما در تاریخ ${jalaliDate(result.expiry!)} منقضی شده است.',
        );
        break;
      case RestoreStatus.notFound:
        _showError('هیچ خرید قبلی‌ای یافت نشد.');
        break;
      case RestoreStatus.error:
        _showError(result.errorMessage ?? 'خطا در بازیابی');
        break;
    }
  }

  void _showSuccess(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(title),
        ]),
        content: Text(message, style: const TextStyle(height: 1.6)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('عالیه!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('خطا'),
        ]),
        content: Text(message, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اشتراک پریمیوم'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade400
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star, size: 56, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'پژواک پریمیوم',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isPremium && _expiry != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'اشتراک فعال تا ${jalaliDate(_expiry!)}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'دسترسی کامل به همه امکانات',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Premium features
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('امکانات پریمیوم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      _FeatureRow(
                          icon: Icons.schedule,
                          title: 'زمان‌بندی آلارم',
                          subtitle: 'تعیین ساعت و روز فعال بودن آلارم'),
                      _FeatureRow(
                          icon: Icons.history,
                          title: 'تاریخچه ۵۰۰۰ نوتیفیکیشن',
                          subtitle: 'نسخه رایگان: فقط ۵ تا'),
                      _FeatureRow(
                          icon: Icons.alarm,
                          title: 'تاریخچه کامل آلارم‌ها',
                          subtitle: 'مشاهده همه آلارم‌های دریافتی'),
                      _FeatureRow(
                          icon: Icons.power_settings_new_rounded,
                          title: 'خاموش کردن موقت سرویس',
                          subtitle: 'توقف موقت پایش نوتیفیکیشن‌ها'),
                      _FeatureRow(
                          icon: Icons.search_rounded,
                          title: 'جستجو و فیلتر پیشرفته',
                          subtitle: 'جستجو در تاریخچه و فیلتر بر اساس اپ'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Monthly plan card
              _PlanCard(
                title: 'اشتراک ماهانه',
                price: '۵۰٬۰۰۰ تومان',
                subtitle: '۳۱ روز + ۱ روز هدیه',
                icon: Icons.calendar_today,
                color: Colors.blue,
                isLoading: _loadingMonthly,
                isPremium: _isPremium,
                onTap: () => _purchase(skuMonthly),
              ),

              const SizedBox(height: 12),

              // Yearly plan card
              _PlanCard(
                title: 'اشتراک سالانه',
                price: '۵۰۰٬۰۰۰ تومان',
                subtitle: '۳۶۶ روز + ۱ روز هدیه',
                icon: Icons.calendar_month,
                color: Colors.orange,
                isLoading: _loadingYearly,
                isPremium: _isPremium,
                onTap: () => _purchase(skuYearly),
              ),

              const SizedBox(height: 20),

              // Restore purchases button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingRestore ? null : _restore,
                  icon: _loadingRestore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label: const Text('بازیابی خرید قبلی'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'در صورت داشتن اشتراک فعال، خرید جدید به مدت اشتراک فعلی اضافه می‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تاریخچه نوتیفیکیشن‌ها از زمان نصب برنامه ثبت می‌شود. داده‌های قبل از نصب در دسترس نیستند.',
                        style: TextStyle(
                            color: Colors.blue[700], fontSize: 11, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool isPremium;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Column(
                      children: [
                        Text(price,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isPremium ? 'تمدید' : 'خرید',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
