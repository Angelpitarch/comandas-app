package __PACKAGE__

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

// Crea el canal "Comandas nuevas" con importancia ALTA: es lo que hace que el aviso
// aparezca como ventana emergente (heads-up) con sonido y vibracion, incluso con la app cerrada.
// El workflow copia este archivo sobre el MainActivity.kt que genera Flutter.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                "comandas_nuevas",
                "Comandas nuevas",
                NotificationManager.IMPORTANCE_HIGH
            )
            canal.description = "Aviso emergente cuando entra una comanda nueva"
            canal.enableVibration(true)
            canal.vibrationPattern = longArrayOf(0, 500, 250, 500)
            canal.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            val atributos = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            canal.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), atributos)
            val gestor = getSystemService(NotificationManager::class.java)
            gestor.createNotificationChannel(canal)
        }
    }
}
