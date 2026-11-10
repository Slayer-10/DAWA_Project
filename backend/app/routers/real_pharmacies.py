import time
import math
import httpx
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Query, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.pharmacy import Pharmacy
from app.models.stock import Stock

router = APIRouter(tags=["Real Pharmacies"])

# Cache: key = (round(lat, 3), round(lng, 3)), value = (timestamp, data)
_cache: Dict[tuple, tuple] = {}
CACHE_TTL = 300  # 5 minutes in seconds

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 2)

@router.get("/pharmacies/nearby")
@router.get("/api/pharmacies/nearby")
async def get_nearby_real_pharmacies(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: int = Query(5000, description="Radius in meters")
) -> List[Dict[str, Any]]:
    cache_key = (round(lat, 3), round(lng, 3))
    now = time.time()
    if cache_key in _cache:
        cached_time, cached_data = _cache[cache_key]
        if now - cached_time < CACHE_TTL:
            return cached_data

    overpass_query = f'[out:json][timeout:10];node["amenity"="pharmacy"](around:{radius},{lat},{lng});out 20;'
    overpass_url = "https://overpass-api.de/api/interpreter"
    headers = {"User-Agent": "DAWA-Healthcare-App/1.0"}

    results: List[Dict[str, Any]] = []

    # 1. Primary: Overpass API
    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            resp = await client.post(overpass_url, data={"data": overpass_query}, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                elements = data.get("elements", [])
                for el in elements:
                    p_lat = el.get("lat")
                    p_lng = el.get("lon")
                    if p_lat is None or p_lng is None:
                        continue
                    tags = el.get("tags", {})
                    name = tags.get("name") or "Pharmacy"
                    addr_parts = [
                        tags.get("addr:housenumber"),
                        tags.get("addr:street"),
                        tags.get("addr:suburb") or tags.get("addr:district") or tags.get("addr:city")
                    ]
                    address = ", ".join([p for p in addr_parts if p]) or tags.get("address")
                    phone = tags.get("phone") or tags.get("contact:phone")
                    opening_hours = tags.get("opening_hours")
                    dist = haversine(lat, lng, p_lat, p_lng)

                    item: Dict[str, Any] = {
                        "name": name,
                        "lat": p_lat,
                        "lng": p_lng,
                        "distance_km": dist,
                    }
                    if address:
                        item["address"] = address
                    if phone:
                        item["phone"] = phone
                    if opening_hours:
                        item["opening_hours"] = opening_hours
                    results.append(item)
    except Exception:
        pass

    # 2. Fallback: OpenStreetMap Nominatim bounded amenity search
    if not results:
        try:
            delta_deg = radius / 111320.0
            min_lon = lng - delta_deg
            max_lon = lng + delta_deg
            min_lat = lat - delta_deg
            max_lat = lat + delta_deg
            nom_url = (
                f"https://nominatim.openstreetmap.org/search?format=json&amenity=pharmacy"
                f"&limit=20&viewbox={min_lon},{max_lat},{max_lon},{min_lat}&bounded=1"
            )
            async with httpx.AsyncClient(timeout=6.0) as client:
                nom_resp = await client.get(nom_url, headers=headers)
                if nom_resp.status_code == 200:
                    items = nom_resp.json()
                    for item in items:
                        try:
                            p_lat = float(item["lat"])
                            p_lng = float(item["lon"])
                        except (ValueError, KeyError):
                            continue
                        disp_name = item.get("display_name", "")
                        raw_name = disp_name.split(",")[0].strip() if disp_name else "Pharmacy"
                        name = raw_name if raw_name else "Pharmacy"
                        dist = haversine(lat, lng, p_lat, p_lng)
                        
                        results.append({
                            "name": name,
                            "lat": p_lat,
                            "lng": p_lng,
                            "address": disp_name,
                            "distance_km": dist,
                            "opening_hours": "9:00 AM – 10:00 PM",
                        })
        except Exception:
            pass

    results.sort(key=lambda x: x["distance_km"])
    top_results = results[:15]
    _cache[cache_key] = (now, top_results)
    return top_results


@router.get("/pharmacies/registered/nearby")
def get_registered_nearby_pharmacies(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: int = Query(5000, description="Radius in meters"),
    db: Session = Depends(get_db)
):
    radius_km = radius / 1000.0
    pharmacies = db.query(Pharmacy).all()
    results = []
    for p in pharmacies:
        p_lat = p.lat if p.lat is not None else p.latitude
        p_lng = p.lng if p.lng is not None else p.longitude
        if p_lat is None or p_lng is None:
            continue
        dist = haversine(lat, lng, p_lat, p_lng)
        if dist <= radius_km:
            results.append({
                "id": p.id,
                "name": p.name,
                "address": p.address,
                "lat": p_lat,
                "lng": p_lng,
                "phone": p.phone,
                "opening_hours": p.opening_hours,
                "is_open": bool(p.is_open) if p.is_open is not None else True,
                "distance_km": dist
            })
    results.sort(key=lambda x: x["distance_km"])
    return results


@router.get("/medicines/nearby")
def get_medicines_nearby(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: int = Query(5000, description="Initial radius in meters"),
    q: Optional[str] = Query(None, description="Search query"),
    db: Session = Depends(get_db)
):
    # Auto-widen radius 5000 -> 10000 -> 20000 if empty
    radii_to_try = [radius]
    for r in [5000, 10000, 20000]:
        if r > radius and r not in radii_to_try:
            radii_to_try.append(r)

    all_pharmacies = db.query(Pharmacy).all()
    pharmacy_map = {}
    pharmacy_distances = {}
    for p in all_pharmacies:
        p_lat = p.lat if p.lat is not None else p.latitude
        p_lng = p.lng if p.lng is not None else p.longitude
        if p_lat is None or p_lng is None:
            continue
        dist = haversine(lat, lng, p_lat, p_lng)
        pharmacy_map[p.id] = p
        pharmacy_distances[p.id] = dist

    for current_radius in radii_to_try:
        radius_km = current_radius / 1000.0
        nearby_pharmacy_ids = [
            pid for pid, dist in pharmacy_distances.items() if dist <= radius_km
        ]
        if not nearby_pharmacy_ids:
            continue

        query = db.query(Stock).filter(
            Stock.pharmacy_id.in_(nearby_pharmacy_ids),
            Stock.quantity > 0
        )
        if q and q.strip():
            query = query.filter(Stock.medicine_name.ilike(f"%{q.strip()}%"))

        stocks = query.all()
        if not stocks:
            continue

        groups = {}
        for s in stocks:
            key = (
                s.medicine_name.strip().title(),
                (s.strength or "").strip(),
                (s.form or "").strip()
            )
            p = pharmacy_map[s.pharmacy_id]
            dist = pharmacy_distances[s.pharmacy_id]
            if key not in groups:
                groups[key] = {
                    "name": s.medicine_name.strip(),
                    "strength": s.strength or "",
                    "form": s.form or "",
                    "min_price": s.price,
                    "pharmacies": []
                }
            groups[key]["pharmacies"].append({
                "pharmacy_id": s.pharmacy_id,
                "name": p.name,
                "distance_km": dist,
                "price": s.price,
                "quantity": s.quantity,
                "is_open": bool(p.is_open) if p.is_open is not None else True
            })
            if s.price < groups[key]["min_price"]:
                groups[key]["min_price"] = s.price

        for g in groups.values():
            g["pharmacies"].sort(key=lambda x: x["distance_km"])

        sorted_groups = sorted(
            groups.values(),
            key=lambda x: x["pharmacies"][0]["distance_km"] if x["pharmacies"] else 999999
        )
        return sorted_groups[:40]

    return []

