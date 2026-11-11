import os
import re
import json
import logging
from typing import List, Dict, Any, Tuple, Optional
import requests
from PIL import Image, ImageOps, ImageEnhance, ImageFilter, UnidentifiedImageError
import pytesseract

from app.schemas.prescription import (
    PrescriptionExtractionResponse,
    PatientInfo,
    DoctorInfo,
    ExtractedMedicine,
)
from app.core.config import settings

logger = logging.getLogger("dawa.ocr")

# ---------------------------------------------------------------------------
# Tesseract setup
# ---------------------------------------------------------------------------

_COMMON_TESS_PATHS = [
    settings.TESSERACT_CMD,
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
    "/usr/bin/tesseract",
    "/usr/local/bin/tesseract",
]

def _find_tesseract() -> Optional[str]:
    for p in _COMMON_TESS_PATHS:
        if p and os.path.isfile(p):
            return p
    return None

def configure_tesseract() -> bool:
    path = _find_tesseract()
    if path:
        pytesseract.pytesseract.tesseract_cmd = path
        return True
    return False

TESSERACT_OK = configure_tesseract()
OLLAMA_CONFIGURED = bool(getattr(settings, "OLLAMA_BASE_URL", ""))

# Startup log: active engines
_active_engines = []
if TESSERACT_OK:
    _active_engines.append("Tesseract")
if OLLAMA_CONFIGURED:
    _active_engines.append("Ollama")
logger.info(f"[OCR] Active engines: {', '.join(_active_engines) if _active_engines else 'NONE'}")

# ---------------------------------------------------------------------------
# Image preprocessing
# ---------------------------------------------------------------------------

def preprocess_image(input_path: str) -> str:
    ext = os.path.splitext(input_path)[1].lower()
    if ext == ".pdf":
        return input_path
    try:
        with Image.open(input_path) as img:
            transposed = ImageOps.exif_transpose(img)
            img = transposed if transposed is not None else img
            img = img.convert("L")
            w, h = img.size
            max_dim = max(w, h)
            if max_dim < 1200:
                scale = 1600.0 / max_dim
                img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            elif max_dim > 2800:
                scale = 2400.0 / max_dim
                img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.8)
            sharpener = ImageEnhance.Sharpness(img)
            img = sharpener.enhance(1.4)
            proc_path = f"{os.path.splitext(input_path)[0]}_proc.png"
            img.save(proc_path, format="PNG")
            return proc_path
    except UnidentifiedImageError:
        raise ValueError("Invalid or unreadable image file. Please upload a valid JPG, PNG, or WEBP image.")
    except Exception as e:
        logger.error(f"Image preprocessing error: {e}")
        raise ValueError(f"Could not process image file: {str(e)}")

# ---------------------------------------------------------------------------
# PDF extraction
# ---------------------------------------------------------------------------

def extract_text_from_pdf(pdf_path: str) -> str:
    try:
        from pypdf import PdfReader
        reader = PdfReader(pdf_path)
        extracted = []
        for page in reader.pages:
            t = page.extract_text()
            if t:
                extracted.append(t)
        return "\n".join(extracted).strip()
    except Exception as e:
        logger.error(f"PDF extraction error: {e}")
        return ""

# ---------------------------------------------------------------------------
# Tesseract multi-pass OCR
# ---------------------------------------------------------------------------

def run_tesseract_ocr(image_path: str) -> str:
    if not TESSERACT_OK:
        return ""
    ext = os.path.splitext(image_path)[1].lower()
    if ext == ".pdf":
        return extract_text_from_pdf(image_path)
    try:
        with Image.open(image_path) as orig:
            best_text = ""
            best_len = 0

            def _ocr(img: Image.Image, cfg: str) -> str:
                try:
                    return pytesseract.image_to_string(img, config=cfg).strip()
                except Exception:
                    return ""

            # Pass 1: grayscale PSM 6
            g = orig.convert("L")
            t = _ocr(g, "--oem 3 --psm 6")
            l = len(re.sub(r"[^A-Za-z0-9]", "", t))
            if l > best_len:
                best_text, best_len = t, l

            # Pass 2: grayscale PSM 3
            t = _ocr(g, "--oem 3 --psm 3")
            l = len(re.sub(r"[^A-Za-z0-9]", "", t))
            if l > best_len:
                best_text, best_len = t, l

            # Pass 3: 2x upscale
            w, h = g.size
            g2 = g.resize((w * 2, h * 2), Image.Resampling.LANCZOS)
            t = _ocr(g2, "--oem 3 --psm 6")
            l = len(re.sub(r"[^A-Za-z0-9]", "", t))
            if l > best_len:
                best_text, best_len = t, l

            # Pass 4: thresholded
            import PIL.ImageOps as _pio
            thresh = g.point(lambda x: 255 if x > 128 else 0, "L")
            t = _ocr(thresh, "--oem 3 --psm 6")
            l = len(re.sub(r"[^A-Za-z0-9]", "", t))
            if l > best_len:
                best_text, best_len = t, l

            return best_text
    except Exception as e:
        logger.error(f"Tesseract OCR execution error: {e}")
        return ""

