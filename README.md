# PhotoMagic Admin — لوحة إدارة الحسابات

تطبيق Flutter مستقل لإدارة حسابات تطبيق **PhotoMagic** (`com.abodycode.photomagic`).
هو نسخة من لوحة إدارة الحسابات الخاصة بمشروع bawsalah، مع حزمة وأيقونة جديدتين.

* **اسم الحزمة (Android applicationId):** `com.abodycode.photomagic.admin`
* **اسم التطبيق:** PhotoMagic Admin
* **قاعدة البيانات:** Firebase Realtime Database — العقدة `/accounts`

## الوظائف

| الوظيفة | التفصيل |
| --- | --- |
| بوابة كلمة المرور الرئيسية | PBKDF2-HMAC-SHA256، تُطلب في **كل** تشغيل، ولا يمكن الوصول لأي شيء قبلها |
| قائمة الحسابات | حيّة عبر `onValue` تحت `/accounts`، الأحدث أولاً |
| إنشاء حساب | دائم (دائمي) أو تجريبي (تجريبي) بمدة `hh:mm:ss`، مع مولّد كلمات مرور عشوائية |
| تعديل حساب | تغيير الاسم أو كلمة المرور أو النوع أو إعادة ضبط العدّاد |
| حذف حساب | حذف نهائي بعد التأكيد |
| تنظيف المنتهية | حذف الحسابات التجريبية المنتهية نهائيًا عند فتح اللوحة |
| حالات الانقطاع | شاشة خطأ صريحة مع إعادة المحاولة |

## مخطط البيانات المشترك

```
/accounts/{username}        # المفتاح: اسم المستخدم بحروف صغيرة
  salt:        <hex32>      // عشوائي لكل حساب
  hash:        v2$100000$<salt>$<pbkdf2-hex>
  permanent:   bool
  expiry_at:   <epoch ms>   // يُحذف للحسابات الدائمة
  created_at:  <epoch ms>
```

تطبيق PhotoMagic يقرأ هذه العقد نفسها للتحقق من تسجيل الدخول، لذا يجب أن
يشير التطبيقان إلى **نفس مشروع Firebase**.

## إعداد Firebase

1. أضف تطبيق Android بالحزمة `com.abodycode.photomagic.admin` إلى مشروع
   Firebase الجديد.
2. نزّل `google-services.json` وضعه في `android/app/google-services.json`.
3. فعّل Realtime Database واسمح بالقراءة/الكتابة على `/accounts`
   (قواعد أمان مناسبة، وليس الوضع المفتوح في الإنتاج).
4. حدّث `lib/firebase_options.dart` بقيم المشروع (تُستخدم لنسخة الويب فقط).

Google Services plugin `4.4.2` مربوط في `android/settings.gradle.kts`
ومُطبَّق في `android/app/build.gradle.kts`.

## البناء والتشغيل

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

ملف الـ APK:

```
build/app/outputs/flutter-apk/app-release.apk
```

أو نسخ أصغر لكل معمارية: `flutter build apk --split-per-abi`
(المفضّل للأجهزة الحديثة: `app-arm64-v8a-release.apk`).

## الأيقونة

أيقونة التطبيق مختلفة عن أيقونة لوحة الإدارة الأصلية: درع أبيض بمفتاح
على خلفية تدرّج بنفسجي/أزرق. تُولّد كل المقاسات بالأمر:

```bash
dart run tool/generate_app_icon.dart
```

## خريطة الكود

```
lib/
├── main.dart                                  # تهيئة Firebase (شاشة خطأ قاتلة عند الفشل)
├── core/admin_security.dart                   # التجزئة الرئيسية والتشفير ومولّد كلمات المرور
├── domain/account_model.dart                  # AdminAccount — مخطط /accounts المشترك
├── data/
│   ├── accounts_repository.dart               # الواجهة + بديل للاختبارات
│   └── firebase_accounts_repository.dart      # تنفيذ RTDB
├── presentation/
│   ├── admin_app.dart                         # بوابة كلمة المرور الرئيسية
│   └── screens/
│       ├── master_gate_screen.dart            # طلب كلمة المرور في كل تشغيل
│       ├── accounts_screen.dart               # القائمة الحيّة والعمليات
│       └── account_edit_dialog.dart           # نافذة الإنشاء/التعديل
└── theme/admin_theme.dart                     # الثيم الفاتح/الداكن
```
