#!/usr/bin/env python3
"""Single source for FlexBar's UI translations.

Run `python3 Resources/translations.py` to regenerate Resources/<lang>.lproj/Localizable.strings
and InfoPlist.strings. Keys are the English UI text used in the Swift sources.
To add a language: add a column to every entry below and its code to LANGS.
"""
import os

LANGS = ["en", "tr", "hi", "de", "fr", "pt"]

STRINGS = {
    # Noise modes. "Ambient Aware" and "TalkThru" are JBL feature names and stay as they are.
    "Noise Cancelling": ["Noise Cancelling", "Gürültü Engelleme", "नॉइज़ कैंसलिंग", "Geräuschunterdrückung", "Réduction de bruit", "Cancelamento de ruído"],
    "Ambient Aware": ["Ambient Aware"] * 6,
    "TalkThru": ["TalkThru"] * 6,
    "Off": ["Off", "Kapalı", "बंद", "Aus", "Désactivé", "Desativado"],
    "Blocks outside sound.": ["Blocks outside sound.", "Dışarıdaki sesi keser.", "बाहर की आवाज़ रोकता है।", "Dämpft Geräusche von außen.", "Bloque les bruits extérieurs.", "Bloqueia o som externo."],
    "Lets you keep hearing your surroundings.": ["Lets you keep hearing your surroundings.", "Çevreni duymaya devam edersin.", "आप आसपास की आवाज़ें सुनते रहते हैं।", "Du hörst deine Umgebung weiterhin.", "Vous continuez à entendre votre environnement.", "Você continua ouvindo o ambiente."],
    "Lowers music and brings voices forward.": ["Lowers music and brings voices forward.", "Müziği kısar, konuşmayı öne çıkarır.", "संगीत धीमा करता है और बातचीत साफ़ सुनाता है।", "Senkt die Musik und hebt Stimmen hervor.", "Baisse la musique et met les voix en avant.", "Abaixa a música e destaca as vozes."],
    "No processing.": ["No processing.", "Hiçbir işlem yapılmaz.", "कोई प्रोसेसिंग नहीं।", "Keine Verarbeitung.", "Aucun traitement.", "Nenhum processamento."],

    # Errors
    "Headphones aren't connected.": ["Headphones aren't connected.", "Kulaklık bağlı değil.", "हेडफ़ोन कनेक्ट नहीं हैं।", "Kopfhörer nicht verbunden.", "Écouteurs non connectés.", "Fones de ouvido não conectados."],
    "The headphones didn't confirm the mode change.": ["The headphones didn't confirm the mode change.", "Kulaklık mod değişikliğini onaylamadı.", "हेडफ़ोन ने मोड बदलने की पुष्टि नहीं की।", "Die Kopfhörer haben den Moduswechsel nicht bestätigt.", "Les écouteurs n’ont pas confirmé le changement de mode.", "Os fones não confirmaram a mudança de modo."],
    "Control service not found.": ["Control service not found.", "Kontrol servisi bulunamadı.", "कंट्रोल सर्विस नहीं मिली।", "Steuerungsdienst nicht gefunden.", "Service de contrôle introuvable.", "Serviço de controle não encontrado."],

    # Connection states and hints
    "Bluetooth is off": ["Bluetooth is off", "Bluetooth kapalı", "ब्लूटूथ बंद है", "Bluetooth ist aus", "Bluetooth désactivé", "Bluetooth desligado"],
    "No Bluetooth permission": ["No Bluetooth permission", "Bluetooth izni yok", "ब्लूटूथ की अनुमति नहीं है", "Keine Bluetooth-Berechtigung", "Accès Bluetooth non autorisé", "Sem permissão de Bluetooth"],
    "Connecting…": ["Connecting…", "Bağlanıyor…", "कनेक्ट हो रहा है…", "Verbinden …", "Connexion…", "Conectando…"],
    "Looking for headphones…": ["Looking for headphones…", "Kulaklık aranıyor…", "हेडफ़ोन खोजे जा रहे हैं…", "Kopfhörer werden gesucht …", "Recherche des écouteurs…", "Procurando os fones…"],
    "Turn on Bluetooth in Control Center.": ["Turn on Bluetooth in Control Center.", "Kontrol Merkezi'nden Bluetooth'u aç.", "कंट्रोल सेंटर में ब्लूटूथ चालू करें।", "Aktiviere Bluetooth im Kontrollzentrum.", "Activez le Bluetooth dans le centre de contrôle.", "Ative o Bluetooth na Central de Controle."],
    "Allow FlexBar under Privacy & Security › Bluetooth.": ["Allow FlexBar under Privacy & Security › Bluetooth.", "FlexBar'a Gizlilik ve Güvenlik › Bluetooth'tan izin ver.", "गोपनीयता और सुरक्षा › ब्लूटूथ में FlexBar को अनुमति दें।", "Erlaube FlexBar unter „Datenschutz & Sicherheit“ › „Bluetooth“.", "Autorisez FlexBar dans Confidentialité et sécurité › Bluetooth.", "Permita o FlexBar em Privacidade e Segurança › Bluetooth."],
    "Open the case lid or put the earbuds in.": ["Open the case lid or put the earbuds in.", "Kutunun kapağını aç ya da kulaklıkları tak.", "केस का ढक्कन खोलें या ईयरबड्स पहनें।", "Öffne das Ladecase oder setze die Ohrhörer ein.", "Ouvrez le boîtier ou mettez les écouteurs.", "Abra o estojo ou coloque os fones."],
    "Open Bluetooth Settings": ["Open Bluetooth Settings", "Bluetooth ayarlarını aç", "ब्लूटूथ सेटिंग्स खोलें", "Bluetooth-Einstellungen öffnen", "Ouvrir les réglages Bluetooth", "Abrir ajustes de Bluetooth"],

    # Panel, footer and menu
    "Left": ["Left", "Sol", "बायाँ", "Links", "Gauche", "Esquerdo"],
    "Right": ["Right", "Sağ", "दायाँ", "Rechts", "Droite", "Direito"],
    "Case": ["Case", "Kutu", "केस", "Case", "Boîtier", "Estojo"],
    "%@ battery: %@": ["%1$@ battery: %2$@", "%1$@ pil: %2$@", "%1$@ बैटरी: %2$@", "%1$@ Akku: %2$@", "Batterie %1$@ : %2$@", "Bateria %1$@: %2$@"],
    "%@ · last known": ["%@ · last known", "%@ · son bilinen", "%@ · आख़िरी जानकारी", "%@ · zuletzt bekannt", "%@ · dernière valeur", "%@ · último valor"],
    "Case · last known": ["Case · last known", "Kutu · son bilinen", "केस · आख़िरी जानकारी", "Case · zuletzt bekannt", "Boîtier · dernière valeur", "Estojo · último valor"],
    "The case battery updates while the earbuds are in the case.": ["The case battery updates while the earbuds are in the case.", "Kutu pili, kulaklıklar kutudayken güncellenir.", "केस की बैटरी तब अपडेट होती है जब ईयरबड्स केस में हों।", "Der Akkustand des Case wird aktualisiert, solange die Ohrhörer darin liegen.", "La batterie du boîtier se met à jour quand les écouteurs y sont rangés.", "A bateria do estojo é atualizada enquanto os fones estão nele."],
    "unknown": ["unknown", "bilinmiyor", "अज्ञात", "unbekannt", "inconnue", "desconhecida"],
    "Firmware %@": ["Firmware %@", "Firmware %@", "फ़र्मवेयर %@", "Firmware %@", "Firmware %@", "Firmware %@"],
    "Refresh": ["Refresh", "Yenile", "रीफ़्रेश करें", "Aktualisieren", "Actualiser", "Atualizar"],
    "Open at Login": ["Open at Login", "Girişte aç", "लॉग इन पर खोलें", "Bei der Anmeldung öffnen", "Ouvrir à l’ouverture de session", "Abrir ao iniciar sessão"],
    "Language": ["Language", "Dil", "भाषा", "Sprache", "Langue", "Idioma"],
    "System Language": ["System Language", "Sistem dili", "सिस्टम भाषा", "Systemsprache", "Langue du système", "Idioma do sistema"],
    "Quit FlexBar": ["Quit FlexBar", "FlexBar'dan çık", "FlexBar बंद करें", "FlexBar beenden", "Quitter FlexBar", "Encerrar o FlexBar"],
    "Settings": ["Settings", "Ayarlar", "सेटिंग्स", "Einstellungen", "Réglages", "Ajustes"],

    # Noise mode details
    "Adaptive Noise Cancelling": ["Adaptive Noise Cancelling", "Uyarlanabilir Gürültü Engelleme", "अडैप्टिव नॉइज़ कैंसलिंग", "Adaptive Geräuschunterdrückung", "Réduction de bruit adaptative", "Cancelamento de ruído adaptativo"],
    "Adjusts to the noise around you.": ["Adjusts to the noise around you.", "Çevrendeki gürültüye göre ayarlanır.", "आसपास के शोर के हिसाब से बदलता है।", "Passt sich an die Umgebungsgeräusche an.", "S’adapte au bruit ambiant.", "Ajusta-se ao ruído ao seu redor."],
    "Ambient Aware level": ["Ambient Aware level", "Ambient Aware seviyesi", "Ambient Aware लेवल", "Ambient-Aware-Stufe", "Niveau Ambient Aware", "Nível do Ambient Aware"],

    # Music EQ (short: they sit side by side in a segmented control)
    "EQ": ["EQ", "EQ", "EQ", "EQ", "Égaliseur", "Equalizador"],
    "Jazz": ["Jazz", "Caz", "जैज़", "Jazz", "Jazz", "Jazz"],
    "Vocal": ["Vocal", "Vokal", "वोकल", "Gesang", "Voix", "Vocal"],
    "Bass": ["Bass", "Bas", "बेस", "Bass", "Basses", "Graves"],
    "A custom EQ from the JBL app is active.": ["A custom EQ from the JBL app is active.", "JBL uygulamasından özel bir EQ etkin.", "JBL ऐप का कस्टम EQ चालू है।", "Ein eigener EQ aus der JBL-App ist aktiv.", "Un égaliseur personnalisé de l’app JBL est actif.", "Um EQ personalizado do app JBL está ativo."],

    # Smart Audio & Video ("Smart Audio & Video" is a JBL feature name)
    "Smart Audio & Video": ["Smart Audio & Video"] * 6,
    "Normal": ["Normal", "Normal", "नॉर्मल", "Normal", "Normal", "Normal"],
    "Audio": ["Audio", "Müzik", "ऑडियो", "Audio", "Audio", "Áudio"],
    "Video": ["Video", "Video", "वीडियो", "Video", "Vidéo", "Vídeo"],
    "Balanced quality and latency.": ["Balanced quality and latency.", "Kalite ve gecikme dengeli.", "क्वालिटी और लेटेंसी में संतुलन।", "Ausgewogene Qualität und Latenz.", "Qualité et latence équilibrées.", "Qualidade e latência equilibradas."],
    "Higher quality for music.": ["Higher quality for music.", "Müzik için daha yüksek kalite.", "संगीत के लिए बेहतर क्वालिटी।", "Höhere Qualität für Musik.", "Meilleure qualité pour la musique.", "Mais qualidade para música."],
    "Lower latency for video and calls.": ["Lower latency for video and calls.", "Video ve görüşmeler için daha az gecikme.", "वीडियो और कॉल के लिए कम लेटेंसी।", "Geringere Latenz für Videos und Anrufe.", "Latence réduite pour les vidéos et les appels.", "Menos latência para vídeos e chamadas."],

    "Changing it reconnects the earbuds for a few seconds.": ["Changing it reconnects the earbuds for a few seconds.", "Değiştirince kulaklık birkaç saniyeliğine yeniden bağlanır.", "इसे बदलने पर ईयरबड्स कुछ सेकंड के लिए फिर से कनेक्ट होते हैं।", "Beim Wechsel verbinden sich die Ohrhörer für ein paar Sekunden neu.", "Le changement reconnecte les écouteurs pendant quelques secondes.", "Ao mudar, os fones se reconectam por alguns segundos."],
    "Applying Smart Audio & Video…": ["Applying Smart Audio & Video…", "Smart Audio & Video uygulanıyor…", "Smart Audio & Video लागू हो रहा है…", "Smart Audio & Video wird angewendet …", "Application de Smart Audio & Video…", "Aplicando Smart Audio & Video…"],
    "The earbuds reconnect for a few seconds to switch profiles.": ["The earbuds reconnect for a few seconds to switch profiles.", "Kulaklık profili değiştirmek için birkaç saniyeliğine yeniden bağlanıyor.", "प्रोफ़ाइल बदलने के लिए ईयरबड्स कुछ सेकंड के लिए फिर से कनेक्ट हो रहे हैं।", "Die Ohrhörer verbinden sich kurz neu, um das Profil zu wechseln.", "Les écouteurs se reconnectent quelques secondes pour changer de profil.", "Os fones estão se reconectando por alguns segundos para trocar de perfil."],

    # Find My Buds
    "Find My Buds": ["Find My Buds", "Kulaklığı bul", "ईयरबड्स खोजें", "Ohrhörer finden", "Localiser les écouteurs", "Encontrar fones"],
    "Take the earbuds out first: the beep is loud.": ["Take the earbuds out first: the beep is loud.", "Önce kulaklıkları çıkar: ses yüksek.", "पहले ईयरबड्स निकाल लें: आवाज़ तेज़ है।", "Nimm die Ohrhörer zuerst heraus: Der Ton ist laut.", "Retirez d’abord les écouteurs : le son est fort.", "Tire os fones primeiro: o som é alto."],
    "Stop": ["Stop", "Durdur", "रोकें", "Stopp", "Arrêter", "Parar"],
    "Stop beeping %@": ["Stop beeping %@", "%@ sesini durdur", "%@ की आवाज़ रोकें", "Ton stoppen: %@", "Arrêter le son : %@", "Parar som: %@"],
    "Beep %@": ["Beep %@", "%@ öttür", "%@ में आवाज़ चलाएँ", "Ton abspielen: %@", "Faire sonner : %@", "Tocar som: %@"],

    # Low battery alerts
    "Low Battery Alerts": ["Low Battery Alerts", "Düşük pil bildirimi", "कम बैटरी अलर्ट", "Warnung bei niedrigem Akku", "Alertes de batterie faible", "Alertas de bateria fraca"],
    "Left earbud battery is at %@.": ["Left earbud battery is at %@.", "Sol kulaklığın pili %@.", "बाएँ ईयरबड की बैटरी %@ है।", "Der linke Ohrhörer hat noch %@ Akku.", "La batterie de l’écouteur gauche est à %@.", "A bateria do fone esquerdo está em %@."],
    "Right earbud battery is at %@.": ["Right earbud battery is at %@.", "Sağ kulaklığın pili %@.", "दाएँ ईयरबड की बैटरी %@ है।", "Der rechte Ohrhörer hat noch %@ Akku.", "La batterie de l’écouteur droit est à %@.", "A bateria do fone direito está em %@."],

    # Connect card
    "Connected": ["Connected", "Bağlandı", "कनेक्ट हो गया", "Verbunden", "Connecté", "Conectado"],
    "Active mode": ["Active mode", "Etkin mod", "सक्रिय मोड", "Aktiver Modus", "Mode actif", "Modo ativo"],
}

