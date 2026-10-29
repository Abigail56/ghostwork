from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.health import router as health_router
from app.core.config import settings


app = FastAPI(
    title=settings.APP_NAME,
    description="The GhostWork workflow automation API.",
    version="0.1.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)


app.include_router(
    health_router,
    prefix="/api/v1",
)


@app.get("/")
def root():
    return {
        "application": "GhostWork",
        "message": "Welcome to the GhostWork API.",
        "docs": "/docs",
    }