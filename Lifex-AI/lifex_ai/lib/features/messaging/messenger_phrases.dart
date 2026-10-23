/// عبارات المسنجر حسب لغة الجهاز. لغة غير محمّلة تبقى بالإنجليزية.
library lifex_ai.features.messaging.messenger_phrases;

class MessengerLine {
  const MessengerLine({
    required this.text,
    required this.usedCode,
    required this.fallback,
  });

  final String text;
  final String usedCode;
  final bool fallback;
}

class MessengerPhrases {
  const MessengerPhrases._();

  static const _en = {
    'title': 'Messenger',
    'chats': 'Chats',
    'groups': 'Groups',
    'calls': 'Calls',
    'meetings': 'Meetings',
    'announcements': 'Announcements',
    'blood': 'Urgent blood',
    'newGroup': 'New group',
    'send': 'Send',
    'attach': 'Attach an image',
    'hint': 'Message',
    'voice': 'Voice call',
    'video': 'Video call',
    'callNotBridged':
        'Saved on this device. No live voice or video reaches another phone.',
    'meetingNotZoom':
        'Local meeting room. It is not a Zoom call and no remote video starts.',
    'announceDenied': 'Only administration can post an announcement.',
    'announceSent': 'Announcement saved on this device for the local profiles.',
    'bloodLocalSaved':
        'Urgent blood note saved on this device. It was not sent to a blood-bank server.',
    'bloodDesk': 'Open the blood desk',
    'noPeers': 'Add another profile on this device to start a chat.',
    'needTitle': 'The group needs a name.',
    'needMember': 'Choose at least one other person.',
    'sentHere': 'Sent on this device only.',
    'blockedAdult': 'This public chat refuses sexual content.',
    'blockedProfanity': 'Profanity is refused in this chat.',
    'blockedSize': 'The file is larger than the local limit.',
    'empty': 'Write a message or attach an image.',
    'cancel': 'Cancel',
    'create': 'Create',
    'deliveredHere': 'On this device',
    'fallbackNote': 'This language is not loaded. English is shown.',
    'adminCompose': 'Announcement text',
    'localOnly':
        'Identity is the phone number. A match on this device opens the chat. SMS opens a draft you send yourself. Wi-Fi and Bluetooth have no bound peer, so the message stays here. The meeting room is local and has no remote video.',
    'urgentBlood': 'Urgent blood request',
    'nameHint': 'Group name',
    'idHint': 'Lifex ID',
    'openById': 'Open chat by ID',
    'myId': 'Your ID',
    'idMissing':
        'This ID is not on this device. Nothing was sent to another phone.',
    'idSelf': 'That is your own ID.',
    'phoneHint': 'Phone number',
    'myPhone': 'Your phone',
    'phoneMissing':
        'This number is not stored on this device. No room was opened and no network message was delivered.',
    'phoneShort': 'The number is too short to match.',
    'phoneSelf': 'That is your own number.',
    'smsDraftOpened':
        'An SMS draft was opened. You send it from the messages app. Arrival is not confirmed.',
    'smsDraftFailed': 'The SMS draft could not be opened. Nothing was sent.',
    'wifiUnbound':
        'Wi-Fi is not bound to another party. The message did not leave this device.',
    'bluetoothUnbound':
        'Bluetooth is not bound to another party. The message did not leave this device.',
    'phoneMessage': 'SMS text',
    'inviteByPhone': 'Invite this number to the local room',
    'noPhone': 'No phone number is saved on your profile.',
  };