INFO_PLIST = {
    "NSBluetoothAlwaysUsageDescription": [
        "FlexBar uses Bluetooth to show the battery and change the noise mode of your JBL Tune Flex 2.",
        "FlexBar, JBL Tune Flex 2 kulaklığının pilini ve gürültü modunu göstermek ve değiştirmek için Bluetooth kullanır.",
        "FlexBar आपके JBL Tune Flex 2 की बैटरी दिखाने और नॉइज़ मोड बदलने के लिए ब्लूटूथ का उपयोग करता है।",
        "FlexBar verwendet Bluetooth, um den Akkustand deiner JBL Tune Flex 2 anzuzeigen und den Geräuschmodus zu ändern.",
        "FlexBar utilise le Bluetooth pour afficher la batterie de vos JBL Tune Flex 2 et changer leur mode de bruit.",
        "O FlexBar usa o Bluetooth para mostrar a bateria e mudar o modo de ruído dos seus JBL Tune Flex 2.",
    ],
}


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')


def write(path, table, index):
    with open(path, "w", encoding="utf-8") as f:
        f.write("/* Generated by Resources/translations.py. Edit that file, not this one. */\n\n")
        for key, values in table.items():
            f.write(f'"{escape(key)}" = "{escape(values[index])}";\n')


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    for i, lang in enumerate(LANGS):
        for table in (STRINGS, INFO_PLIST):
            assert all(len(v) == len(LANGS) for v in table.values()), "every entry needs one value per language"
        folder = os.path.join(here, f"{lang}.lproj")
        os.makedirs(folder, exist_ok=True)
        write(os.path.join(folder, "Localizable.strings"), STRINGS, i)
        write(os.path.join(folder, "InfoPlist.strings"), INFO_PLIST, i)
    print("wrote", ", ".join(f"{l}.lproj" for l in LANGS))


if __name__ == "__main__":
    main()
