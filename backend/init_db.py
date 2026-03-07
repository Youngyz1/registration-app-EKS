"""
Database initialization module
Ensures tables are created and ready on app startup
"""
from database import engine, Base
import models

def init_db():
    """Initialize database tables on app startup"""
    try:
        print("[INIT] Creating database tables...")
        Base.metadata.create_all(bind=engine)
        print("[INIT]  Database tables created successfully")
    except Exception as e:
        print(f"[INIT]  Error creating tables: {str(e)}")
        raise

if __name__ == "__main__":
    init_db()
