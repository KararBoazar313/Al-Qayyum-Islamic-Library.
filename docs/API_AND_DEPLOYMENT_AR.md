# تشغيل API مكتبة القيّوم

## المتطلبات
- Node.js 20 أو أحدث.
- PostgreSQL 16 أو أحدث.
- قاعدة بيانات مخصصة ومستخدم تطبيق بأقل صلاحيات ممكنة.
- HTTPS، نسخ احتياطية، ومخزن ملفات خاص خارج مجلد الويب.

## إعداد قاعدة البيانات
أنشئ قاعدة بيانات PostgreSQL 16 ومستخدم تطبيق مخصصاً بأقل صلاحيات لازمة، ثم من مجلد `server/` شغّل أداة الترحيل التي تطبق ملفات `database/001` إلى `database/012` بالترتيب وتسجل كل ترحيل في `qayyum.schema_migrations`:

```bash
cd server
npm install
npm run migrate
```

تستخدم أداة الترحيل معاملة مستقلة لكل ملف، ولا تكرر ترحيلاً مسجلاً. خذ نسخة احتياطية قبل أي ترحيل على قاعدة تحتوي بيانات. لا تشغّل ملفات SQL يدوياً بالتوازي مع الأداة.

## تشغيل الخادم

```bash
cd server
cp .env.example .env
# عدّل DATABASE_URL وJWT_SECRET وCORS_ORIGIN وPRIVATE_STORAGE_DIR
npm install
npm run migrate
npm start
```

لإنشاء حساب المالك مرة واحدة: عيّن `OWNER_EMAIL` و`OWNER_PASSWORD` (16 محرفاً أو أكثر) في البيئة، ثم شغّل `npm run bootstrap-owner`. أزل كلمة المرور من البيئة فور نجاح الإنشاء.

## واجهات API الأساسية
- `GET /api/health`
- `POST /api/auth/register`, `POST /api/auth/login`
- `GET /api/catalog/works?q=` يعرض الأعمال المنشورة فقط.
- `POST /api/research/notes`, `GET/PUT/DELETE /api/research/notes` — ملاحظات خاصة بصاحب الحساب.
- `PUT /api/reader/progress`, `GET /api/reader/progress/:editionId`
- `POST /api/files` — رفع PDF/EPUB إلى الحجر الخاص؛ لا يعطي رابط قراءة.
- `GET /api/files/:id/read` — يتطلب جلسة، وفحصاً نظيفاً، وقرار حقوق يسمح بالقراءة؛ الوصول المقيد لصاحب الملف/الإدارة.
- `POST /api/admin/import/preview`, `POST /api/admin/import/stage`
- `POST /api/admin/import/records/:id/approve` — يحوّل السجل المقبول إلى مسودة عمل، لا ينشره.
- `PUT /api/admin/files/:id/review` — تسجيل نتيجة الفحص ومراجعة الحقوق.
- `POST /api/admin/works/:id/publish` — قرار النشر العلمي النهائي للمالك/المدير.
- `GET /api/admin/review/rights`

## دورة الملف الرقمي
1. رفع الملف بعد المصادقة.
2. فحص امتداد وتوقيع PDF/ZIP، الحجم، وتوليد SHA-256.
3. تخزينه في مجلد خاص بصلاحية ملف مقيدة، وتسجيل حالة `pending`.
4. تشغيل ماسح برمجيات خبيثة خارجي على مسار الحجر؛ لا تضبط `scanStatus=clean` قبل نتيجة موثقة.
5. يراجع مختص المصدر والرخصة الأصلية والرابط ومالك الحق ونطاق الوصول.
6. يسجل المدير قراراً مناسباً؛ لا يُسمح بالتوزيع إلا مع دليل موثق ورخصة صريحة ومراجع وتاريخ مراجعة.
7. لا يسمح مسار القراءة إلا بملف نظيف وقرار قراءة صالح. الروابط ليست عامة ولا تُخزن في صفحات ثابتة.

## دفعات الفهرسة
استخدم أدوات `tools/` لتحويل المصدر، ثم `tools_validate_catalog.py`، ثم `match_catalog_editions.py`، ثم `review_workflow.py`. ابدأ دائماً بالمعاينة وdry-run. خدمة API تخزن سجلات المصدر كـ`needs_review`، وعند قبول السجل ينشئ مسودة فقط. النشر العلمي وحقوق الملفات قراران منفصلان.

## حدود الاستضافة الثابتة
GitHub Pages مناسب لملفات `index.html`, `styles.css`, `app.js` فقط. لا يتيح تشغيل API أو PostgreSQL أو تخزين ملفات خاصة. انشر مجلد الواجهة على Pages، وانشر `server/` على استضافة خادم منفصلة، ثم أضف عنوان API إلى إعداد الواجهة مع CORS محدود. لا تضع بيانات الاتصال أو مفاتيح JWT داخل JavaScript للمتصفح.

## ربط واجهة GitHub Pages بالخادم
بعد نشر API على عنوان HTTPS ثابت، غيّر قيمة الوسم التالي في `index.html` إلى عنوان الخادم (من دون `/` أخيرة). هذا الوسم غير موجود في النسخة المصدر ويجب إضافته قبل أن تتصل الواجهة بالخادم:

```html
<meta name="qayyum-api-base" content="https://api.example.org">
```

ثم اضبط `CORS_ORIGIN` في الخادم على نطاق GitHub Pages الفعلي فقط. عندها تعمل نماذج الدخول والتسجيل، بحث الأعمال المنشورة، مزامنة الملاحظات، ورفع الملفات إلى الحجر. رمز الدخول يبقى في `sessionStorage` للجلسة الحالية ولا يوضع في مستودع Git.
