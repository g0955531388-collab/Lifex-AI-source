# Lifex-AI Backend (خادم مبدئي)

يغطي: الفجوات 2 (روابط الخوادم)، 4 (المزامنة السحابية)، 11 (profileId حقيقي).

التشغيل: `npm start` على المنفذ 3000. لا حزم خارجية؛ `crypto` المدمج في Node هو المستعمل، وليس حزمة npm اسمها crypto.

املأ `backend.baseUrl` في `lifex_ai/assets/config/app_config.json` بقيمة `http://عنوان-الجهاز:3000`.

الخادم ذاكرة فقط. `deviceId` ليس مصادقة. قبل الإنتاج: قاعدة دائمة، HTTPS، JWT، تشفير حمولة المزامنة، ونسخ احتياطي.
