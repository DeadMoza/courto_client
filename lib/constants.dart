const String apiUrl = "http://192.168.1.100:3000/";

class AppFormat {
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
}
