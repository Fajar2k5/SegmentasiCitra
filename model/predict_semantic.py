"""
Modul Inferensi Semantic Segmentation (CamVid 11 Kelas) untuk Integrasi GUI MATLAB.
Model: DeepLabV3+ dengan backbone ResNet-50.

API Python yang dipertahankan (kompatibel dengan pemanggilan lama):
    from predict_semantic import predict_to_files
    res = predict_to_files("input.png", "best_deeplabv3plus_resnet50_camvid.pth",
                           "mask_out.png", "overlay_out.png")

Pemanggilan dari MATLAB (jalur utama GUI) berjalan in-process melalui pyenv:
    pyenv('Version', '/path/ke/.venv/bin/python3.12');
    py.sys.path().insert(int32(0), '/path/ke/SegmentasiCitra/model');
    m = py.importlib.import_module('predict_semantic');
    m.predict_to_files(input_png, checkpoint_pth, mask_png, overlay_png, ...
                       0.45, true, metadata_json, 'auto');

CLI tetap tersedia untuk penggunaan manual/backward compatibility:
    python predict_semantic.py input.png best.pth \
        --mask-out mask.png --overlay-out overlay.png \
        --metadata-out result.json --alpha 0.45 --device auto --json

Catatan penting:
    Persentase kelas yang dihasilkan adalah CAKUPAN AREA PIKEL (pixel coverage),
    bukan akurasi. Akurasi hanya dapat dihitung bila tersedia ground-truth.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import time
from datetime import datetime, timezone

__version__ = "1.1.0"

CLASS_NAMES = [
    "Sky", "Building", "Pole", "Road", "Pavement",
    "Tree", "SignSymbol", "Fence", "Car", "Pedestrian", "Bicyclist"
]

# Warna kelas mengikuti palette CamVid 11 kelas yang dipakai saat training.
CLASS_COLORS_LIST = [
    [128, 128, 128],  # Sky
    [128,   0,   0],  # Building
    [192, 192, 128],  # Pole
    [128,  64, 128],  # Road
    [  0,   0, 192],  # Pavement
    [128, 128,   0],  # Tree
    [192, 128, 128],  # SignSymbol
    [ 64,  64, 128],  # Fence
    [ 64,   0, 128],  # Car
    [ 64,  64,   0],  # Pedestrian
    [  0, 128, 192],  # Bicyclist
]

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

# Cache global agar model hanya dimuat satu kali per proses.
_MODEL_CACHE = {}
_MODEL_INFO_CACHE = {}

# Import berat dilakukan lazy agar `--help` dan pesan error tetap ramah
# walaupun environment Python belum lengkap.
_IMPORT_ERROR = None
_DEPS_READY = False
try:
    import cv2
    import numpy as np
    import torch
    import torch.nn.functional as F
    import segmentation_models_pytorch as smp
    _DEPS_READY = True
except ImportError as exc:  # pragma: no cover - depends on environment
    _IMPORT_ERROR = exc
    cv2 = None
    np = None
    torch = None
    F = None
    smp = None

if np is not None:
    CLASS_COLORS = np.array(CLASS_COLORS_LIST, dtype=np.uint8)
    IMAGENET_MEAN = np.array(IMAGENET_MEAN, dtype=np.float32)
    IMAGENET_STD = np.array(IMAGENET_STD, dtype=np.float32)
else:
    CLASS_COLORS = list(CLASS_COLORS_LIST)


class InferenceError(RuntimeError):
    """Kesalahan inferensi yang pesannya aman ditampilkan langsung ke pengguna."""


def _require_deps():
    if _DEPS_READY:
        return
    module = getattr(_IMPORT_ERROR, "name", None) or str(_IMPORT_ERROR)
    raise InferenceError(
        "Dependensi Python tidak lengkap: modul '%s' tidak dapat diimpor. "
        "Instal dependensi dengan perintah: python -m pip install -r model/requirements.txt"
        % module
    ) from _IMPORT_ERROR


def _utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _resolve_device(requested=None):
    """Mengembalikan torch.device dari pilihan auto/cpu/cuda."""
    _require_deps()
    requested = (requested or "auto").strip().lower()
    if requested == "auto":
        requested = "cuda" if torch.cuda.is_available() else "cpu"
    if requested == "cuda":
        if not torch.cuda.is_available():
            raise InferenceError(
                "Perangkat 'cuda' diminta, tetapi CUDA tidak tersedia. "
                "Gunakan --device cpu atau --device auto."
            )
        return torch.device("cuda")
    if requested == "cpu":
        return torch.device("cpu")
    raise InferenceError("Nilai --device tidak valid: %s (pilih auto, cpu, atau cuda)" % requested)


def _device_metadata(device):
    _require_deps()
    info = {
        "type": str(device),
        "name": platform.processor() or "CPU",
        "cuda_available": bool(torch.cuda.is_available()),
    }
    if device.type == "cuda":
        info["name"] = torch.cuda.get_device_name(device)
        try:
            info["cuda_capability"] = "%d.%d" % torch.cuda.get_device_capability(device)
        except Exception:
            pass
    return info


def _ensure_parent_dir(path):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.isdir(parent):
        os.makedirs(parent, exist_ok=True)


def _read_image(path):
    """Membaca citra dengan aman, termasuk path non-ASCII di Windows."""
    _require_deps()
    data = np.fromfile(path, dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def _write_image(path, image):
    """Menulis citra dengan aman, termasuk path non-ASCII di Windows."""
    _require_deps()
    _ensure_parent_dir(path)
    ext = os.path.splitext(path)[1] or ".png"
    ok, buffer = cv2.imencode(ext, image)
    if not ok:
        raise InferenceError("Gagal meng-encode citra keluaran: %s" % path)
    buffer.tofile(path)


def _write_json(path, payload):
    _ensure_parent_dir(path)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def load_model(weights_path, device=None):
    """
    Memuat model DeepLabV3+ ResNet-50 dari checkpoint .pth (CPU/CUDA otomatis).

    Mengembalikan tuple (model, device, img_h, img_w) seperti API lama.
    Informasi model tambahan disimpan pada _MODEL_INFO_CACHE.
    """
    weights_path = os.path.abspath(os.fspath(weights_path))
    if not os.path.isfile(weights_path):
        raise FileNotFoundError("File checkpoint tidak ditemukan: %s" % weights_path)

    _require_deps()
    resolved = _resolve_device(device)
    cache_key = (weights_path, str(resolved))
    if cache_key in _MODEL_CACHE:
        return _MODEL_CACHE[cache_key][:4]

    try:
        try:
            checkpoint = torch.load(weights_path, map_location=resolved, weights_only=False)
        except TypeError:  # torch < 2.0 tidak memiliki argumen weights_only
            checkpoint = torch.load(weights_path, map_location=resolved)
    except Exception as exc:
        raise InferenceError(
            "Checkpoint gagal dibaca (%s): %s" % (weights_path, exc)
        ) from exc

    if not isinstance(checkpoint, dict) or "model_state_dict" not in checkpoint:
        raise InferenceError(
            "Checkpoint tidak valid: kunci 'model_state_dict' tidak ditemukan di %s"
            % weights_path
        )

    img_h = int(checkpoint.get("img_height", 384))
    img_w = int(checkpoint.get("img_width", 512))

    encoder_name = str(checkpoint.get("encoder") or "resnet50")
    model = smp.DeepLabV3Plus(
        encoder_name=encoder_name,
        encoder_weights=None,
        in_channels=3,
        classes=len(CLASS_NAMES),
    )

    state_dict = checkpoint["model_state_dict"]
    if isinstance(state_dict, dict) and state_dict:
        # Dukungan checkpoint hasil DataParallel (prefix "module.").
        if any(key.startswith("module.") for key in state_dict.keys()):
            state_dict = {key[len("module."):] if key.startswith("module.") else key: value
                          for key, value in state_dict.items()}
    try:
        model.load_state_dict(state_dict)
    except Exception as exc:
        raise InferenceError(
            "Bobot checkpoint tidak cocok dengan arsitektur DeepLabV3+ ResNet-50: %s" % exc
        ) from exc

    model.to(resolved)
    model.eval()

    info = {
        "architecture": str(checkpoint.get("architecture") or "DeepLabV3+"),
        "encoder": encoder_name,
        "num_classes": len(CLASS_NAMES),
        "class_names": list(CLASS_NAMES),
        "checkpoint": weights_path,
        "checkpoint_name": os.path.basename(weights_path),
        "input_width": img_w,
        "input_height": img_h,
    }
    for source_key, target_key in (
        ("epoch", "checkpoint_epoch"),
        ("best_val_miou", "checkpoint_best_val_miou"),
        ("val_miou", "checkpoint_val_miou"),
        ("best_miou", "checkpoint_best_miou"),
    ):
        if source_key in checkpoint:
            try:
                info[target_key] = float(checkpoint[source_key])
            except (TypeError, ValueError):
                info[target_key] = str(checkpoint[source_key])

    _MODEL_CACHE[cache_key] = (model, resolved, img_h, img_w)
    _MODEL_INFO_CACHE[cache_key] = info
    return _MODEL_CACHE[cache_key]


def predict_to_files(
    image_path: str,
    weights_path: str,
    out_mask_path: str = "semantic_mask.png",
    out_overlay_path: str = "semantic_overlay.png",
    alpha: float = 0.45,
    use_tta: bool = True,
    metadata_path: str = None,
    device: str = None,
):
    """
    Menjalankan segmentasi semantik dan menyimpan mask berwarna, overlay, serta
    (opsional) metadata JSON. API parameter lama tetap dipertahankan; parameter
    metadata_path dan device bersifat opsional.

    Nilai "detected_classes_pct" adalah persentase piksel per kelas (coverage),
    BUKAN akurasi model.
    """
    total_start = time.perf_counter()

    image_path = os.path.abspath(os.fspath(image_path))
    weights_path = os.path.abspath(os.fspath(weights_path))
    out_mask_path = os.fspath(out_mask_path)
    out_overlay_path = os.fspath(out_overlay_path)
    if metadata_path is not None:
        metadata_path = os.fspath(metadata_path)

    if not os.path.isfile(image_path):
        raise FileNotFoundError("Citra tidak dapat ditemukan: %s" % image_path)
    if not os.path.isfile(weights_path):
        raise FileNotFoundError("File checkpoint tidak ditemukan: %s" % weights_path)

    try:
        alpha = float(alpha)
    except (TypeError, ValueError) as exc:
        raise ValueError("Nilai alpha overlay harus berupa angka 0..1") from exc
    if not 0.0 <= alpha <= 1.0:
        raise ValueError("Nilai alpha overlay harus berada pada rentang 0..1")

    _require_deps()

    # Baca citra lebih dahulu agar kesalahan file/gambar terdeteksi sebelum
    # memuat checkpoint model yang besar.
    img_bgr = _read_image(image_path)
    if img_bgr is None:
        raise FileNotFoundError("Citra tidak dapat dibaca (format tidak didukung/rusak): %s" % image_path)
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    orig_h, orig_w = int(img_rgb.shape[0]), int(img_rgb.shape[1])

    load_start = time.perf_counter()
    model, model_device, img_h, img_w = load_model(weights_path, device)
    load_seconds = time.perf_counter() - load_start
    model_info = _MODEL_INFO_CACHE.get((weights_path, str(model_device)), {})

    preprocess_start = time.perf_counter()
    resized = cv2.resize(img_rgb, (img_w, img_h), interpolation=cv2.INTER_LINEAR)
    norm = (resized.astype(np.float32) / 255.0 - IMAGENET_MEAN) / IMAGENET_STD
    tensor = torch.from_numpy(np.ascontiguousarray(norm.transpose(2, 0, 1))).unsqueeze(0).to(model_device)
    preprocess_seconds = time.perf_counter() - preprocess_start

    inference_start = time.perf_counter()
    with torch.no_grad():
        logits = model(tensor)
        if use_tta:
            flipped = model(torch.flip(tensor, dims=[3]))
            logits = 0.5 * (logits + torch.flip(flipped, dims=[3]))
    if model_device.type == "cuda":
        torch.cuda.synchronize(model_device)
    inference_seconds = time.perf_counter() - inference_start

    postprocess_start = time.perf_counter()
    logits_orig = F.interpolate(logits, size=(orig_h, orig_w), mode="bilinear", align_corners=False)
    pred_ids = torch.argmax(logits_orig, dim=1).squeeze(0).cpu().numpy().astype(np.uint8)

    colors = np.asarray(CLASS_COLORS, dtype=np.uint8)
    pred_rgb = colors[pred_ids]
    overlay_rgb = cv2.addWeighted(img_rgb, 1.0 - alpha, pred_rgb, alpha, 0)

    _write_image(out_mask_path, cv2.cvtColor(pred_rgb, cv2.COLOR_RGB2BGR))
    _write_image(out_overlay_path, cv2.cvtColor(overlay_rgb, cv2.COLOR_RGB2BGR))

    total_px = int(pred_ids.size)
    class_pixels = []
    class_percent = []
    classes = []
    detected = {}
    for cls_idx, cls_name in enumerate(CLASS_NAMES):
        pixels = int(np.sum(pred_ids == cls_idx))
        pct = round(float(pixels) / float(total_px) * 100.0, 2) if total_px else 0.0
        class_pixels.append(pixels)
        class_percent.append(pct)
        classes.append({
            "id": cls_idx,
            "name": cls_name,
            "color": [int(c) for c in CLASS_COLORS_LIST[cls_idx]],
            "pixels": pixels,
            "coverage_pct": pct,
        })
        if pct > 0.0:
            detected[cls_name] = pct
    postprocess_seconds = time.perf_counter() - postprocess_start

    total_seconds = time.perf_counter() - total_start
    metadata = {
        "ok": True,
        "tool": {
            "name": "predict_semantic.py",
            "version": __version__,
            "generated_at_utc": _utc_now(),
        },
        "coverage_note": (
            "Persentase kelas adalah cakupan area piksel (pixel coverage), "
            "BUKAN akurasi. Tidak ada ground-truth pada citra masukan."
        ),
        "image": {
            "path": image_path,
            "name": os.path.basename(image_path),
            "width": orig_w,
            "height": orig_h,
            "channels": 3,
            "total_pixels": total_px,
        },
        "model": model_info,
        "device": _device_metadata(model_device),
        "settings": {
            "tta": bool(use_tta),
            "tta_mode": "horizontal_flip_average" if use_tta else "none",
            "overlay_alpha": alpha,
            "resize_interpolation": "INTER_LINEAR",
            "input_width": img_w,
            "input_height": img_h,
        },
        "timings": {
            "model_load_seconds": round(load_seconds, 4),
            "preprocess_seconds": round(preprocess_seconds, 4),
            "inference_seconds": round(inference_seconds, 4),
            "postprocess_seconds": round(postprocess_seconds, 4),
            "total_seconds": round(total_seconds, 4),
        },
        "runtime_seconds": round(total_seconds, 4),
        "outputs": {
            "mask": os.path.abspath(os.fspath(out_mask_path)),
            "overlay": os.path.abspath(os.fspath(out_overlay_path)),
            "metadata": os.path.abspath(metadata_path) if metadata_path else None,
        },
        "classes": classes,
        "class_pixels": class_pixels,
        "class_percent": class_percent,
        "detected_classes_pct": detected,
        "system": {
            "python_version": platform.python_version(),
            "torch_version": getattr(torch, "__version__", None),
            "cuda_version": getattr(torch.version, "cuda", None),
            "opencv_version": getattr(cv2, "__version__", None),
            "numpy_version": getattr(np, "__version__", None),
            "smp_version": getattr(smp, "__version__", None),
            "platform": platform.platform(),
        },
    }

    if metadata_path:
        _write_json(metadata_path, metadata)

    return {
        # Kunci lama (backward-compatible)
        "mask_path": os.path.abspath(os.fspath(out_mask_path)),
        "overlay_path": os.path.abspath(os.fspath(out_overlay_path)),
        "detected_classes_pct": detected,
        # Kunci tambahan
        "metadata_path": os.path.abspath(metadata_path) if metadata_path else None,
        "metadata": metadata,
        "classes": classes,
        "class_pixels": class_pixels,
        "class_percent": class_percent,
        "image_width": orig_w,
        "image_height": orig_h,
        "runtime_seconds": round(total_seconds, 4),
        "device": str(model_device),
    }


def _alpha_argument(value):
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("alpha harus berupa angka 0..1") from exc
    if not 0.0 <= number <= 1.0:
        raise argparse.ArgumentTypeError("alpha harus berada pada rentang 0..1")
    return number


def build_arg_parser():
    parser = argparse.ArgumentParser(
        description=(
            "Inferensi semantic segmentation CamVid 11 kelas (DeepLabV3+ ResNet-50). "
            "Persentase kelas yang dilaporkan adalah cakupan area, bukan akurasi."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("image", help="Path citra masukan")
    parser.add_argument("weights", help="Path checkpoint .pth")
    parser.add_argument("--mask-out", default="semantic_mask.png",
                        help="Path mask berwarna keluaran (PNG)")
    parser.add_argument("--overlay-out", default="semantic_overlay.png",
                        help="Path overlay keluaran (PNG)")
    parser.add_argument("--metadata-out", default=None,
                        help="Path metadata JSON keluaran (opsional)")
    parser.add_argument("--alpha", type=_alpha_argument, default=0.45,
                        help="Alpha overlay, 0..1")
    tta_group = parser.add_mutually_exclusive_group()
    tta_group.add_argument("--tta", dest="use_tta", action="store_true",
                           help="Aktifkan test-time augmentation (flip horizontal)")
    tta_group.add_argument("--no-tta", dest="use_tta", action="store_false",
                           help="Nonaktifkan test-time augmentation")
    parser.set_defaults(use_tta=True)
    parser.add_argument("--device", choices=["auto", "cpu", "cuda"], default="auto",
                        help="Perangkat inferensi")
    parser.add_argument("--json", action="store_true",
                        help="Cetak hasil/error sebagai satu objek JSON ke stdout")
    parser.add_argument("--version", action="version", version="%(prog)s " + __version__)
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    try:
        result = predict_to_files(
            image_path=args.image,
            weights_path=args.weights,
            out_mask_path=args.mask_out,
            out_overlay_path=args.overlay_out,
            alpha=args.alpha,
            use_tta=args.use_tta,
            metadata_path=args.metadata_out,
            device=args.device,
        )
        if args.json:
            print(json.dumps({"ok": True, **result}, ensure_ascii=True, default=str))
        else:
            print("Inferensi berhasil (cakupan area, bukan akurasi).")
            print("Mask    : %s" % result["mask_path"])
            print("Overlay : %s" % result["overlay_path"])
            if result.get("metadata_path"):
                print("Metadata: %s" % result["metadata_path"])
            print("Runtime : %.3f detik (%s)" % (result["runtime_seconds"], result["device"]))
        return 0
    except Exception as exc:
        payload = {
            "ok": False,
            "error_type": type(exc).__name__,
            "message": str(exc),
            "version": __version__,
        }
        if args.json:
            print(json.dumps(payload, ensure_ascii=True))
        # Pesan manusiawi tetap ditulis ke stderr agar mudah dibaca manual.
        print("ERROR: %s" % str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
