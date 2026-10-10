---
name: copadam-godot
description: |
  Cop Adam (Stick Figure Fighter) - Godot 4 Android oyunu icin tam tasarim belgesi.
  Bu skill, oyunun mekaniklerini, mimarisini, mob sistemini, yukseltme sistemini
  ve Play Store yayinlama adimlarini kapsar. Herhangi bir AI model bu dosyayi
  okuyarak oyunu gelistirmeye devam edebilir.
---

# COP ADAM - GODOT 4 ANDROiD OYUNU
## TAM TASARIM VE GELISTIRME BELGESI

---

## 1. OYUN KAVRAMI

**Tur:** Side-scrolling Wave Survivor / Beat-em-up
**Platform:** Android (Google Play Store)
**Motor:** Godot 4.x (GDScript)
**Hedef Kitle:** 12+ yas, casual-mid core
**Perspektif:** 2D Yan (Side View)

### Ozet
Oyuncu sol tarafta sabit duran bir cop adam (stick figure) karakteri oynar.
Sag taraftan her dalga (wave) farkli dushman (mob) tipleri gelir.
Oyuncu saldiri, savunma ve ozel yetenek butonlariyla savasir.
Olunce veya dalga bitince kazanilan altinla yukseltme yapilir.
Amac: Mumkun oldugu kadar uzun hayatta kalmak ve yuksek dalga sayisina ulasmak.

---

## 2. KLASOR YAPISI (Project Structure)

`
copadam/
|-- project.godot
|-- export_presets.cfg
|-- assets/
|   |-- sprites/
|   |   |-- player/        (idle, attack, block, hurt, death)
|   |   |-- mobs/          (basic, fast, tank, ranged, boss)
|   |   +-- ui/            (coin, heart, shield)
|   |-- audio/
|   |   |-- sfx/           (attack, hit, block, special, coin, death, wave_clear)
|   |   +-- music/         (menu_theme, battle_theme)
|   +-- fonts/
|-- scenes/
|   |-- main_menu.tscn
|   |-- game.tscn
|   |-- upgrade_screen.tscn
|   |-- game_over.tscn
|   +-- wave_clear.tscn
+-- scripts/
    |-- globals/
    |   |-- GameManager.gd      # Autoload - global state
    |   |-- SaveManager.gd      # Autoload - kayit sistemi
    |   +-- AudioManager.gd     # Autoload - ses yonetimi
    |-- player/
    |   |-- Player.gd
    |   |-- PlayerStats.gd
    |   +-- PlayerAnimator.gd
    |-- mobs/
    |   |-- MobBase.gd
    |   |-- BasicMob.gd
    |   |-- FastMob.gd
    |   |-- TankMob.gd
    |   |-- RangedMob.gd
    |   +-- BossMob.gd
    |-- systems/
    |   |-- WaveManager.gd
    |   |-- UpgradeSystem.gd
    |   |-- CombatSystem.gd
    |   +-- CoinSystem.gd
    +-- ui/
        |-- HUD.gd
        |-- UpgradeCard.gd
        +-- DamageNumber.gd
`

---

## 3. OYUNCU MEKANIKLERI

### 3a. Temel Istatistikler (Base Stats)
`
max_hp:           100
current_hp:       100
max_armor:        0        # Yukseltme ile artar
current_armor:    0
attack_dmg:       15
attack_speed:     1.0      # saniye basina saldiri cooldown
block_reduction:  0.5      # Savunmada hasar 50 percent azalir
special_dmg:      50
special_cooldown: 8.0      # saniye
coins:            0
`

### 3b. Savas Sistemi (Combat)

SALDIRI (Attack):
- Oyuncu butona basar
- attack_speed'e gore cooldown var
- En yakin mob'a hasar verir
- Hasar = attack_dmg + random(-3, +3)

SAVUNMA (Block):
- Buton basili tutulur (hold)
- Gelen hasar = gelen_hasar * (1 - block_reduction)
- Zirh varsa once zirh dusar
- Savunma sirasinda hareket yok

OZEL YETENEK (Special):
- Cooldown dolu iken kullanilir
- Tum ekrandaki moblara AOE hasar
- Gorsel: ekran titremesi + neon blast efekti
- Cooldown = 8 saniye (yukseltme ile azalir)