# ---------------------------------------------------------------------------
# Ollama structured extraction
# ---------------------------------------------------------------------------

def structure_prescription_with_ollama(ocr_text: str) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    if not OLLAMA_CONFIGURED:
        return None, "Ollama not configured"
    endpoint = f"{settings.OLLAMA_BASE_URL.rstrip('/')}/api/chat"
    prompt = f"""You are a clinical pharmacist AI assistant extracting structured data from doctor prescription OCR text for the DAWA Healthcare platform.
Analyze the following raw OCR text and extract all patient details, doctor details, and prescribed medicines into strict JSON.

CRITICAL EXTRACTION RULES:
1. ONLY extract medicines that are explicitly visible and legible in the OCR text.
2. NEVER invent, hallucinate, extrapolate, or guess medicines, strengths, dosage forms, or quantities.
3. If any field (strength, dosage_form, quantity, instructions, frequency, duration) is missing, not mentioned, or unclear in the text, you MUST set it to null (use 1 for quantity if unspecified).
4. If a medicine line has an uncertain or partially legible field, list that field name in "uncertain_fields".
5. If NO medicines are legible in the text, return an empty list [] for "medicines".
6. Return JSON only, matching the exact schema below, without explanation or markdown text.

REQUIRED JSON SCHEMA:
{{
  "patient": {{"name": string or null, "age": string or null, "gender": string or null, "date": string or null}},
  "doctor": {{"name": string or null, "clinic": string or null, "registration_no": string or null}},
  "medicines": [
    {{
      "original_name": "Exact medicine name from text",
      "strength": "e.g. 500 mg or null",
      "dosage_form": "e.g. Tablet, Capsule, Syrup or null",
      "quantity": integer or null,
      "instructions": "e.g. Take after meals or null",
      "frequency": "e.g. Once daily, Twice daily or null",
      "duration": "e.g. 5 days, 1 week or null",
      "uncertain_fields": ["list of uncertain fields"]
    }}
  ],
  "unreadable_notes": ["any unreadable lines"]
}}

RAW OCR TEXT:
\"\"\"{ocr_text}\"\"\"
"""
    payload = {
        "model": settings.OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": "You are a clinical pharmacy OCR data extractor. Return strict JSON only."},
            {"role": "user", "content": prompt}
        ],
        "format": "json",
        "stream": False,
        "options": {"temperature": 0.0}
    }
    try:
        response = requests.post(endpoint, json=payload, timeout=settings.OLLAMA_TIMEOUT)
        if response.status_code != 200:
            return None, f"Ollama returned HTTP {response.status_code}"
        data = response.json()
        content = data.get("message", {}).get("content", "").strip()
        if not content:
            return None, "Ollama returned empty response"
        # Retry once on bad JSON
        try:
            parsed = json.loads(content)
        except json.JSONDecodeError:
            response2 = requests.post(endpoint, json=payload, timeout=settings.OLLAMA_TIMEOUT)
            content2 = response2.json().get("message", {}).get("content", "").strip()
            try:
                parsed = json.loads(content2)
            except json.JSONDecodeError:
                return None, "Ollama returned invalid JSON after retry"
        return parsed, None
    except requests.exceptions.Timeout:
        return None, f"Ollama timed out after {settings.OLLAMA_TIMEOUT}s"
    except requests.exceptions.ConnectionError:
        return None, f"Ollama unavailable at {settings.OLLAMA_BASE_URL}"
    except Exception as e:
        return None, f"Ollama error: {str(e)}"

# ---------------------------------------------------------------------------
# Rule-based fallback parser (Tesseract only, no Ollama)
# ---------------------------------------------------------------------------

# Common OCR slip corrections
_OCR_FIXES = [
    (r"\b0 mg\b", "0mg"),
    (r"\bmp\b", "mg"),
    (r"(\d)\s+mg\b", r"\1mg"),
    (r"\bmcg\b", "mcg"),
]

_FREQ_MAP = {
    r"\bod\b": "Once daily",
    r"\bonce\s+daily\b": "Once daily",
    r"\bbd\b": "Twice daily",
    r"\btwice\s+daily\b": "Twice daily",
    r"\btds\b": "Three times daily",
    r"\bthree\s+times\s+daily\b": "Three times daily",
    r"\bqid\b": "Four times daily",
    r"\bfour\s+times\s+daily\b": "Four times daily",
    r"\bsos\b": "As needed",
    r"\bprn\b": "As needed",
    r"\b1\+0\+1\b": "Twice daily",
    r"\b1\+1\+1\b": "Three times daily",
}

