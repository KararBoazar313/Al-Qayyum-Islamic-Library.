# المرحلة 49 — هيكل البحوث والمصادر والإصدارات

## المنجز
- إنشاء أبواب وفصول ومباحث لكل مشروع بحثي، مع ترتيبها وإضافة محتوى أو ملاحظات.
- حفظ بيانات المصادر: النوع والعنوان والمؤلف والناشر والطبعة والجزء والصفحة والرابط والملاحظات.
- حفظ إصدار snapshot للمشروع مع هيكله ومصادره للرجوع إليه لاحقاً.
- ربط كل العمليات بملكية المشروع والحساب المصادق عليه؛ لا يمكن عرض أو تعديل مشروع مستخدم آخر.
- إضافة واجهات النماذج وعرض الهيكل والمراجع والإصدارات داخل مركز البحوث.

## API
- `GET /api/research/projects/:id/outline`
- `POST /api/research/projects/:id/sections`
- `POST /api/research/projects/:id/sources`
- `POST /api/research/projects/:id/revisions`

## قاعدة البيانات
- migration `010_research_structure_sources.sql`
- الجداول: `research_sections`, `research_sources`, `research_project_revisions`.

## الاختبارات
- `node --check app.js`
- `node --check server/src/index.js`
- `npm test --prefix server`
- `python -m pytest -q`

## المتبقي
- ربط المراجع مباشرة بسجلات الكتب والطبعات المعتمدة في فهرس المكتبة بدلاً من إدخالها يدوياً فقط.
- سجل فروق نصية متقدم بين نسخ التحقيق.
- قاعدة الحديث والأسانيد والرجال الموثقة وواجهات البحث المتخصصة.
- تطبيق migrations على قاعدة الإنتاج بعد إعداد بيانات الاتصال.
