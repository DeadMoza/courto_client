// const String apiUrl = "https://api.courto.ly/";

// to test on physical phone change url to pc ip
const String apiUrl = "http://192.168.3.180:4000/"; 

class AppFormat {

    // convert api time string into datetime to pass to formatting function (formatTime)
    static formatArabicTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      final dt = DateTime(0, 1, 1, hour, minute);
      return formatTime(dt);
    } catch (_) {
      return timeStr;
    }
  }


  // تحويل الوقت إلى صيغة عربية (ص/م)
  static String formatTime(DateTime time) {
    int hour = time.hour;
    String period = 'ص';
    if (hour >= 12) {
      period = 'م';
      if (hour > 12) hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  // تحويل التاريخ إلى صيغة عربية
  static String formatDateArabic(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

   static String formatHM(DateTime dt) =>
      "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";


  static String translateStatus(String status) {
    switch (status) {
      case "confirmed":
        return "مؤكد";
      case "pending":
        return "في انتظار الرد";
      case "unavailable":
        return "غير متاح";
      default:
        return "متاح";
    }
  }

  static String toEnglishNumbers(String input) {
  const arabicNums = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  const englishNums = ['0','1','2','3','4','5','6','7','8','9'];

  for (int i = 0; i < arabicNums.length; i++) {
    input = input.replaceAll(arabicNums[i], englishNums[i]);
  }
  return input;
}

}
