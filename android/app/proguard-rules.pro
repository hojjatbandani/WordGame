# قواعد R8 لنسخة الإصدار (Flutter 3.47 يفعّل التصغير وتقليص الموارد
# افتراضيا في release).
#
# flutter_local_notifications تحفظ الإشعارات المجدولة عبر GSON، وتعيد
# قراءتها بعد إعادة إقلاع الجهاز. بلا هذه القواعد تُشوَّه أسماء الحقول
# فتفشل الاستعادة بصمت وتضيع كل التذكيرات المجدولة عند أول إعادة تشغيل.
# (من README الإضافة، الإصدار 18.)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
