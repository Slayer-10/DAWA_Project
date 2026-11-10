import asyncio
import time
from typing import List, Dict, Any, Optional
import httpx
from fastapi import APIRouter, Query

router = APIRouter(prefix="", tags=["Geocoding"])

# In-memory cache: key -> (timestamp, data)
_search_cache: Dict[str, tuple[float, List[Dict[str, Any]]]] = {}
_reverse_cache: Dict[tuple[float, float], tuple[float, Dict[str, Any]]] = {}
CACHE_TTL = 600  # 10 minutes

_rate_limit_lock = asyncio.Lock()
_last_call_time: float = 0.0

async def _throttle():
    global _last_call_time
    async with _rate_limit_lock:
        now = time.time()
        elapsed = now - _last_call_time
        if elapsed < 1.0:
            await asyncio.sleep(1.0 - elapsed)
        _last_call_time = time.time()

HEADERS = {"User-Agent": "DAWA-App/1.0"}
NOMINATIM_BASE = "https://nominatim.openstreetmap.org"

@router.get("/geocode/search")
@router.get("/api/geocode/search")
async def search_places(
    q: str = Query("", description="Search query")
) -> List[Dict[str, Any]]:
    trimmed = q.strip().lower()
    if len(trimmed) < 3:
        return []

    now = time.time()
    if trimmed in _search_cache:
        cached_time, cached_data = _search_cache[trimmed]
        if now - cached_time < CACHE_TTL:
            return cached_data

    await _throttle()
    url = f"{NOMINATIM_BASE}/search"
    params = {
        "format": "jsonv2",
        "limit": 6,
        "addressdetails": 1,
        "q": q.strip()
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url, params=params, headers=HEADERS)
            if resp.status_code != 200:
                return []
            items = resp.json()
            results = []
            for item in items:
                address = item.get("address", {})
                short = (
                    item.get("name")
                    or address.get("suburb")
                    or address.get("city")
                    or address.get("town")
                    or address.get("village")
                    or item.get("display_name", "").split(",")[0]
                )
                results.append({
                    "label": item.get("display_name", ""),
                    "short_label": short,
                    "lat": float(item["lat"]),
                    "lng": float(item["lon"]),
                })
            _search_cache[trimmed] = (now, results)
            return results
    except Exception:
        return []

@router.get("/geocode/reverse")
@router.get("/api/geocode/reverse")
async def reverse_geocode(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude")
) -> Dict[str, Any]:
    key = (round(lat, 4), round(lng, 4))
    now = time.time()
    if key in _reverse_cache:
        cached_time, cached_data = _reverse_cache[key]
        if now - cached_time < CACHE_TTL:
            return cached_data

    await _throttle()
    url = f"{NOMINATIM_BASE}/reverse"
    params = {
        "format": "jsonv2",
        "zoom": 14,
        "lat": lat,
        "lon": lng,
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url, params=params, headers=HEADERS)
            if resp.status_code != 200:
                return {"short_label": "Unknown Location", "label": ""}
            data = resp.json()
            address = data.get("address", {})
            suburb_or_city = (
                address.get("suburb")
                or address.get("city")
                or address.get("town")
                or address.get("village")
                or address.get("county")
                or ""
            )
            country = address.get("country", "")
            short_parts = [p for p in [suburb_or_city, country] if p]
            short_label = ", ".join(short_parts) or data.get("display_name", "").split(",")[0]
            result = {
                "short_label": short_label,
                "label": data.get("display_name", "")
            }
            _reverse_cache[key] = (now, result)
            return result
    except Exception:
        return {"short_label": "Unknown Location", "label": ""}

