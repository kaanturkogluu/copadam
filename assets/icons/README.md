# YETENEK & KATEGORİ İKON REHBERİ

Bu klasör (`assets/icons/`), yetenek ağacı düğümleri ve kategorileri için kullanacağınız ikon dosyalarını barındırır.

---

### 1. İkon Özellikleri (Tavsiye Edilen Boyut ve Format)
* **Ölçüler:** **64 x 64 piksel** veya **128 x 128 piksel** (Kare 1:1 en-boy oranı).
* **Format:** **PNG** (Transparan / Şeffaf arka planlı) veya **SVG** (Vektörel).
* **Görsel Stil:** 
  - İkonun arka planı saydam (transparent) olmalıdır.
  - Beyaz, açık gri, altın sarısı veya neon çizgili silüet ikonlar buton renkleriyle kusursuz uyum sağlar.
  - Oyun içi butonlarda otomatik olarak **36x36** / **40x40** piksel boyutuna dengeli şekilde ölçeklenir.

---

### 2. JSON Dosyasında (`data/skill_tree.json`) Kullanım

İkon dosyanızı bu klasöre attıktan sonra sadece **dosya adını** yazmanız yeterlidir.

#### Örnek Yetenek Düğümü:
```json
{
  "id": "atk_root",
  "parent": "",
  "name": "+%3 Hasar",
  "icon": "sword.png",
  "desc": "Tüm saldırı hasarını artırır",
  "base_cost": 10,
  "cost_multiplier": 1.5,
  "max_level": 10,
  "stat": "attack_dmg",
  "value": 3
}
```

#### Örnek Kategori:
```json
{
  "id": "attack",
  "name": "Atak",
  "code": "A",
  "icon": "sword.png",
  "color": "#ff5533",
  "nodes": [...]
}
```

> **Not:** Eğer bir yetenekte ikon kullanmak istemiyorsanız `"icon": ""` şeklinde boş bırakabilirsiniz; sistem otomatik olarak sadece metin gösterecektir.
