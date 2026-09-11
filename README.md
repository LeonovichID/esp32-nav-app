# ESP32 Navigation Simulator (Flutter & OpenStreetMap)

Aplikasi perantara Android untuk mengolah rute vektor 2D dan poligon bangunan dari OpenStreetMap (OSRM & Overpass API) yang siap dikirimkan ke layar ESP32 via Bluetooth BLE.

## 🚀 Fitur Utama
* **Peta OpenStreetMap:** Memilih rute tujuan secara interaktif.
* **OSRM Routing Engine:** Mendapatkan *polyline* rute secara gratis tanpa API Key berbayar.
* **Overpass API:** Menarik poligon bangunan 2D di sekitar kendaraan.
* **ESP32 Screen Simulator:** Visualisasi garis vektor monokrom 60 FPS sebelum ditransmisikan ke hardware.

## 🛠️ Cara Build APK Tanpa PC
Proyek ini mengintegrasikan **GitHub Actions**. Setiap kali ada `git push` ke cabang utama, server GitHub akan merakit file `.apk` otomatis yang dapat diunduh di tab **Actions -> Artifacts**.
