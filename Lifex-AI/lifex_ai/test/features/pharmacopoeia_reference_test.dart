import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/medications/pharmacopoeia_reference.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/women_health/pregnancy_cv_guard.dart';

void main() {
  test('الدستور المرجعي ينبّه ولا يوقف دواء ولا يقترح بديلاً', () {
    final json = jsonDecode(
      File('lib/data/reference/global_drugs_database.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['automatic_stop_allowed'], isFalse);
    expect(json['automatic_alternative_allowed'], isFalse);
    expect(json['dosing_advice_allowed'], isFalse);

    final book = PharmacopoeiaReference.fromJson(json);
    expect(PharmacopoeiaReference.automaticStopAllowed, isFalse);
    expect(book.find('Panadol')?.genericName, 'Paracetamol');
    expect(book.find('Acetaminophen')?.genericName, 'Paracetamol');
    expect(book.find('Amoxicillin')?.genericName, 'Amoxicillin');
    expect(
      book.find('Amoxicillin / Clavulanic Acid')?.genericName,
      'Amoxicillin / Clavulanic Acid',
    );
    expect(book.find('Augmentin')?.genericName, 'Amoxicillin / Clavulanic Acid');
    expect(book.find('Fentanyl')?.genericName, 'Fentanyl');
    expect(book.find('Metformin')?.genericName, 'Metformin');
    expect(book.find('Fluconazole')?.genericName, 'Fluconazole');
    expect(book.find('Glibenclamide')?.genericName, 'Glyburide');
    expect(book.find('Paracetamol/Tramadol')?.genericName, 'Tramadol/Paracetamol');
    expect(book.find('Losartan')?.genericName, 'Losartan');
    expect(book.find('HCTZ')?.genericName, 'Hydrochlorothiazide');
    expect(book.find('Lisinopril')?.genericName, 'Lisinopril');
    expect(book.find('Acyclovir')?.genericName, 'Acyclovir');
    expect(book.find('Favipiravir/ER')?.genericName, 'Favipiravir');
    expect(
      book.find('Tenofovir disoproxil fumarate')?.genericName,
      'Tenofovir',
    );
    expect(
      book.find('Emtricitabine/Tenofovir alafenamide')?.genericName,
      'Emtricitabine/Tenofovir alafenamide',
    );
    expect(
      book.find('Sofosbuvir/Velpatasvir/Voxilaprevir')?.genericName,
      'Sofosbuvir/Velpatasvir/Voxilaprevir',
    );
    expect(book.find('Nirmatrelvir/Ritonavir')?.genericName, 'Nirmatrelvir/Ritonavir');
    expect(book.find('Digoxin')?.genericName, 'Digoxin');
    expect(book.find('Glyceryl trinitrate')?.genericName, 'Nitroglycerin');
    expect(book.find('Pantoprazole')?.genericName, 'Pantoprazole');
    expect(book.find('Carbidopa/Levodopa')?.genericName, 'Levodopa/Carbidopa');
    expect(book.find('Niacin Extended Release')?.genericName, 'Niacin');
    expect(book.find('Clotrimazole Cream')?.genericName, 'Clotrimazole');
    expect(book.find('Timolol Eye Drops')?.genericName, 'Timolol');
    expect(book.find('Diazepam')?.genericName, 'Diazepam');
    expect(book.find('Valproic acid')?.genericName, 'Valproate');
    expect(book.find('Dexmethylphenidate')?.genericName, 'Dexmethylphenidate');
    expect(book.find('Cisplatin')?.genericName, 'Cisplatin');
    expect(book.find('Fluorouracil')?.genericName, '5-Fluorouracil');
    expect(book.find('Calcium folinate')?.genericName, 'Leucovorin');
    expect(book.find('Folic Acid')?.genericName, 'Folic Acid');
    expect(book.find('Ferrous sulfate')?.genericName, 'Iron Sulfate');
    expect(book.find('Cholecalciferol')?.genericName, 'Vitamin D3');
    expect(book.find('Progesterone Vaginal Suppository')?.genericName, 'Progesterone');
    expect(book.find('Chlorhexidine Solution 4%')?.genericName, 'Chlorhexidine');
    expect(book.find('Medroxyprogesterone Acetate')?.genericName, 'Medroxyprogesterone');
    expect(book.find('Magnesium Hydroxide')?.genericName, 'Magnesium Hydroxide');
    expect(book.find('GnRH Agonist'), isNull);
    expect(book.find('Albuterol')?.genericName, 'Salbutamol');
    expect(book.find('Codeine/Phosphate')?.genericName, 'Codeine');
    expect(book.find('Budesonide/Formoterol')?.genericName, 'Budesonide/Formoterol');
    expect(book.find('Beclomethasone')?.genericName, 'Beclometasone');
    expect(book.find('Levocetirizine')?.genericName, 'Levocetirizine');
    expect(book.find('Cetirizine')?.genericName, 'Cetirizine');
    expect(book.find('Sildenafil')?.genericName, 'Sildenafil');
    expect(book.find('Prasterone')?.genericName, 'DHEA');
    expect(book.find('Vaginal Wash - Chlorhexidine')?.genericName, 'Chlorhexidine');
    expect(book.find('Fenugreek Extract')?.genericName, 'Fenugreek');
    expect(book.find('Prenatal Multivitamins'), isNull);
    expect(book.find('Quaternary Ammonium Compounds'), isNull);
    expect(book.find('Cephalexin')?.genericName, 'Cefalexin');
    final fentanyl = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Fentanyl');
    expect(fentanyl.containsKey('standard_dosages'), isFalse);
    final metformin = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Metformin');
    expect(metformin.containsKey('standard_dosages'), isFalse);
    expect('${metformin['generic_name']}'.contains('500'), isFalse);
    final losartan = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Losartan');
    expect(losartan.containsKey('standard_dosages'), isFalse);
    final acyclovir = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Acyclovir');
    expect(acyclovir.containsKey('standard_dosages'), isFalse);
    final digoxin = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Digoxin');
    expect(digoxin.containsKey('standard_dosages'), isFalse);
    final ethanol = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Ethanol');
    expect(ethanol.containsKey('standard_dosages'), isFalse);
    expect('${ethanol['generic_name']}'.contains('70'), isFalse);
    final diazepam = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Diazepam');
    expect(diazepam.containsKey('standard_dosages'), isFalse);
    final cisplatin = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Cisplatin');
    expect(cisplatin.containsKey('standard_dosages'), isFalse);
    final saline = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Normal Saline');
    expect('${saline['generic_name']}'.contains('1000'), isFalse);
    final folic = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Folic Acid');
    expect(folic.containsKey('standard_dosages'), isFalse);
    expect('${folic['generic_name']}'.contains('400'), isFalse);
    expect(folic.containsKey('purpose'), isFalse);
    final formoterol = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Formoterol');
    expect(formoterol.containsKey('standard_dosages'), isFalse);
    final sildenafil = (json['drug_categories'] as List)
        .expand((category) => (category as Map)['drugs'] as List)
        .cast<Map>()
        .firstWhere((drug) => drug['generic_name'] == 'Sildenafil');
    expect(sildenafil.containsKey('standard_dosages'), isFalse);
    expect('${sildenafil['generic_name']}'.contains('50'), isFalse);
    expect(
      (json['drug_categories'] as List).cast<Map>().any(
            (category) => category['category_name_ar'] == 'أسماء أدوية الضغط',
          ),
      isTrue,
    );

    final profile = HealthProfile(
      profileId: 'p1',
      fullName: 'اختبار',
      dateOfBirth: DateTime(1992, 4, 1),
      currentMedicationNames: ['ليزينوبريل', 'باراسيتامول', 'Ibuprofen'],
      chronicConditions: [
        ChronicConditionRecord(
          conditionName: 'قرحة هضمية',
          diagnosedAt: DateTime(2020, 1, 1),
        ),
      ],
    );

    final flags = const PregnancyCvGuard().flagsFor(
      profile,
      pharmacopoeia: book,
      gestationalWeek: 30,
    );
    final text = flags.join('\n');
    expect(text, contains('ليزينوبريل'));
    expect(text, contains('D'));
    expect(text, contains('ليست إذناً'));
    expect(text, contains('لا يوقف الدواء'));
    expect(text, contains('الثلث الثالث'));
    expect(text.contains('آمن'), isFalse);
    expect(text.contains('500mg'), isFalse);
    expect(text.contains('بديل مقترح'), isFalse);
    expect(profile.currentMedicationNames, contains('Ibuprofen'));

    final cv = book.cvCautions(profile).join('\n');
    expect(cv, contains('Ibuprofen'));
    expect(cv, contains('ليس إيقافاً'));
    expect(cv.contains('400mg'), isFalse);
  });
}
