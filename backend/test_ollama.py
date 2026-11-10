import requests
import json

prompt = """You are a clinical pharmacy data extractor.
Analyze the following raw OCR text extracted from a doctor's prescription.
Extract the patient information, doctor information, and prescribed medicines into strict JSON.

CRITICAL RULES:
1. ONLY extract medicines that are explicitly visible in the OCR text.
2. NEVER invent, hallucinate, or assume medicines, strengths, forms, or quantities.
3. If a field is missing, unclear, or unreadable in the text, use null (or 1 for quantity if unspecified).
4. If no medicines are present in the text, return an empty list: [] for medicines.

Return JSON in this EXACT structure:
{
  "patient": {"name": null, "age": null, "gender": null, "date": null},
  "doctor": {"name": null, "clinic": null, "registration_no": null},
  "medicines": [
    {
      "original_name": "Name as seen in text",
      "strength": "e.g. 500mg, 625mg or null",
      "dosage_form": "e.g. Tablet, Syrup, Capsule or null",
      "quantity": 10,
      "instructions": "e.g. After meals or null",
      "frequency": "e.g. Twice daily, 1+0+1 or null",
      "duration": "e.g. 5 days or null",
      "uncertain_fields": []
    }
  ],
  "unreadable_notes": []
}

OCR TEXT:
Dr. Sarah Ahmed - Shaukat Khanum Clinic
Pt: Ali Khan, Age: 34
Date: 12-Nov-2026

Rx:
1. Tab. Augmentin 625mg - 1 tab twice daily x 7 days - Qty: 14
2. Syp. Hydryllin 120ml - 2 tsp at bedtime
"""

res = requests.post(
    'http://localhost:11434/api/chat',
    json={
        'model': 'llama3.2:3b',
        'messages': [{'role': 'user', 'content': prompt}],
        'format': 'json',
        'stream': False,
        'options': {'temperature': 0.0}
    },
    timeout=180
)
print("STATUS:", res.status_code)
print(res.json()['message']['content'])
