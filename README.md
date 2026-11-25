# SegmentasiCitra

Tugas 3 IF4073 Pemrosesan Citra Digital - Segmentasi Citra dengan Deteksi Tepi,
Split and Merge, dan Deep Learning.

Repositori ini berisi **GUI MATLAB** dan **modul inferensi Python** untuk
semantic segmentation menggunakan model terlatih **DeepLabV3+**
(encoder ResNet-50 atau ResNet-101) pada **11 kelas CamVid**.

## Link ke Dataset CamVid


## Fitur

- GUI MATLAB dengan navigasi tab D/B/C.
- Memilih citra masukan, Python venv, dan checkpoint model.
- Inferensi dengan model deep learning.
- Menampilkan citra masukan, mask berwarna, dan overlay.
- Pengaturan TTA (flip horizontal), alpha overlay, dan perangkat (auto/cpu/cuda).
- **Simpan Hasil** mask, overlay, dan metadata ke folder pilihan pengguna.

## Struktur Repositori

```
SegmentasiCitra/
├── SegmentasiCitraApp.m       # Entry point GUI MATLAB
├── SegmentasiCitraPython.m    # Helper pyenv dan inferensi in-process
├── CitraSegMatlab.prj         # Proyek MATLAB
├── model/
│   ├── predict_semantic.py    # Satu-satunya script inferensi + CLI + metadata JSON
│   ├── requirements.txt       # Dependensi Python
│   ├── best_deeplabv3plus_resnet101_camvid_v3.pth  # default bila ada
│   └── best_deeplabv3plus_resnet50_camvid.pth      # fallback
├── resources/                 # Metadata proyek MATLAB (generated)
└── README.md
```

## Persyaratan

### MATLAB

- MATLAB **R2021a atau lebih baru** (diuji pada R2026a dengan Python 3.12).
- Tidak memerlukan toolbox tambahan untuk komponen GUI dan pembacaan
  PNG/JPG/BMP/TIF. GUI memakai `uifigure`, `uitabgroup`, `uigridlayout`,
  dan `imread` bawaan MATLAB.
- MATLAB harus mendukung antarmuka Python in-process (`pyenv`, `py.*`).
  GUI memilih interpreter dengan `pyenv('Version', ...)` secara otomatis,
  lalu mengimpor `model/predict_semantic.py` dengan `py.importlib`.

### Python

- Python **3.9+**; disarankan 3.10-3.12 dan versi yang didukung MATLAB.
- Library: `numpy`, `opencv-python`, `torch`, `torchvision`,
  `segmentation-models-pytorch` (lihat `model/requirements.txt`).

### Model

Semua checkpoint disimpan di satu folder `model/`:

```
model/best_deeplabv3plus_resnet101_camvid_v3.pth   # default GUI (ResNet-101, 480x640)
model/best_deeplabv3plus_resnet50_camvid.pth       # fallback (ResNet-50, 384x512)
```

Skrip inferensi `model/predict_semantic.py` membaca model dengan ResNet-50atau ResNet-101.
## Setup

### 1. Siapkan Python

Dari root repositori:

```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r model/requirements.txt
```

Untuk CUDA, pasang `torch` dan `torchvision` terlebih dahulu mengikuti
petunjuk di <https://pytorch.org/get-started/locally/>, lalu:

```bash
python -m pip install -r model/requirements.txt
```

Verifikasi:

```bash
python -c "import torch, cv2, segmentation_models_pytorch; print(torch.__version__)"
python model/predict_semantic.py --help
```

### 2. Integrasi Python in-process (`pyenv`)

GUI memakai interpreter Python yang diisi di field **Python (pyenv / venv)**
dan memuatnya ke dalam proses MATLAB.

- Isi field dengan **path lengkap** ke Python di venv, misalnya
  `/home/user/SegmentasiCitra/.venv/bin/python3.12` atau
  `C:\path\ke\SegmentasiCitra\.venv\Scripts\python.exe`.
- **Jika MATLAB sudah terlanjur memuat Python lain**, MATLAB tidak dapat
  mengganti interpreter tanpa restart. GUI akan menampilkan pesan agar Anda
  menutup dan membuka ulang MATLAB, lalu langsung menjalankan GUI tanpa
  memanggil `py.*` lebih dulu. Ini juga berlaku jika Anda sudah menjalankan
  perintah Python lain di Command Window.
- Cek environment yang sedang dimuat kapan saja:

  ```matlab
  pyenv
  ```

  Untuk memilih manual sebelum membuka GUI:

  ```matlab
  pyenv('Version', '/path/ke/SegmentasiCitra/.venv/bin/python3.12');
  ```

Pilihan `pyenv` disimpan MATLAB untuk sesi berikutnya. Jika sudah benar, GUI
akan memakai environment yang sama tanpa memuat ulang interpreter.

### 3. Jalankan GUI MATLAB

Buka `CitraSegMatlab.prj` di MATLAB, lalu dari Command Window:

```matlab
SegmentasiCitraApp
```

Atau dari root repositori:

```matlab
addpath(pwd)
SegmentasiCitraApp
```

Jika proyek MATLAB sudah dibuka, root proyek otomatis berada di path.
Simpan `SegmentasiCitraPython.m` di folder yang sama dengan `SegmentasiCitraApp.m`.

## Cara Menggunakan

1. Buka tab **D - Semantic Segmentation**.
2. Klik **Pilih...** pada **Citra Masukan** dan pilih citra.
3. Isi **Python (pyenv / VENV)** dengan path lengkap Python yang memiliki
   dependensi, misalnya:
   - Linux/macOS: `/path/ke/SegmentasiCitra/.venv/bin/python3.12`
   - Windows: `C:\path\ke\SegmentasiCitra\.venv\Scripts\python.exe`
   - Nama perintah seperti `python3` juga dicari di `PATH`, tetapi path lengkap
     lebih aman karena MATLAB harus dapat menemukan `libpython` yang cocok.

   Jika folder `.venv` berada di root repositori, GUI otomatis mengisinya.
   Variabel environment `SEGMENTASI_PYTHON` juga dapat dipakai untuk menimpa
   nilai default. Jika MATLAB sudah memuat Python lain, **restart MATLAB**
   sebelum menjalankan inferensi; GUI akan menjelaskan hal ini bila terjadi.
4. Periksa **Checkpoint Model**. Default mengarah ke checkpoint ResNet-101 di
   `model/` bila tersedia; jika tidak, GUI memakai checkpoint ResNet-50 lama di
   folder yang sama.
5. Atur **TTA**, **Alpha overlay**, dan **Perangkat**.
6. Klik **Jalankan Inferensi**.
7. Lihat citra masukan, mask berwarna, dan overlay pada panel tampilan utama.
8. Gunakan **Simpan Hasil** untuk menyalin hasil ke folder pilihan.
   **Buka Output** membuka folder sementara hasil inferensi.