  static const _ar = {
    'title': 'المسنجر',
    'chats': 'المحادثات',
    'groups': 'المجموعات',
    'calls': 'الاتصالات',
    'meetings': 'قاعات الاجتماع',
    'announcements': 'إعلانات الإدارة',
    'blood': 'تبرع دم عاجل',
    'newGroup': 'مجموعة جديدة',
    'send': 'إرسال',
    'attach': 'إرفاق صورة',
    'hint': 'رسالة',
    'voice': 'اتصال صوتي',
    'video': 'اتصال فيديو',
    'callNotBridged':
        'حُفظ الطلب على هذا الجهاز. لا يوجد مسار صوت أو فيديو حي يصل هاتفاً آخر.',
    'meetingNotZoom':
        'قاعة محلية على هذا الجهاز. ليست مكالمة زوم ولا يبدأ فيديو بعيد.',
    'announceDenied': 'الإعلان من الإدارة فقط.',
    'announceSent': 'حُفظ الإعلان على هذا الجهاز للملفات المحلية.',
    'bloodLocalSaved':
        'حُفظ نداء الدم العاجل على هذا الجهاز. لم يُرسل إلى خادم بنك دم.',
    'bloodDesk': 'فتح مكتب الدم',
    'noPeers': 'أضف ملفاً آخر على هذا الجهاز لبدء محادثة.',
    'needTitle': 'المجموعة تحتاج اسماً.',
    'needMember': 'اختر شخصاً واحداً على الأقل معك.',
    'sentHere': 'أُرسلت على هذا الجهاز فقط.',
    'blockedAdult': 'المحادثة العامة ترفض المحتوى الإباحي.',
    'blockedProfanity': 'الألفاظ النابية مرفوضة هنا.',
    'blockedSize': 'الملف أكبر من الحد المحلي.',
    'empty': 'اكتب رسالة أو أرفق صورة.',
    'cancel': 'إلغاء',
    'create': 'إنشاء',
    'deliveredHere': 'على هذا الجهاز',
    'fallbackNote': 'هذه اللغة غير محمّلة. تُعرض الإنجليزية.',
    'adminCompose': 'نص الإعلان',
    'localOnly':
        'التعريف برقم الهاتف. المطابقة على هذا الجهاز تفتح المحادثة. الرسالة القصيرة مسودة ترسلها أنت. الواي فاي والبلوتوث غير مربوطين بطرف فلا تغادر الرسالة. غرفة الاجتماع محلية وبلا فيديو بعيد.',
    'urgentBlood': 'طلب تبرع بالدم العاجل',
    'nameHint': 'اسم المجموعة',
    'idHint': 'معرّف Lifex',
    'openById': 'افتح المحادثة بالمعرّف',
    'myId': 'معرّفك',
    'idMissing': 'هذا المعرّف غير موجود على هذا الجهاز. لم تُرسل رسالة إلى هاتف آخر.',
    'idSelf': 'هذا معرّفك أنت.',
    'phoneHint': 'رقم الهاتف',
    'myPhone': 'رقمك',
    'phoneMissing':
        'هذا الرقم غير محفوظ على هذا الجهاز. لم تُفتح غرفة ولم تُسلَّم رسالة عبر الشبكة.',
    'phoneShort': 'الرقم أقصر من أن يُطابق.',
    'phoneSelf': 'هذا رقمك أنت.',
    'smsDraftOpened':
        'فُتحت مسودة رسالة قصيرة. الإرسال من تطبيق الرسائل. الوصول غير مؤكد.',
    'smsDraftFailed': 'تعذّر فتح مسودة الرسالة القصيرة. لم تُرسل.',
    'wifiUnbound': 'الواي فاي غير مربوط بطرف آخر. الرسالة لم تغادر الجهاز.',
    'bluetoothUnbound': 'البلوتوث غير مربوط بطرف آخر. الرسالة لم تغادر الجهاز.',
    'phoneMessage': 'نص الرسالة القصيرة',
    'inviteByPhone': 'ادعُ هذا الرقم إلى الغرفة المحلية',
    'noPhone': 'لا رقم محفوظ في ملفك.',
  };

