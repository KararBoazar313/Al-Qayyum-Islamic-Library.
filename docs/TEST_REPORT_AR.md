# تقرير الاختبارات — 18 نوفمبر 2026

## نتائج هذه الحزمة
- Python unit tests: **9/9 ناجحة** (`python -m unittest discover -s tests -v`).
- Node smoke/security contract tests: **21/21 ناجحة** (`cd server && npm test`).
- `node --check app.js`: ناجح.
- `node --check server/src/index.js`: ناجح.
- `node --check server/src/bootstrap-owner.js`: ناجح.
- `node --check server/scripts/migrate.js`: ناجح.
- `python -m py_compile tools/*.py`: ناجح.
- JSON parsing للـmanifest وملف اللغات: ناجح.
- `tools_validate_catalog.py` على قالب الاستيراد: ناجح بنيوياً (القالب فارغ ولا يحتوي سجلات كتب).
- اختبارات التعاقد الساكنة تشمل صلاحيات المالك والإدارة، نطاق طلبات الدعم، البلاغات، القرارات، والاستئنافات.

## ما لم يُختبر
- PostgreSQL غير متصل ببيئة التنفيذ؛ لم تُنفذ migrations على قاعدة فعلية ولم يجر اختبار تكامل SQL أو HTTP end-to-end.
- لم تُشغّل خدمة Node مع PostgreSQL فعلياً، ولم تُختبر عمليات البريد أو HTTPS في بيئة منشورة.
- لم يتوفر ماسح برمجيات خبيثة؛ الملفات تبقى pending حتى فحص خارجي.
- لم يُجر اختبار متصفح آلي شامل؛ يلزم اختبار الواجهات على متصفحات فعلية.

الاختبارات الناجحة تثبت الفحوص الساكنة واختبارات الأدوات المحددة أعلاه، ولا تعني أن الخدمة نُشرت أو أن قاعدة البيانات أو الخدمات الخارجية تعمل.
