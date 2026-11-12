# -*- coding: utf-8 -*-
from docx import Document
from docx.shared import Inches, Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

doc = Document()
sec = doc.sections[0]
sec.top_margin = Inches(0.7)
sec.bottom_margin = Inches(0.7)
sec.left_margin = Inches(0.75)
sec.right_margin = Inches(0.75)
styles = doc.styles
styles["Normal"].font.name = "Arial"
styles["Normal"]._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial")
styles["Normal"].font.size = Pt(12)


def rtl(para):
    p_pr = para._p.get_or_add_pPr()
    bidi = OxmlElement("w:bidi")
    bidi.set(qn("w:val"), "1")
    p_pr.append(bidi)


def add(text, bold=False, size=12, space=6):
    para = doc.add_paragraph()
    para.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    para.paragraph_format.space_after = Pt(space)
    rtl(para)
    run = para.add_run(text)
    run.bold = bold
    run.font.size = Pt(size)
    run.font.name = "Arial"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial")
    run._element.rPr.rFonts.set(qn("w:cs"), "Arial")
    return para


def heading(text):
    para = doc.add_heading(text, level=1)
    para.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    rtl(para)
    for run in para.runs:
        run.font.name = "Arial"
        run._element.rPr.rFonts.set(qn("w:cs"), "Arial")
    return para


add("ورقة عمل: كاميرا المكفوفين في Lifex-AI", bold=True, size=18, space=4)
add("اختبار عملي على هاتف أندرويد. لا تُعلَّم خانة «نجح» إلا بعد رؤية النتيجة أو سماعها.", size=12)
add("النسخة: APK التصحيح بتاريخ 15 أكتوبر 2026، الساعة 3:18 صباحاً.", size=11, space=2)
add(
    r"الملف: C:\Users\sdsds\Downloads\Lifex-AI-source-main\Lifex-AI\lifex_ai\build\app\outputs\flutter-apk\app-debug.apk",
    size=11,
    space=10,
)

heading("قبل البدء")
add("1. ثبّت ملف APK أعلاه على الهاتف. النسخة الأقدم لا تحتوي هذا المسار.")
add("2. اسمح بالكاميرا عندما يطلبها أندرويد.")
add("3. للوصف العربي المسموع، ثبّت بيانات النطق العربي من إعدادات الهاتف إن لم تكن موجودة.")
add("4. سجّل في آخر الورقة: نجح، أو فشل، أو لم يُجرَّب. جملة على الشاشة ليست دليلاً على أن الصوت سُمع.")

heading("1. الاتصال ومفتاح Gemini")
add("المكان: مركز الذكاء الاصطناعي داخل التطبيق.", bold=True)
add("ما تفعله: افتح المركز، وأدخل مفتاح Gemini الذي تملكه، ثم اطلب ربط النموذج.")
add("ينجح التحقق إذا ظهرت كلمة «متصل» بجانب Gemini، ومن دون رسالة فشل مصادقة.")
add(
    "هذا الاتصال لنص الأسئلة. لا يرسل إطارات الكاميرا. Gemini Live غير مهيأ في هذا البناء: لا خادم يصدر رمزاً قصير العمر، ولا مفتاح داخل ملف التطبيق."
)
add("إذا لم يظهر «متصل»، اترك خانة الكاميرا السحابية فارغة. الكاميرا المحلية لا تتوقف بسبب ذلك.")

heading("2. الكاميرا المحلية أولاً")
add("المكان: الشاشة الرئيسية. العنصر الأول هو «كاميرا المكفوفين»، وعلى الحافة شريط بالاسم نفسه.", bold=True)
add("ما تفعله:")
add("• افتح الكاميرا ووافق على استخدامها داخل الصفحة.")
add("• اترك مفتاح «أوافق على سؤال سحابي عن المشهد» مغلقاً. هذا هو الوضع الافتراضي.")
add("• وجّه العدسة إلى شخص أو سيارة أو غرفة، وانتظر نحو ثانيتين بين كل وصف.")
add("ينجح التحقق إذا نطق التطبيق تصنيفاً عربياً تغير مع المشهد، مثل «تصنيف الصورة: شخص».")
add("هذا تصنيف للصورة كلها. ليس موقع الجسم، ولا مسافة، ولا دليلاً على أن الطريق آمن.")
add("إذا لم يظهر شيء واضح، الجملة المتوقعة: «لم أتمكن من تحديد المشهد بثقة» أو أن المصنّف لم يعد نتيجة. هذا فشل صادق، وليس اكتشافاً.")
add("أغلق الشبكة عن الهاتف وأعد فتح الكاميرا. يجب أن تبقى الصفحة تعمل وتعطي وصفاً محلياً أو رسالة الصمت، من دون إغلاق التطبيق.")
add("لا تنتقل الكاميرا إلى السحابة وحدها. حتى مع الموافقة، هذا البناء لا يرسل الصورة.")

heading("3. الفتح السريع")
add(
    "الرابط lifex://vision/blind-camera?mode=auto&consent=true غير مبرمج في هذه النسخة. تمريره لا يفتح الكاميرا، وفشله ليس عطلاً في العدسة.",
    bold=True,
)
add("الرابط الموجود اليوم هو lifex://assistant فقط، وهو لا يفتح كاميرا المكفوفين.")
add("الفتح المعتمد للاختبار: من الرئيسية، المس «كاميرا المكفوفين» أو الشريط الجانبي. المسّة تهتز، والاسم يقرأه TalkBack.")
add("داخل شاشة الكاميرا، لمس الشريط لا يوقف البث.")
add("ينجح التحقق إذا فُتحت شاشة الرؤية وبدأت العدسة بعد الموافقة، من الزر أو الشريط، لا من الرابط غير الموجود.")

heading("4. النطق")
add("المحرك: VoiceEngine ثم FlutterTts على الهاتف.", bold=True)
add("ما تفعله:")
add("• اسمع الوصف من مكبر الصوت، لا تكتفِ بقراءة النص على الشاشة.")
add("• غيّر المشهد. يجب ألا تُعاد الجملة نفسها بلا توقف، وألا يتكلم وصفان في اللحظة نفسها.")
add("• اضغط «استمع للأمر» ثم تكلم. الوصف لا يقاطع جلسة الاستماع.")
add("• أغلق شاشة الكاميرا. يجب أن يتوقف الكلام والعدسة.")
add("إذا لم يكن صوت عربي مثبتاً، تظهر رسالة أن بيانات النطق العربي غير مثبتة، وأن النص بقي على الشاشة. لا تُحسب هذه الرسالة نجاح سماع.")
add("ينجح التحقق فقط إذا سمعت وصفاً عربياً واضحاً ناتجاً عن المشهد أمام العدسة، وتوقف الصوت عند الخروج.")

heading("سجل النتيجة")
add("اكتب التاريخ واسم الهاتف، ثم لكل بند: نجح أو فشل أو لم يُجرَّب.")
add("1. حالة Gemini في المركز: ..............")
add("2. وصف محلي والشبكة مغلقة: ..............")
add("3. الفتح من الزر أو الشريط: ..............")
add("4. سماع عربي من المكبر، وتوقف عند الإغلاق: ..............")
add("ملاحظة مما سمعته حرفياً:")
add(" ")
add("لا تُكتب «الكاميرا مكتملة» إلا إذا نجحت البنود 2 و3 و4 على الهاتف. بند Gemini لا يغني عن العدسة.")

out = r"C:\Users\sdsds\Downloads\Lifex-AI_ورقة-عمل-كاميرا-المكفوفين.docx"
doc.save(out)
print(out)
