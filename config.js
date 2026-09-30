eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhnYnBqcnJyc3dranpjcWRsY21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NjgxNzMsImV4cCI6MjEwNjM0NDE3M30.fDERIOPChNhDUe89Gg3hzlKIkNo9MKBIDwhLQWKHP_k
// ضع هنا بيانات مشروعك في Supabase (من: Project Settings ← API)
window.KIDSCV_CONFIG = {
  SUPABASE_URL: 'https://YOUR-PROJECT.supabase.co',   // Project URL
  SUPABASE_ANON_KEY: 'YOUR-ANON-PUBLIC-KEY',           // anon / publishable key (المفتاح العام فقط، وليس service_role)
  OTP_CHANNEL: 'sms',       // 'sms' رسالة نصية، أو 'whatsapp' بعد تفعيل واتساب في Twilio
  DEFAULT_COUNTRY: '974'    // رمز الدولة الافتراضي (قطر 974، الأردن 962)
};
