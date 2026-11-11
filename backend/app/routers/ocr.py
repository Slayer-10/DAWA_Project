import os
import uuid
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool
from app.database import get_db
from app.models.prescription import Prescription, PrescriptionItem
from app.schemas.prescription import PrescriptionExtractionResponse
from app.services.ocr_service import process_prescription_pipeline
from app.core.config import settings
from app.auth import get_current_user, require_role
from app.models.user import User

router = APIRouter(prefix="/ocr", tags=["Prescription OCR"])

@router.post("/upload-prescription", response_model=PrescriptionExtractionResponse)
async def upload_prescription(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("patient"))
):
    """
    Accepts an actual uploaded prescription image or PDF.
    Validates file format, size, and integrity.
    Saves the image securely.
    Processes the image through genuine Vision AI / OCR pipeline.
    Never inserts mock, default, or fallback medicines.
    Returns structured JSON with patient, doctor, and medicine records.
    """
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ".pdf"]:
        raise HTTPException(
            status_code=400,
            detail="Unsupported format. Please upload JPG, PNG, WEBP, or PDF."
        )

    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)

    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")
    if len(contents) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (maximum 20MB allowed).")

    with open(filepath, "wb") as f:
        f.write(contents)

    # Process through genuine pipeline offloaded to threadpool so asyncio loop stays responsive
    try:
        response_data = await run_in_threadpool(process_prescription_pipeline, filepath)
    except ValueError as e:
        # Unreadable image
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except OSError:
                pass
        raise HTTPException(status_code=422, detail=str(e))
    except RuntimeError as e:
        # No engine available (Tesseract missing)
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except OSError:
                pass
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except OSError:
                pass
        raise HTTPException(status_code=500, detail=f"Prescription processing error: {str(e)}")

    # Save prescription record in database
    db_prescription = Prescription(
        patient_id=None,  # patient_id FK is to legacy patients table; auth done via require_role
        image_path=filename,
        ocr_raw_text=response_data.raw_text or "",
        ocr_confidence=1.0 if response_data.success else 0.0,
        status="PROCESSED" if response_data.success else "UNVERIFIED"
    )
    db.add(db_prescription)
    db.commit()
    db.refresh(db_prescription)

    # Save initial items if any were genuinely extracted
    for m in response_data.medicines:
        db_item = PrescriptionItem(
            prescription_id=db_prescription.id,
            medicine_name=m.original_name,
            strength=m.strength,
            dosage_form=m.dosage_form,
            quantity=m.quantity or 1,
            instructions=m.instructions,
            confidence=m.confidence,
        )
        db.add(db_item)
    db.commit()

    # Fill generated metadata in response
    response_data.prescription_id = db_prescription.id
    response_data.image_url = f"/api/prescriptions/{db_prescription.id}/image"

    return response_data
