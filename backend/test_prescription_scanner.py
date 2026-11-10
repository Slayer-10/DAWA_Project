import os
import sys
import unittest
import requests
from PIL import Image, ImageDraw, ImageFont

# Add backend directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.config import settings
from app.services.ocr_service import (
    preprocess_image,
    run_tesseract_ocr,
    structure_prescription_with_ollama,
    process_prescription_pipeline,
)
from app.schemas.prescription import PrescriptionExtractionResponse

class TestPrescriptionScanning(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.test_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_artifacts")
        os.makedirs(cls.test_dir, exist_ok=True)

        # Image 1: Dr. Ayesha Malik - Augmentin & Hydryllin
        cls.img1_path = os.path.join(cls.test_dir, "prescription_1.png")
        img1 = Image.new("RGB", (900, 500), color=(255, 255, 255))
        d1 = ImageDraw.Draw(img1)
        text1 = (
            "DAWA CLINIC & HEALTHCARE\n"
            "Dr. Ayesha Malik, MBBS, FCPS\n"
            "Services Hospital Lahore - Reg # PMDC-44219\n"
            "--------------------------------------------------\n"
            "Patient: Usman Tariq       Age: 42       Gender: Male\n"
            "Date: 10-Nov-2026\n\n"
            "Rx:\n"
            "1. Tab. Augmentin 625mg\n"
            "   Sig: 1 tablet twice daily x 7 days\n"
            "   Qty: 14\n\n"
            "2. Syp. Hydryllin 120ml\n"
            "   Sig: 1 teaspoon at bedtime\n"
            "   Qty: 1\n"
        )
        d1.text((30, 30), text1, fill=(0, 0, 0))
        img1.save(cls.img1_path)

        # Image 2: Dr. Bilal Siddiqui - Brufen & Risek
        cls.img2_path = os.path.join(cls.test_dir, "prescription_2.png")
        img2 = Image.new("RGB", (900, 500), color=(255, 255, 255))
        d2 = ImageDraw.Draw(img2)
        text2 = (
            "MAYO HOSPITAL LAHORE\n"
            "Dr. Bilal Siddiqui - Internal Medicine\n"
            "--------------------------------------------------\n"
            "Patient: Fatima Zahra       Age: 29       Gender: Female\n"
            "Date: 11-Nov-2026\n\n"
            "Rx:\n"
            "1. Tab. Brufen 400mg\n"
            "   Sig: 1 tablet thrice daily after meals x 5 days\n"
            "   Qty: 15\n\n"
            "2. Cap. Risek 20mg\n"
            "   Sig: 1 capsule daily before breakfast x 10 days\n"
            "   Qty: 10\n"
        )
        d2.text((30, 30), text2, fill=(0, 0, 0))
        img2.save(cls.img2_path)

        # Image 3: Unreadable image (blank / pure noise, no text)
        cls.img_unreadable_path = os.path.join(cls.test_dir, "unreadable_prescription.png")
        img_noise = Image.new("RGB", (400, 400), color=(240, 240, 240))
        d3 = ImageDraw.Draw(img_noise)
        d3.line([(10, 10), (390, 390)], fill=(200, 200, 200), width=3)
        d3.ellipse([(100, 100), (300, 300)], outline=(190, 190, 190), width=2)
        img_noise.save(cls.img_unreadable_path)

        # Image 4: Invalid corrupted file
        cls.invalid_file_path = os.path.join(cls.test_dir, "invalid_file.jpg")
        with open(cls.invalid_file_path, "wb") as f:
            f.write(b"CORRUPTED_NON_IMAGE_DATA_12345_NOT_AN_IMAGE")

    def test_01_prescription_image_1(self):
        print("\n--- Test 1: Prescription Image 1 (Augmentin & Hydryllin) ---")
        result = process_prescription_pipeline(self.img1_path)
        print(f"Provider: {result.provider_used}")
        print(f"Success: {result.success}")
        print(f"Patient: {result.patient.name}, Age: {result.patient.age}")
        print(f"Doctor: {result.doctor.name}")
        med_names = [m.original_name for m in result.medicines]
        print(f"Extracted Medicines ({len(result.medicines)}): {med_names}")
        for m in result.medicines:
            print(f"  - {m.original_name} | Strength: {m.strength} | Form: {m.dosage_form} | Qty: {m.quantity} | Freq: {m.frequency} | Dur: {m.duration}")

        self.assertTrue(result.success)
        self.assertGreaterEqual(len(result.medicines), 2)
        
        # Verify Augmentin
        has_augmentin = any("augmentin" in m.original_name.lower() for m in result.medicines)
        self.assertTrue(has_augmentin, "Augmentin must be recognized")
        
        # Verify Hydryllin
        has_hydryllin = any("hydryllin" in m.original_name.lower() for m in result.medicines)
        self.assertTrue(has_hydryllin, "Hydryllin must be recognized")
        
        # Confirm no fake/mock Panadol
        has_panadol = any("panadol" in m.original_name.lower() for m in result.medicines)
        self.assertFalse(has_panadol, "Must not inject mock Panadol")

    def test_02_prescription_image_2(self):
        print("\n--- Test 2: Prescription Image 2 (Brufen & Risek) ---")
        result = process_prescription_pipeline(self.img2_path)
        print(f"Provider: {result.provider_used}")
        print(f"Success: {result.success}")
        print(f"Patient: {result.patient.name}, Age: {result.patient.age}")
        print(f"Doctor: {result.doctor.name}")
        med_names = [m.original_name for m in result.medicines]
        print(f"Extracted Medicines ({len(result.medicines)}): {med_names}")
        for m in result.medicines:
            print(f"  - {m.original_name} | Strength: {m.strength} | Form: {m.dosage_form} | Qty: {m.quantity} | Freq: {m.frequency} | Dur: {m.duration}")

        self.assertTrue(result.success)
        self.assertGreaterEqual(len(result.medicines), 2)

        # Verify Brufen
        has_brufen = any("brufen" in m.original_name.lower() for m in result.medicines)
        self.assertTrue(has_brufen, "Brufen must be recognized")

        # Verify Risek
        has_risek = any("risek" in m.original_name.lower() for m in result.medicines)
        self.assertTrue(has_risek, "Risek must be recognized")

        # Confirm no fake/mock Panadol or Augmentin
        self.assertFalse(any("panadol" in m.original_name.lower() for m in result.medicines))
        self.assertFalse(any("augmentin" in m.original_name.lower() for m in result.medicines))

    def test_03_unreadable_image(self):
        print("\n--- Test 3: Unreadable Image ---")
        result = process_prescription_pipeline(self.img_unreadable_path)
        print(f"Success: {result.success}")
        print(f"Medicines count: {len(result.medicines)}")
        print(f"Warnings: {result.warnings}")

        self.assertFalse(result.success)
        self.assertEqual(len(result.medicines), 0, "Unreadable image must yield 0 medicines (no mock fallback)")
        self.assertTrue(len(result.warnings) > 0, "Must display an appropriate error warning")

    def test_04_invalid_file(self):
        print("\n--- Test 4: Invalid / Corrupted File ---")
        with self.assertRaises(ValueError) as ctx:
            preprocess_image(self.invalid_file_path)
        print(f"Properly caught ValueError: {ctx.exception}")
        self.assertIn("Invalid or unreadable image", str(ctx.exception))

    def test_05_ollama_unavailable(self):
        print("\n--- Test 5: Ollama Unavailable Fallback ---")
        original_base_url = settings.OLLAMA_BASE_URL
        try:
            # Point to a dead port
            settings.OLLAMA_BASE_URL = "http://localhost:59999"
            result = process_prescription_pipeline(self.img1_path)
            print(f"Success: {result.success}")
            print(f"Medicines count: {len(result.medicines)}")
            print(f"Warnings: {result.warnings}")

            self.assertFalse(result.success)
            self.assertEqual(len(result.medicines), 0, "Must NEVER return mock medicines when Ollama is down")
            self.assertTrue(any("unavailable" in w.lower() for w in result.warnings))
        finally:
            settings.OLLAMA_BASE_URL = original_base_url

if __name__ == "__main__":
    unittest.main()