_FORM_MAP = {
    r"\btab\.?\b": "Tablet",
    r"\bcap\.?\b": "Capsule",
    r"\bsyr\.?\b": "Syrup",
    r"\binj\.?\b": "Injection",
    r"\bsusp\.?\b": "Suspension",
    r"\bdrops?\b": "Drops",
    r"\bgel\b": "Gel",
    r"\bcream\b": "Cream",
}

def _apply_ocr_fixes(text: str) -> str:
    for pattern, repl in _OCR_FIXES:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)
    return text

def _extract_frequency(text: str) -> Optional[str]:
    for pattern, readable in _FREQ_MAP.items():
        if re.search(pattern, text, re.IGNORECASE):
            return readable
    return None

def _extract_duration(text: str) -> Optional[str]:
    m = re.search(r"\b(\d+)\s*(day|week|month)s?\b", text, re.IGNORECASE)
    if m:
        return f"{m.group(1)} {m.group(2)}{'s' if int(m.group(1)) > 1 else ''}"
    return None

def _extract_quantity(text: str, freq: Optional[str], dur: Optional[str]) -> int:
    # BD x 5 days = 10, TDS x 5 days = 15, etc.
    freq_num = {"Once daily": 1, "Twice daily": 2, "Three times daily": 3, "Four times daily": 4}.get(freq or "", 1)
    dur_days = 0
    if dur:
        m = re.search(r"(\d+)\s*day", dur, re.IGNORECASE)
        if m:
            dur_days = int(m.group(1))
        m = re.search(r"(\d+)\s*week", dur, re.IGNORECASE)
        if m:
            dur_days = int(m.group(1)) * 7
    if dur_days > 0 and freq_num > 0:
        return freq_num * dur_days
    # explicit quantity
    m = re.search(r"\b(?:qty|quantity|x)\s*[:=]?\s*(\d+)\b", text, re.IGNORECASE)
    if m:
        return int(m.group(1))
    return 1

def _extract_form(text: str) -> Optional[str]:
    for pattern, form in _FORM_MAP.items():
        if re.search(pattern, text, re.IGNORECASE):
            return form
    return None

def _extract_strength(text: str) -> Optional[str]:
    # Match patterns like 500mg, 625 mg, 10mcg, 0.5mg
    m = re.search(r"\b(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|%)\b", text, re.IGNORECASE)
    if m:
        return f"{m.group(1)} {m.group(2).lower()}"
    return None

# Lines that look like medicine entries: numbered list or starts with Tab/Cap/Syp
_MED_LINE_RE = re.compile(
    r"^(?:\d+[\.\)]\s*)?(?:Tab\.?\s*|Cap\.?\s*|Syr\.?\s*|Syp\.?\s*|Inj\.?\s*|Susp\.?\s*)?([A-Za-z][A-Za-z0-9\-\s]{1,40}?)(?:\s+(\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|%)))?",
    re.IGNORECASE
)

_SKIP_WORDS = {
    "prescription", "name", "age", "date", "doctor", "dr", "patient", "signature",
    "rx", "address", "clinic", "hospital", "ref", "phone", "mobile", "reg", "stamp",
    "dawa", "healthcare", "note", "total", "advice", "follow", "up",
}

# Prefix pattern to strip before extracting medicine name
_PREFIX_RE = re.compile(
    r"^(?:\d+[\.\)]\s*)?(?:Tab\.?\s+|Cap\.?\s+|Syr\.?\s+|Syp\.?\s+|Inj\.?\s+|Susp\.?\s+)?",
    re.IGNORECASE
)

def rule_based_parse(raw_text: str) -> List[ExtractedMedicine]:
    medicines: List[ExtractedMedicine] = []
    seen_names: set = set()
    lines = raw_text.splitlines()

    for line in lines:
        line = line.strip()
        if len(line) < 4:
            continue
        line_fixed = _apply_ocr_fixes(line)

        # Strip list prefix and dosage form prefix to get name
        stripped = _PREFIX_RE.sub("", line_fixed).strip()
        if len(stripped) < 3:
            continue

        # Extract strength first (may appear anywhere in line)
        strength = _extract_strength(line_fixed)
        form = _extract_form(line_fixed)

        # Name = everything before the first digit or comma after stripping prefix
        name_match = re.match(r"^([A-Za-z][A-Za-z0-9\-\s]{1,40}?)(?=\s+\d|\s*,|\s*$)", stripped)
        if not name_match:
            continue
        name_raw = name_match.group(1).strip().rstrip(".,;:")
        if len(name_raw) < 3:
            continue
        name_lower = name_raw.lower()
        if any(skip in name_lower for skip in _SKIP_WORDS):
            continue
        if name_lower in seen_names:
            continue
        seen_names.add(name_lower)

        freq = _extract_frequency(line_fixed)
        dur = _extract_duration(line_fixed)
        qty = _extract_quantity(line_fixed, freq, dur)

        uncertain = []
        if not strength:
            uncertain.append("strength")
        if not form:
            uncertain.append("dosage_form")

        medicines.append(ExtractedMedicine(
            original_name=name_raw,
            normalized_name=name_raw,
            strength=strength,
            dosage_form=form,
            quantity=qty,
            instructions=None,
            frequency=freq,
            duration=dur,
            uncertain_fields=uncertain,
            field_status="needs_verification" if uncertain else "verified_from_image",
            confidence=0.75 if uncertain else 0.85,
        ))

    return medicines

# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def process_prescription_pipeline(original_image_path: str) -> PrescriptionExtractionResponse:
    """
    Engine chain: Tesseract -> Ollama (if configured) -> rule-based fallback.
    Returns 422-equivalent ValueError on unreadable image.
    Returns 503-equivalent RuntimeError if no engine available.
    """
    if not TESSERACT_OK:
        logger.error("No OCR engine available. Tesseract not found.")
        raise RuntimeError("Prescription reader is unavailable.")

    # 1. Preprocess
    proc_image_path = preprocess_image(original_image_path)

    # 2. Tesseract OCR (multi-pass)
    raw_text = run_tesseract_ocr(proc_image_path)
    logger.info(f"OCR raw text length: {len(raw_text)} chars")

    alphanumeric = re.sub(r"[^A-Za-z0-9]", "", raw_text)
    if not raw_text or len(alphanumeric) < 3:
        raise ValueError(
            "Could not read the prescription. Try a clearer photo."
        )

    # 3. Try Ollama structured extraction
    medicines: List[ExtractedMedicine] = []
    patient = PatientInfo()
    doctor = DoctorInfo()
    provider = "Tesseract OCR"
    warnings: List[str] = []

    ollama_data, ollama_err = structure_prescription_with_ollama(raw_text)

    if ollama_data and not ollama_err:
        provider = "Tesseract OCR + Ollama"
        raw_patient = ollama_data.get("patient") or {}
        patient = PatientInfo(
            name=raw_patient.get("name"),
            age=str(raw_patient.get("age")) if raw_patient.get("age") is not None else None,
            gender=raw_patient.get("gender"),
            date=raw_patient.get("date"),
        )
        raw_doctor = ollama_data.get("doctor") or {}
        doctor = DoctorInfo(
            name=raw_doctor.get("name"),
            clinic=raw_doctor.get("clinic"),
            registration_no=raw_doctor.get("registration_no"),
        )
        for item in ollama_data.get("medicines", []):
            if not isinstance(item, dict):
                continue
            med_name = (item.get("original_name") or item.get("medicine_name") or "").strip()
            if not med_name or med_name.lower() in ["null", "none", "unknown", "n/a"]:
                continue
            uncertain = item.get("uncertain_fields") or []
            if isinstance(uncertain, str):
                uncertain = [uncertain]
            qty_val = item.get("quantity")
            parsed_qty = 1
            if isinstance(qty_val, int) and qty_val > 0:
                parsed_qty = qty_val
            elif isinstance(qty_val, str) and qty_val.isdigit():
                parsed_qty = int(qty_val)
            has_uncertainty = len(uncertain) > 0
            medicines.append(ExtractedMedicine(
                original_name=med_name,
                normalized_name=med_name,
                strength=item.get("strength"),
                dosage_form=item.get("dosage_form"),
                quantity=parsed_qty,
                instructions=item.get("instructions"),
                frequency=item.get("frequency"),
                duration=item.get("duration"),
                uncertain_fields=uncertain,
                field_status="needs_verification" if has_uncertainty else "verified_from_image",
                confidence=0.85 if has_uncertainty else 0.95,
            ))

    # 4. Rule-based fallback if Ollama failed or returned no medicines
    if not medicines:
        if ollama_err:
            logger.info(f"Ollama unavailable ({ollama_err}), using rule-based parser")
        medicines = rule_based_parse(raw_text)
        if medicines:
            provider = "Tesseract OCR + Rule-based Parser"

    if not medicines:
        warnings.append(
            "No medicines could be clearly identified in this prescription. "
            "Please add your medicines manually below."
        )

    return PrescriptionExtractionResponse(
        success=len(medicines) > 0,
        prescription_id=0,
        image_url="",
        patient=patient,
        doctor=doctor,
        medicines=medicines,
        clinical_notes=[],
        warnings=warnings,
        requires_patient_review=True,
        provider_used=provider,
        raw_text=None,  # never expose raw OCR text to client
    )