  static const _fr = {
    'title': 'Messagerie',
    'chats': 'Discussions',
    'groups': 'Groupes',
    'calls': 'Appels',
    'meetings': 'Réunions',
    'announcements': 'Annonces',
    'blood': 'Sang urgent',
    'newGroup': 'Nouveau groupe',
    'send': 'Envoyer',
    'attach': 'Joindre une image',
    'hint': 'Message',
    'voice': 'Appel vocal',
    'video': 'Appel vidéo',
    'callNotBridged':
        'Enregistré sur cet appareil. Aucun appel vocal ou vidéo n’atteint un autre téléphone.',
    'meetingNotZoom':
        'Salle locale. Ce n’est pas un appel Zoom et aucune vidéo distante ne démarre.',
    'announceDenied': 'Seule l’administration peut publier une annonce.',
    'announceSent': 'Annonce enregistrée sur cet appareil.',
    'bloodLocalSaved':
        'Demande de sang enregistrée ici. Elle n’a pas été envoyée à un serveur.',
    'bloodDesk': 'Ouvrir le bureau du sang',
    'noPeers': 'Ajoutez un autre profil sur cet appareil.',
    'needTitle': 'Le groupe a besoin d’un nom.',
    'needMember': 'Choisissez au moins une autre personne.',
    'sentHere': 'Envoyé sur cet appareil seulement.',
    'blockedAdult': 'Ce salon refuse le contenu sexuel.',
    'blockedProfanity': 'Les insultes sont refusées.',
    'blockedSize': 'Le fichier dépasse la limite locale.',
    'empty': 'Écrivez un message ou joignez une image.',
    'cancel': 'Annuler',
    'create': 'Créer',
    'deliveredHere': 'Sur cet appareil',
    'fallbackNote': 'Cette langue n’est pas chargée. L’anglais est affiché.',
    'adminCompose': 'Texte de l’annonce',
    'localOnly':
        'L’identité est le numéro de téléphone. Une correspondance sur cet appareil ouvre la discussion. Le SMS ouvre un brouillon que vous envoyez. Le Wi-Fi et le Bluetooth n’ont pas de pair lié, donc le message reste ici. La salle est locale et sans vidéo distante.',
    'urgentBlood': 'Demande urgente de sang',
    'nameHint': 'Nom du groupe',
    'idHint': 'Identifiant Lifex',
    'openById': 'Ouvrir la discussion par identifiant',
    'myId': 'Votre identifiant',
    'idMissing':
        'Cet identifiant n’est pas sur cet appareil. Rien n’a été envoyé à un autre téléphone.',
    'idSelf': 'C’est votre propre identifiant.',
    'phoneHint': 'Numéro de téléphone',
    'myPhone': 'Votre numéro',
    'phoneMissing':
        'Ce numéro n’est pas enregistré sur cet appareil. Aucune salle ni message réseau.',
    'phoneShort': 'Le numéro est trop court pour correspondre.',
    'phoneSelf': 'C’est votre propre numéro.',
    'smsDraftOpened':
        'Un brouillon SMS est ouvert. Vous l’envoyez depuis l’application messages. L’arrivée n’est pas confirmée.',
    'smsDraftFailed': 'Le brouillon SMS n’a pas pu s’ouvrir. Rien n’a été envoyé.',
    'wifiUnbound':
        'Le Wi-Fi n’est lié à aucune autre partie. Le message n’a pas quitté l’appareil.',
    'bluetoothUnbound':
        'Le Bluetooth n’est lié à aucune autre partie. Le message n’a pas quitté l’appareil.',
    'phoneMessage': 'Texte du SMS',
    'inviteByPhone': 'Inviter ce numéro dans la salle locale',
    'noPhone': 'Aucun numéro n’est enregistré sur votre profil.',
  };

  static const tables = {'en': _en, 'ar': _ar, 'fr': _fr};

  static String primary(String languageCode) {
    final trimmed = languageCode.trim().toLowerCase();
    if (trimmed.isEmpty) return 'en';
    final cut = trimmed.split(RegExp(r'[-_]')).first;
    return cut.isEmpty ? 'en' : cut;
  }

  static bool rtl(String usedCode) =>
      usedCode == 'ar' || usedCode == 'ur' || usedCode == 'fa' || usedCode == 'he';

  static MessengerLine line(String languageCode, String key) {
    final code = primary(languageCode);
    final hit = tables[code]?[key];
    if (hit != null && hit.isNotEmpty) {
      return MessengerLine(text: hit, usedCode: code, fallback: false);
    }
    return MessengerLine(
      text: _en[key] ?? key,
      usedCode: 'en',
      fallback: code != 'en',
    );
  }
}
