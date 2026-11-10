import os
import re
import json
import logging
from typing import List, Dict, Any, Tuple, Optional
import requests
from PIL import Image, ImageOps, ImageEnhance, UnidentifiedImageError
import pytesseract

from app.schemas.prescription import (
    PrescriptionExtractionResponse,
    PatientInfo,
    DoctorInfo,
    ExtractedMedicine,
)
from app.core.config import settings

logger = logging.getLogger("dawa.ocr")

def configure_tesseract():
    """Configures pytesseract with the verified binary path."""
    tess_path = settings.TESSERACT_CMD
    if os.path.exists(tess_path):
        pytesseract.pytesseract.tesseract_cmd = tess_path
    else:
        logger.warning(f"Tesseract executable not found at configured path: {tess_path}")

# Initialize on import
configure_tesseract()

def preprocess_image(input_path: str) -> str:
    """
    Validates the image file and applies Pillow image enhancements for OCR:
    - Verifies file integrity
    - Orientation correction via EXIF
    - Grayscale conversion
    - Dynamic resizing preserving aspect ratio (upscaling small images for DPI, capping excessively large images)
    - Contrast enhancement for legible pen/print stroke recognition
    - Sharpness enhancement for clean character edge separation
    """
    ext = os.path.splitext(input_path)[1].lower()
    if ext == ".pdf":
        return input_path

    try:
        with Image.open(input_path) as img:
            # 1. Correct EXIF orientation
            transposed = ImageOps.exif_transpose(img)
            img = transposed if transposed is not None else img

            # 2. Convert to Grayscale
            img = img.convert("L")

            # 3. Dynamic resizing for OCR optimization
            w, h = img.size
            max_dim = max(w, h)
            if max_dim < 1200:
                scale = 1600.0 / max_dim
                img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            elif max_dim > 2800:
                scale = 2400.0 / max_dim
                img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)

            # 4. Enhance contrast for ink strokes
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.8)

            # 5. Enhance sharpness for clear font and pen edges
            sharpener = ImageEnhance.Sharpness(img)
            img = sharpener.enhance(1.4)

            # Save processed image as PNG to avoid JPEG compression artifacts on text
            proc_path = f"{os.path.splitext(input_path)[0]}_proc.png"
            img.save(proc_path, format="PNG")
            return proc_path
    except UnidentifiedImageError:
        raise ValueError("Invalid or unreadable image file. Please upload a valid JPG, PNG, or WEBP image.")
    except Exception as e:
        logger.error(f"Image preprocessing error: {e}")
        raise ValueError(f"Could not process image file: {str(e)}")

def extract_text_from_pdf(pdf_path: str) -> str:
    """Extracts text from a PDF file if uploaded."""
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

def run_tesseract_ocr(image_path: str) -> str:
    """
    Executes Tesseract OCR on the preprocessed image file.
    Extracts actual visible text from the image.
    """
    configure_tesseract()
    ext = os.path.splitext(image_path)[1].lower()
    if ext == ".pdf":
        return extract_text_from_pdf(image_path)

    try:
        with Image.open(image_path) as img:
            # First attempt: PSM 6 (uniform block of text, ideal for structured prescriptions)
            text = pytesseract.image_to_string(img, config="--oem 3 --psm 6").strip()
            # If empty or minimal characters detected, fall back to automatic page segmentation (PSM 3)
            clean_check = re.sub(r"[^A-Za-z0-9]", "", text)
            if len(clean_check) < 4:
                text_alt = pytesseract.image_to_string(img, config="--oem 3 --psm 3").strip()
                if len(re.sub(r"[^A-Za-z0-9]", "", text_alt)) > len(clean_check):
                    text = text_alt
            return text
    except Exception as e:
        logger.error(f"Tesseract OCR execution error: {e}")
        return ""

