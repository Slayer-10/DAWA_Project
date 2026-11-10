import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "dawa.db")
SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    # Import all models to ensure they are registered with Base.metadata
    from app.models import (  # noqa: F401
        user, patient, pharmacy, medicine, stock, inventory, prescription, invoice, order
    )
    Base.metadata.create_all(bind=engine)

    import sqlite3
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Migrate pharmacies table
    cur.execute("PRAGMA table_info(pharmacies)")
    p_cols = {row[1] for row in cur.fetchall()}
    if "owner_user_id" not in p_cols:
        cur.execute("ALTER TABLE pharmacies ADD COLUMN owner_user_id INTEGER")
    if "lat" not in p_cols:
        cur.execute("ALTER TABLE pharmacies ADD COLUMN lat FLOAT")
    if "lng" not in p_cols:
        cur.execute("ALTER TABLE pharmacies ADD COLUMN lng FLOAT")
    if "is_open" not in p_cols:
        cur.execute("ALTER TABLE pharmacies ADD COLUMN is_open BOOLEAN DEFAULT 1")

    cur.execute("UPDATE pharmacies SET lat = latitude WHERE lat IS NULL AND latitude IS NOT NULL")
    cur.execute("UPDATE pharmacies SET lng = longitude WHERE lng IS NULL AND longitude IS NOT NULL")
    cur.execute("UPDATE pharmacies SET is_open = 1 WHERE is_open IS NULL")

    # Migrate orders table
    cur.execute("PRAGMA table_info(orders)")
    o_cols = {row[1] for row in cur.fetchall()}
    if "user_id" not in o_cols:
        cur.execute("ALTER TABLE orders ADD COLUMN user_id INTEGER")
    if "items" not in o_cols:
        cur.execute("ALTER TABLE orders ADD COLUMN items TEXT")
    if "prescription_ref" not in o_cols:
        cur.execute("ALTER TABLE orders ADD COLUMN prescription_ref VARCHAR(100)")

    conn.commit()
    conn.close()