HASAR HESABI:
`gdscript
func take_damage(incoming: int) -> void:
    var net = incoming
    if current_armor > 0:
        var absorb = min(current_armor, int(incoming * 0.6))
        current_armor -= absorb
        net -= absorb
    current_hp -= max(1, net)
    if current_hp <= 0:
        die()
`

---

## 4. MOB SISTEMI

### 4a. Mob Tipleri

| Mob       | HP  | Hasar | Hiz    | Odul | Aciklama                          |
|-----------|-----|-------|--------|------|-----------------------------------|
| Temel     | 40  | 10    | 60px/s |  5c  | Standart dusman                   |
| Hizli     | 20  |  7    |140px/s |  8c  | Cabuk gelir, az cani var          |
| Tank      | 150 | 20    | 30px/s | 15c  | Yavas ama cok guclu               |
| Uzaktan   | 30  | 12    | 40px/s | 12c  | Durur, mermi atar (250px menzil)  |
| Boss      | 500+| 35    | 45px/s | 80c  | Her 5 dalgada bir cikar           |

### 4b. Dalga Formulu
`gdscript
func get_wave_config(wave: int) -> Dictionary:
    return {
        "mob_count": 3 + (wave * 2),
        "hp_mult":   1.0 + (wave * 0.12),
        "dmg_mult":  1.0 + (wave * 0.08),
        "spawn_interval": max(0.5, 2.0 - (wave * 0.1)),
        "weights": {
            "basic":  max(10, 60 - wave * 3),
            "fast":   min(40, 10 + wave * 2),
            "tank":   min(30, wave * 2),
            "ranged": min(20, wave - 3) if wave > 3 else 0,
            "boss":   100 if wave % 5 == 0 else 0
        }
    }
`

### 4c. Mob AI
- BasicMob:  Duz yuruye, yaklasinca saldir (her 1.5s)
- FastMob:   Hizli kosu, yaklasinca hizli saldir (her 0.8s)
- TankMob:   Yavas yuruye, yaklasinca agir saldir (her 2.5s)
- RangedMob: 250px mesafe kor, mermi at (her 2s)
- BossMob:   Faz 1 normal, Faz 2 (HP<%50) hiz +50%

---

## 5. YUKSELTME SISTEMI

### 5a. Yukseltme Listesi

| ID              | Isim           | Max Sev | Etki                        | Temel Maliyet |
|-----------------|----------------|---------|-----------------------------|---------------|
| upgrade_hp      | Can Artisi     | 10      | +25 max HP                  | 30c           |
| upgrade_armor   | Zirh           | 8       | +15 max armor               | 40c           |
| upgrade_atk     | Saldiri Gucu   | 10      | +8 hasar                    | 35c           |
| upgrade_atk_spd | Saldiri Hizi   | 5       | -0.15s cooldown             | 60c           |
| upgrade_block   | Savunma        | 5       | +8% hasar azaltma           | 50c           |
| upgrade_special | Ozel Yetenek   | 5       | +15 sp.hasar, -1s cooldown  | 80c           |
| upgrade_gold    | Altin Kazanimi | 5       | +20% coin drop              | 45c           |
| upgrade_regen   | Can Yenileme   | 3       | Dalga bitisinde +15 HP      | 100c          |

### 5b. Maliyet Formulu
`gdscript
func get_cost(base_cost: int, level: int) -> int:
    return int(base_cost * pow(1.6, level))
`

