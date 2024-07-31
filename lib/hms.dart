import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'hms_month.dart';
import 'login.dart';

class HomeMedSheet extends StatefulWidget {
  final String visitId;
  final String hn;

  const HomeMedSheet({
    Key? key,
    required this.visitId,
    required this.hn,
  }) : super(key: key);

  @override
  State<HomeMedSheet> createState() => _HomeMedSheetState();
}

class _HomeMedSheetState extends State<HomeMedSheet> {
  Map<String, dynamic>? patientDetails;
  List<dynamic>? medications;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeLocaleData();
    _fetchPatientDetails();
  }

  Future<void> _initializeLocaleData() async {
    await initializeDateFormatting('th', null);
    await initializeDateFormatting('en', null);
  }

  Future<void> _fetchPatientDetails() async {
    final url = Uri.parse('https://bpk-webapp-prd1.bdms.co.th/ApiPhamacySmartLabel/PatientDetails');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'emplid': widget.visitId, 'pass': ""});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == '200') {
          setState(() {
            patientDetails = (jsonResponse['detailsH'] as List<dynamic>?)?.first;
            medications = jsonResponse['detailsB'] as List<dynamic>?;
          });
        } else {
          _showSnackBar('Failed to load patient details: ${jsonResponse['message']}');
        }
      } else {
        _showSnackBar('Failed to load patient details');
      }
    } catch (e) {
      _showSnackBar('An error occurred while fetching patient details.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _getCurrentLanguage() {
    if (patientDetails == null || !patientDetails!.containsKey('base_communication_language_id')) {
      return 'EN';
    }
    return patientDetails!['base_communication_language_id'];
  }

  String getText(String thaiText, String englishText) {
    return _getCurrentLanguage() == 'TH' ? thaiText : englishText;
  }

  Future<void> _speak(String text) async {
    final textParts = _splitTextByLanguage(text);
    for (int i = 0; i < textParts.length; i++) {
      final part = textParts[i];
      final nextPart = i + 1 < textParts.length ? textParts[i + 1] : '';
      final language = _detectLanguage(nextPart);
      final speechText = _convertNumbers(part, language);
      await _flutterTts.setLanguage(language == 'TH' ? 'th-TH' : 'en-US');
      await _flutterTts.setSpeechRate(3.2); // Adjust speech rate here
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(speechText);
      await _flutterTts.awaitSpeakCompletion(true);
    }
  }

  String _detectLanguage(String text) {
    final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
    return thaiRegex.hasMatch(text) ? 'TH' : 'EN';
  }

  List<String> _splitTextByLanguage(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    String? currentLanguage;

    for (final char in text.split('')) {
      final charLanguage = _detectLanguage(char);
      if (currentLanguage == null || charLanguage == currentLanguage) {
        buffer.write(char);
        currentLanguage = charLanguage;
      } else {
        parts.add(buffer.toString());
        buffer.clear();
        buffer.write(char);
        currentLanguage = charLanguage;
      }
    }
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    return parts;
  }

  String _convertNumbers(String text, String language) {
    final numberRegex = RegExp(r'\d+');
    return text.splitMapJoin(
      numberRegex,
      onMatch: (m) => _numberToWords(int.parse(m.group(0)!), language),
      onNonMatch: (n) => n,
    );
  }

  String _numberToWords(int number, String language) {
    if (language == 'TH') {
      return _numberToThaiWords(number);
    } else {
      return number.toString();
    }
  }

  String _numberToThaiWords(int number) {
    final thaiNumbers = ['ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'];
    final thaiUnits = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน'];
    final buffer = StringBuffer();
    final digits = number.toString().split('').map(int.parse).toList();
    for (int i = 0; i < digits.length; i++) {
      final digit = digits[digits.length - 1 - i];
      final unit = i < thaiUnits.length ? thaiUnits[i] : '';
      if (digit != 0) {
        buffer.write('${thaiNumbers[digit]}$unit');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          getText('ใบสั่งยากลับบ้าน', 'Home Medication Sheet'),
          style: const TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginPage())),
            icon: const Icon(Icons.logout),
            color: Colors.white,
          ),
        ],
      ),
      body: patientDetails != null && medications != null
          ? SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientProfileSection(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => Functionmonth(hn: widget.hn))),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(
                getText('รายการยาย้อนหลัง', 'Previous medicine list'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            _buildMedicationSection(),
          ],
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPatientProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getText('ข้อมูลผู้ป่วย', 'Profile'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Card(
          child: ListTile(
            title: Text(
              '${patientDetails!['patient_name']}',
              style: const TextStyle(fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${getText('รหัสโรงพยาบาล', 'HN')} : ${patientDetails!['hn']}', style: const TextStyle(fontSize: 16)),
                Text('${getText('เพศ', 'Gender')} : ${patientDetails!['fix_gender_id']}', style: const TextStyle(fontSize: 16)),
                Text('${getText('วันเกิด', 'Date of birth')} : ${_formatDate(patientDetails!['birthdate'])}', style: const TextStyle(fontSize: 16)),
                Text('${getText('อายุ', 'Age')} : ${patientDetails!['age']}', style: const TextStyle(fontSize: 16)),
                Text('${getText('วันที่เข้าพบแพทย์ / เลขที่', 'Episode Date / Number')} : ${_formatDate(patientDetails!['visit_date'])} ${patientDetails!['visit_time']} ${patientDetails!['en']}', style: const TextStyle(fontSize: 16)),
                Text('${getText('การแพ้', 'Allergy')} : ${_formatAllergy(patientDetails!['drugaallergy'])}', style: const TextStyle(fontSize: 16)),
                Text('${getText('ประเภทผู้ป่วย', 'Patient Type')} : ${patientDetails!['fix_visit_type_id']}', style: const TextStyle(fontSize: 16)),
                if (patientDetails!['fix_visit_type_id'] == 'IPD') Text('${getText('ห้อง', 'Ward')} : ${patientDetails!['roombed']}', style: const TextStyle(fontSize: 16)),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () {
                      String patientDetailsText = """
                        ${patientDetails!['patient_name'] ?? getText('ไม่มีข้อมูล', 'N/A')}
                        ${getText('วันเกิด', 'Date of birth')} : ${_formatDate(patientDetails!['birthdate'])}
                        ${getText('การแพ้', 'Allergy')} : ${_formatAllergy(patientDetails!['drugaallergy'])}
                      """;
                      _speak(patientDetailsText);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return getText('ไม่มีข้อมูล', 'N/A');
    }
    try {
      final DateTime date = DateTime.parse(dateStr);
      final locale = _getCurrentLanguage() == 'TH' ? 'th' : 'en';
      return DateFormat('dd MMMM yyyy', locale).format(date);
    } catch (e) {
      return getText('ไม่สามารถแปลงวันที่ได้', 'Invalid date');
    }
  }

  String _formatAllergy(String? allergy) {
    if (allergy == null || allergy.isEmpty) {
      return getText('ปฏิเสธการแพ้ยา', 'No known drug allergies');
    }
    return allergy;
  }

  Widget _buildMedicationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getText('รายการยา', 'Medications'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medications!.length,
          itemBuilder: (context, index) {
            final medication = medications![index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMedicationImage(medication['profileimage']),
                    const SizedBox(height: 10),
                    _buildMedicationDetails(medication),
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () async {
                          String medicationText = """
                            ${medication['item_name']}
                            ${medication['th_name']}
                            ${getText('คำแนะนำ', 'Instructions')} : ${medication['instruction_text_line1']} ${medication['instruction_text_line2']} ${medication['instruction_text_line3']}
                          """;
                          if (medication['item_deacription'] != null && medication['item_deacription'].isNotEmpty) {
                            medicationText += """
                              ${getText('คำอธิบาย', 'Description')} : ${medication['item_deacription']}
                            """;
                          }
                          if (medication['item_caution'] != null && medication['item_caution'].isNotEmpty) {
                            medicationText += """
                              ${getText('คำเตือน', 'Caution')} : ${medication['item_caution']}
                            """;
                          }
                          medicationText += """
                            ${getText('ชื่อแพทย์', 'Doctor Name')} : ${medication['opddoctorname']}
                          """;
                          _speak(medicationText);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicationImage(String? base64Image) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: base64Image != null && base64Image.isNotEmpty
            ? Image.memory(
          base64Decode(base64Image),
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 150);
          },
        )
            : const Icon(Icons.image, size: 150),
      ),
    );
  }

  Widget _buildMedicationDetails(Map<String, dynamic> medication) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${medication['item_name']}',
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          '${medication['th_name']}',
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          '${getText('คำแนะนำ', 'Instructions')} : ${medication['instruction_text_line1']}',
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          '${medication['instruction_text_line2']}',
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          '${medication['instruction_text_line3']}',
          style: const TextStyle(fontSize: 16),
        ),
        if (medication['item_deacription'] != null && medication['item_deacription'].isNotEmpty)
          Text(
            '${getText('คำอธิบาย', 'Description')} : ${medication['item_deacription']}',
            style: const TextStyle(fontSize: 16),
          ),
        if (medication['item_caution'] != null && medication['item_caution'].isNotEmpty)
          Text(
            '${getText('คำเตือน', 'Caution')} : ${medication['item_caution']}',
            style: const TextStyle(fontSize: 16),
          ),
        Text(
          '${getText('ชื่อแพทย์', 'Doctor Name')} : ${medication['opddoctorname']}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
