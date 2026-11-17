# Master prompt: bikin logo Mull pakai Gemini

Cara pakai: buka Gemini, pilih mode gambar (Nano Banana / Imagen), lalu salin
isi kotak di bawah dan tempel sebagai pesan. Minta 4 variasi sekaligus, pilih
yang paling kebaca waktu dikecilin.

Kalau hasilnya kurang, jangan tulis ulang dari nol — pakai bagian
"Cara minta revisi" di bawah.

---

## Prompt utama

```text
Design a mobile app icon for "Mull", a music player and downloader app.

BRAND
- Name: Mull. The icon should read as a stylized letter "M" that also suggests
  sound or playback. Do not spell out the full word.
- Personality: calm, modern, a little playful. It is a personal music app, not
  a corporate product.
- Accent color: violet #6242FB. You may use one supporting tint from the same
  family (lighter violet or a cool indigo). The mark itself is near-white
  (#F7F7FB) on violet, or violet on near-white.

FORM
- Flat vector, geometric, built from simple shapes: thick rounded strokes,
  circles, and one triangle. Uniform stroke weight.
- Generous rounded line caps. No sharp corners.
- The silhouette must stay readable at 48x48 pixels. Prioritize one clear idea
  over detail.
- Composition: centered, with clear breathing room on all four sides. Keep the
  mark inside the middle 66% of the canvas so it survives being cropped into a
  circle, a squircle, or a rounded square.
- Square canvas, 1024x1024.

WHAT TO EXPLORE (give me different takes, not variations of one)
1. An "M" whose two peaks are drawn as sound-wave arcs.
2. An "M" where the middle valley becomes a play triangle.
3. An "M" built from vertical equalizer bars of varying heights.
4. An "M" drawn as one continuous looping ribbon, suggesting repeat.

HARD CONSTRAINTS
- Flat design only. No gradients, no drop shadows, no bevels, no glow, no
  glassmorphism, no 3D rendering, no photorealism.
- No text, no letters other than the M shape itself, no numbers.
- No musical notes, no treble clefs, no headphones, no vinyl records, no
  microphones. These are clichés and I do not want them.
- Do not imitate the branding of Spotify, YouTube Music, Apple Music, Deezer,
  SoundCloud, or Tidal. No green circle with waves, no red circle with a
  triangle, no orange cloud.
- No background scenery, no mockup of a phone, no presentation board. Just the
  icon artwork filling the canvas.

OUTPUT
- Give me 4 distinct concepts, one per image.
- For each, also show the same mark at small size so I can judge legibility.
```

---

## Cara minta revisi

Kirim lanjutan ini ke Gemini, jangan mulai percakapan baru:

```text
Take concept #N. Keep the exact same shapes and proportions, change only:
- [sebut satu hal, misalnya: make the stroke weight 20% thicker]
Do not redesign it. Do not add anything new.
```

Hal yang paling sering perlu diperbaiki:

| Masalah | Yang diminta |
| --- | --- |
| Buram waktu dikecilin | `make the strokes thicker and remove the smallest details` |
| Kepotong waktu jadi lingkaran | `shrink the mark to 60% of the canvas, keep it centered` |
| Warnanya meleset | `use exactly #6242FB for the violet and #F7F7FB for the mark` |
| Kebanyakan bentuk | `reduce to at most three shapes` |
| Masih ada gradient | `flat fills only, no gradient anywhere` |

---

## Setelah dapat gambarnya

Simpan PNG 1024x1024 di `assets/logo-baru.png`, lalu bilang ke Claude. Yang
bakal dikerjakan:

1. `ic_launcher.png` lima kepadatan (48, 72, 96, 144, 192).
2. Foreground ikon adaptif Android 8+ (dikecilin ke 62%, latar violet polos).
3. Lapisan monochrome buat tema ikon Android 13+.

Yang sekarang dipakai: logo dari versi Windows (`mull-git/assets/mull.png`),
huruf M putih dengan segitiga play di tengah, latar violet.
