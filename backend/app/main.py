import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from .database import init_db
from .services.cache_builder import build_cache
from .routers import tides, locations
from .config import STATIC_DIR

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Tide Times Calendar...")
    init_db()
    logger.info("Database initialized")

    # Only rebuild cache if DB is empty or REBUILD_CACHE is set
    from .database import get_db
    with get_db() as db:
        count = db.execute("SELECT COUNT(*) as c FROM predictions").fetchone()["c"]

    if count == 0 or os.environ.get("REBUILD_CACHE"):
        logger.info("Building prediction cache (this may take a minute)...")
        build_cache()
        logger.info("Cache build complete!")
    else:
        logger.info(f"Using existing cache ({count} predictions)")

    yield
    logger.info("Shutting down Tide Times Calendar")


app = FastAPI(title="Tide Times Calendar", version="1.0.0", lifespan=lifespan)

# API routes
app.include_router(tides.router)
app.include_router(locations.router)


# Serve Flutter web app as SPA
if STATIC_DIR.exists():
    # Mount all static assets (JS, CSS, images, etc.)
    app.mount("/assets", StaticFiles(directory=str(STATIC_DIR / "assets")), name="assets")

    @app.get("/flutter_bootstrap.js")
    async def flutter_bootstrap():
        return FileResponse(str(STATIC_DIR / "flutter_bootstrap.js"))

    @app.get("/flutter_service_worker.js")
    async def flutter_sw():
        return FileResponse(str(STATIC_DIR / "flutter_service_worker.js"))

    @app.get("/main.dart.js")
    async def main_dart_js():
        path = STATIC_DIR / "main.dart.js"
        if path.exists():
            return FileResponse(str(path))
        return FileResponse(str(STATIC_DIR / "index.html"))

    @app.get("/manifest.json")
    async def manifest():
        return FileResponse(str(STATIC_DIR / "manifest.json"))

    @app.get("/favicon.png")
    async def favicon():
        path = STATIC_DIR / "favicon.png"
        if path.exists():
            return FileResponse(str(path))
        return FileResponse(str(STATIC_DIR / "index.html"))

    @app.get("/")
    async def serve_root():
        return FileResponse(str(STATIC_DIR / "index.html"))

    # Catch-all for Flutter SPA routing (must be last)
    @app.get("/{path:path}")
    async def serve_flutter(path: str):
        # Don't catch API routes
        if path.startswith("api/"):
            return {"error": "not found"}
        file_path = STATIC_DIR / path
        if file_path.exists() and file_path.is_file():
            return FileResponse(str(file_path))
        return FileResponse(str(STATIC_DIR / "index.html"))
else:
    @app.get("/")
    async def root():
        return {
            "message": "Tide Times Calendar API",
            "docs": "/docs",
            "endpoints": {
                "locations": "/api/locations",
                "tides": "/api/tides/{location}?date=YYYY-MM-DD",
                "hourly": "/api/tides/{location}/hourly?date=YYYY-MM-DD",
                "sun": "/api/sun/{location}?date=YYYY-MM-DD",
                "health": "/api/health",
            },
            "note": "Flutter web build not found at expected path.",
        }