def structure_prescription_with_ollama(ocr_text: str) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Sends actual extracted OCR text to local Ollama API (llama3.2:3b).
    Structures text into strict JSON adhering to medical guidelines:
    - Never invents medicine names, strengths, dosages or quantities
    - Returns null for missing or unclear fields
    - Returns empty list if no medicines are present
    """
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
  "patient": {{
    "name": string or null,
    "age": string or null,
    "gender": string or null,
    "date": string or null
  }},
  "doctor": {{
    "name": string or null,
    "clinic": string or null,
    "registration_no": string or null
  }},
  "medicines": [
    {{
      "original_name": "Exact medicine name from text",
      "strength": "e.g. 500 mg, 625 mg, 10 mg or null",
      "dosage_form": "e.g. Tablet, Capsule, Syrup, Drop or null",
      "quantity": integer or null,
      "instructions": "e.g. Take after meals, with water or null",
      "frequency": "e.g. Once daily, Twice daily, 1+0+1, PRN or null",
      "duration": "e.g. 5 days, 1 week or null",
      "uncertain_fields": ["list", "of", "uncertain", "fields"]
    }}
  ],
  "unreadable_notes": ["any unreadable lines or annotations"]
}}

RAW OCR TEXT:
\"\"\"{ocr_text}\"\"\"
"""

    payload = {
        "model": settings.OLLAMA_MODEL,
        "messages": [
            {
                "role": "system",
                "content": "You are a clinical pharmacy OCR data extractor. You return strict JSON conforming to the requested schema. Never invent medicines or default values."
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.0
        }
    }

    try:
        response = requests.post(
            endpoint,
            json=payload,
            timeout=settings.OLLAMA_TIMEOUT
        )
        if response.status_code != 200:
            return None, f"Ollama returned HTTP {response.status_code}: {response.text[:200]}"
        
        data = response.json()
        message_content = data.get("message", {}).get("content", "").strip()
        if not message_content:
            return None, "Ollama returned an empty response."

        # Parse JSON from model
        parsed = json.loads(message_content)
        return parsed, None
    except requests.exceptions.Timeout:
        return None, f"Ollama model timed out after {settings.OLLAMA_TIMEOUT}s."
    except requests.exceptions.ConnectionError:
        return None, f"Ollama local AI service is unavailable at {settings.OLLAMA_BASE_URL}."
    except Exception as e:
        return None, f"Ollama processing error: {str(e)}"

def process_prescription_pipeline(original_image_path: str) -> PrescriptionExtractionResponse:
    """
    Main prescription scanning pipeline:
    1. Preprocesses image using Pillow (orientation, grayscale, contrast, resizing).
    2. Runs Tesseract OCR to extract actual visible text.
    3. If no readable text found, returns appropriate error notice and empty medicine list.
    4. Sends extracted text to local Ollama (llama3.2:3b) to structure into clinical JSON.
    5. If Ollama is unavailable, returns honest error warning and empty medicine list.
    6. Never returns mock or default sample medicines.
    """
    # 1. Preprocess with Pillow
    proc_image_path = preprocess_image(original_image_path)

    # 2. Extract actual visible text via Tesseract OCR
    raw_text = run_tesseract_ocr(proc_image_path)
    logger.info(f"Tesseract raw text length: {len(raw_text)} chars")

    # 3. Check for readable content
    alphanumeric_chars = re.sub(r"[^A-Za-z0-9]", "", raw_text)
    if not raw_text or len(alphanumeric_chars) < 3:
        return PrescriptionExtractionResponse(
            success=False,
            prescription_id=0,
            image_url="",
            patient=PatientInfo(),
            doctor=DoctorInfo(),
            medicines=[],
            clinical_notes=[],
            warnings=[
                "No readable text could be detected from this prescription image. "
                "Please ensure the image is clear, well-lit, and in focus, or add your medicines manually below."
            ],
            requires_patient_review=True,
            provider_used="Tesseract OCR",
            raw_text=raw_text,
        )

    # 4. Structure extracted text with Ollama
    ollama_data, ollama_err = structure_prescription_with_ollama(raw_text)

    if ollama_err or not ollama_data:
        warning_msg = (
            f"Local AI structuring note: {ollama_err}. "
            "No medicines could be automatically structured. Please review or add your medicines manually below."
        ) if ollama_err else "Could not structure prescription text. Please enter your medicines manually below."

        return PrescriptionExtractionResponse(
            success=False,
            prescription_id=0,
            image_url="",
            patient=PatientInfo(),
            doctor=DoctorInfo(),
            medicines=[],
            clinical_notes=[],
            warnings=[warning_msg],
            requires_patient_review=True,
            provider_used="Tesseract OCR (Ollama Unavailable)",
            raw_text=raw_text,
        )

    # 5. Convert Ollama data into validated schema objects
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

    medicines: List[ExtractedMedicine] = []
    for item in ollama_data.get("medicines", []):
        if not isinstance(item, dict):
            continue
        med_name = (item.get("original_name") or item.get("medicine_name") or "").strip()
        # Discard invalid or null names
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

        medicines.append(
            ExtractedMedicine(
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
            )
        )

    warnings: List[str] = []
    if not medicines:
        warnings.append(
            "No medicines could be clearly identified from the text in this image. "
            "You can add your medicines manually below to find pharmacies."
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
        provider_used="Tesseract OCR + Llama 3.2",
        raw_text=raw_text,
    )