### 5c. Ne Zaman Yukseltme Yapilir?
- Dalga tamamlandiginda (WaveClear ekraninda "Yukselt" butonu)
- Olunce GameOver ekraninda (biriken altinlarla)
- Ana menude ayri "Yukseltmeler" ekraninda
- ONEMLI: Altinlar kalicidir (olsek bile SaveManager'da saklanir)

---

## 6. KAYIT SISTEMI

`gdscript
# SaveManager.gd (Autoload)
const SAVE_PATH = "user://save.dat"

var data = {
    "coins": 0,
    "upgrades": {},    # {"upgrade_hp": 3, "upgrade_atk": 1 ...}
    "best_wave": 0,
    "total_kills": 0,
    "total_damage": 0,
    "games_played": 0
}

func save() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify(data))

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH): return
    var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
    data = JSON.parse_string(f.get_as_text())
`

---

## 7. SAHNE AKISI (Scene Flow)

`
MainMenu
  |
  |-- UpgradeScreen (yukseltmeleri gor) --> MainMenu
  |
  +-- Game
        |
        |-- [dalga bitti] --> WaveClear
        |                       |-- UpgradeScreen --> Game (sonraki dalga)
        |                       +-- Game (sonraki dalga direkt)
        |
        +-- [oyuncu oldu] --> GameOver
                                |-- UpgradeScreen --> MainMenu
                                |-- Game (tekrar oyna)
                                +-- MainMenu
`

---

## 8. ANDROID YAYIN HAZIRLIKLARI

### 8a. Godot Export Ayarlari
`
Project -> Export -> Android:
  Package:         com.SIRKET_ADI.copadam
  Version Name:    1.0.0
  Version Code:    1
  Min SDK:         21 (Android 5.0)
  Target SDK:      34
  Permissions:     VIBRATE, INTERNET
  Icon:            512x512 PNG
`

### 8b. Keystore Olusturma
`ash
keytool -genkey -v -keystore copadam.keystore ^
  -alias copadam -keyalg RSA -keysize 2048 -validity 10000
`

### 8c. Play Store Gereksinimleri Checklist
- [ ] 512x512 uygulama ikonu
- [ ] Feature graphic: 1024x500 PNG
- [ ] En az 2 ekran goruntusu (telefon)
- [ ] Kisa aciklama (80 karakter max)
- [ ] Tam aciklama (4000 karakter max)
- [ ] Gizlilik Politikasi URL (ZORUNLU)
- [ ] Icerik derecelendirmesi anketi (PEGI/ESRB)
- [ ] APK/AAB imzali dosya

### 8d. Monetizasyon (Opsiyonel)
- Google AdMob: interstitial reklam (game over ekraninda)
- "Reklam Izle > Altin Kazan" odullu reklam sistemi
- Opsiyonel: Kozmetik skin satisi (reklamsiz oyun .99)

---

## 9. YAPILACLAK LISTESI (Oncelik Sirasi)

### FAZ 1 - Temel Oyun (MVP)
- [ ] Godot 4 projesi olustur, Android export kur
- [ ] Player sahnesi: AnimatedSprite2D (stick figure cizimi)
- [ ] Player.gd: HP, armor, attack, block, special mekanikleri
- [ ] MobBase.gd: hareket + saldiri AI
- [ ] BasicMob ve FastMob olustur
- [ ] WaveManager.gd: mob spawn sistemi
- [ ] HUD.gd: HP/armor barlari, coin, dalga sayisi
- [ ] GameManager.gd (Autoload): global state yonetimi
- [ ] SaveManager.gd (Autoload): JSON kayit/yukle
- [ ] Game Over ekrani + tekrar oyna

### FAZ 2 - Icerik Genisligi
- [ ] TankMob, RangedMob ekle
- [ ] BossMob + fazlar (HP yuzdesine gore)
- [ ] Tum yukseltme sistemi (UpgradeSystem.gd)
- [ ] Yukseltme ekrani (upgrade_screen.tscn)
- [ ] Floating damage numbers (DamageNumber.gd)
- [ ] Kombo sistemi (hizli saldirilar icin x2 hasar)
- [ ] Dalga tamamlandi ekrani + animasyon

### FAZ 3 - Ses ve Gorsel Cilalama
- [ ] Ses efektleri (saldiri, hasar, olum, coin)
- [ ] Arka plan muzigi (menu + battle)
- [ ] Parcacik efektleri (kan, duman, coin)
- [ ] Kamera sarsintisi (Camera2D shake)
- [ ] Mob olum animasyonlari

### FAZ 4 - Android ve Yayin
- [ ] Android export ayarla + test et (ADB ile USB)
- [ ] Keystore imzala
- [ ] Google AdMob entegre et
- [ ] Play Store varliklari hazirla
- [ ] Gizlilik politikasi yaz
- [ ] Icerik derecelendirmesi al
- [ ] Play Console'a yukle, inceleme bekle

---

## 10. KRITIK NOTLAR

> Godot 4 Android build icin JDK 17 ve Android SDK gereklidir.
> Editor Settings -> Export -> Android kisminden yollari ayarla.

> GDScript kullan, C# gereksiz agirlik katar.

> Autoload sirasi: GameManager -> SaveManager -> AudioManager

> Mobil performans: draw_call'lari azalt, sprite atlas kullan, 60fps hedefle.

> TEST: Android Debug Bridge (adb) ile USB test yap, emulator kullanma.

> ONEMLI: index.html ve style.css dosyalari silinebilir, onlar HTML prototipti.
