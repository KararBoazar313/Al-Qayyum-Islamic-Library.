# إعداد تسجيل Google وتخزين Cloudflare R2 لمكتبة القيّوم

## تسجيل الدخول باستخدام Google

1. أنشئ مشروعاً في Firebase Console وأضف تطبيق Web.
2. من Authentication > Sign-in method فعّل Google.
3. من Authentication > Settings > Authorized domains أضف `kararboazar313.github.io`.
4. انسخ قيم Web App العامة إلى وسوم meta في `index.html`:
   - `firebase-api-key`
   - `firebase-auth-domain`
   - `firebase-project-id`
   - `firebase-app-id`
5. أنشئ Service Account من إعدادات مشروع Firebase، وخزّن JSON الكامل في متغير بيئة سري باسم `FIREBASE_SERVICE_ACCOUNT_JSON` في منصة تشغيل API. لا تضع ملف Service Account أو محتواه في GitHub.
6. أعد نشر API بعد تثبيت اعتماد `firebase-admin`.

مسار API هو `POST /api/auth/google` ويستقبل `{ "idToken": "..." }`. الخادم يتحقق من الرمز والبريد المؤكد، ثم يربط هوية Google بحساب البريد الموجود إن تطابق البريد، أو ينشئ حساباً جديداً. جلسة المكتبة تبقى JWT الحالية.

## إعداد Cloudflare R2

وحدة التخزين الحالية تدعم S3-compatible storage، لذلك لا تحتاج إلى تغيير كود تخزين الملفات.

اضبط متغيرات البيئة التالية في منصة API:

- `S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
- `S3_REGION=auto`
- `S3_BUCKET=<PRIVATE_BUCKET_NAME>`
- `S3_ACCESS_KEY_ID=<R2_ACCESS_KEY_ID>`
- `S3_SECRET_ACCESS_KEY=<R2_SECRET_ACCESS_KEY>`
- `S3_FORCE_PATH_STYLE=false`

احذف `RAPIDFILE_SECRET_KEY` عند التحويل إلى R2؛ لا يجوز إعداد المزودين معاً. أنشئ bucket خاصاً، ولا تجعل ملفات الكتب عامة مباشرة. يستمر الخادم في إصدار روابط/تدفقات الوصول وفق صلاحيات المكتبة.

بعد ضبط المتغيرات أعد تشغيل API، ثم افحص `/api/health` وتأكد أن `privateStorageMode` يساوي `s3` وأن `privateStorageConfigured` و`privateStorageDurable` يساويان true.

## ملاحظات أمان

- لا تضع مفاتيح R2 أو Service Account في ملفات الواجهة أو GitHub.
- لا تحذف ملفات Rapidfile القديمة قبل ترحيلها والتحقق من سلامة الملفات الجديدة.
- اختبر رفع ملف وقراءته وحذفه بحساب إداري قبل تحويل الاستخدام الكامل.
- لا تُفعّل الفوترة أو تنشئ موارد مدفوعة قبل مراجعة السعر والحصة المجانية في لوحة المزود.
