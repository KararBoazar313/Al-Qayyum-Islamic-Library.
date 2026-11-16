# تشغيل قاعدة بيانات القيّوم (تجريبي)

المتطلبات: PostgreSQL 16+ وامتداد `pgcrypto`، وقاعدة بيانات اختبار فارغة.

نفّذ بالترتيب من مجلد المشروع:
```bash
psql -v ON_ERROR_STOP=1 -d qayyum_test -f database/001_core_schema.sql
psql -v ON_ERROR_STOP=1 -d qayyum_test -f database/002_platform_modules.sql
psql -v ON_ERROR_STOP=1 -d qayyum_test -f database/003_catalog_import.sql
psql -v ON_ERROR_STOP=1 -d qayyum_test -f database/004_security_community_backups.sql
```

تحقق أولي بعد التنفيذ:
```sql
SELECT table_schema, count(*) AS table_count
FROM information_schema.tables
WHERE table_schema='qayyum' AND table_type='BASE TABLE'
GROUP BY table_schema;
SELECT public_id, account_type FROM qayyum.users;
SELECT to_regclass('qayyum.direct_messages') AS direct_messages_table;
```

المتوقع: لا تُنشأ بيانات مالك تلقائياً، وجدول `direct_messages` غير موجود. لا تنفذ الاختبار على قاعدة إنتاج.

## ملاحظات أمنية وتشغيلية
- لا تنشئ حساب المالك 313 قبل إعداد إجراء خادمي آمن، وتفعيل MFA، وتخزين الأسرار خارج المستودع.
- قيد المعرّف 313 في المخطط يمنع استخدامه لحساب غير المالك، لكن يجب اختبار منع إنشاء أكثر من مالك في بيئة PostgreSQL حقيقية قبل الإنتاج.
- جداول SQL وحدها لا تنفذ API أو سياسات وصول صفية أو تشفير ملفات أو نسخاً احتياطية فعلية.
- راجع الصلاحيات، RLS، الحذف، وسجل التدقيق واختبر الاستعادة قبل إطلاق الخدمة.
- لا توجد نتيجة اختبار PostgreSQL فعلية مرفقة بهذه الحزمة؛ شغّل الأوامر أعلاه على بيئة اختبار واحتفظ بالمخرجات.
