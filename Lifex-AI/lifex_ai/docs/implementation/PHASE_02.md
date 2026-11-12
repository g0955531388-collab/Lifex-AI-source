# المرحلة 2 — بعد إقلاع الهاتف

التاريخ: 2026-10-15  
بعد: `4722a52`

## ما تغيّر

- مفتاح «استئناف وضع الوصول بعد إقلاع الهاتف» في الإعداد الأولي، ويُحفظ في `SharedPreferences`.
- عند التفعيل يبقى الخيار محفوظاً. الكاميرا والميكروفون لا يبدآن عند الإقلاع.
- `AndroidManifest.xml` بلا `RECEIVE_BOOT_COMPLETED` وبلا `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

## الاختبار

`flutter test test/features/boot_access_preference_test.dart` → `+2: All tests passed`.

`flutter analyze` لملف التفضيل وشاشة الإعداد → `No issues found`.

لم يُعد تشغيل الهاتف. جهاز Honor كان متصلاً في جلسة سابقة، وإعادة إقلاعه لم تُنفَّذ هنا حتى لا ينقطع استخدامه. لذلك لا يُدّعى أن مساراً بعد الإقلاع اشتغل على الجهاز.
