const sources=[
{name:"OpenITI / KITAB",desc:"نصوص تراثية وبيانات وصفية",url:"https://kitab-project.org/data/download",terms:"نصوص كتب تراثية مؤلفين وكتب"},
{name:"مؤسسة الفرقان — المكتبة الرقمية",desc:"فهارس المخطوطات والمجموعات",url:"https://digitallibrary.al-furqan.com/",terms:"مخطوطات فهارس"},
{name:"Internet Archive",desc:"بيانات الكتب والنسخ الرقمية",url:"https://archive.org/developers/",terms:"كتب نسخ رقمية بيانات"},
{name:"المكتبة الشاملة",desc:"نصوص وحزم كتب إسلامية",url:"https://shamela.amuslim.org/download.php",terms:"كتب نصوص حديث فقه"},
{name:"HathiTrust",desc:"فهرسة ونسخ رقمية بحسب الإتاحة",url:"https://www.hathitrust.org/",terms:"فهرسة طبعات مخطوطات"},
{name:"Open Library",desc:"بيانات ببليوغرافية وطبعات",url:"https://openlibrary.org/developers/api",terms:"مؤلف طبعة بيانات ببليوغرافية"}
];
const subjects=[...document.querySelectorAll('#subjectGrid button')];
const input=document.getElementById('searchInput'),list=document.getElementById('resultList'),count=document.getElementById('resultCount');
function run(q){q=(q||'').trim().toLowerCase();let found=sources.filter(s=>(s.name+' '+s.desc+' '+s.terms).toLowerCase().includes(q)||!q);list.innerHTML='';count.textContent=found.length+' مصادر مقترحة';if(!found.length){list.innerHTML='<div class="empty">ما لقينا مصدراً مطابقاً ضمن دليل المصادر الحالي. جرّب كلمة أوسع.</div>';return}found.forEach(s=>{let el=document.createElement('div');el.className='result-item';el.innerHTML=`<div><b>${s.name}</b><span>${s.desc}</span></div><a href="${s.url}" target="_blank" rel="noopener">فتح المصدر ↗</a>`;list.appendChild(el)})}
document.getElementById('searchBtn').addEventListener('click',()=>run(input.value));input.addEventListener('keydown',e=>{if(e.key==='Enter')run(input.value)});subjects.forEach(b=>b.addEventListener('click',()=>{input.value=b.dataset.term;run(b.dataset.term);document.getElementById('results').scrollIntoView()}));document.getElementById('menuBtn').addEventListener('click',()=>document.querySelector('.topbar').classList.toggle('open'));
