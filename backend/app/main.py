import logging

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.health import router as health_router
from app.api.routes import auth, catalog, dashboard, executions, hooks, integrations, notifications, push, users, workflows
from app.core.config import settings

logging.basicConfig(level=logging.DEBUG if settings.DEBUG else logging.INFO)
logger = logging.getLogger("ghostwork")

app = FastAPI(
    title=settings.APP_NAME,
    description="The GhostWork workflow automation API.",
    version=settings.APP_VERSION,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-GhostWork-CSRF"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("X-Frame-Options", "DENY")
    if settings.ENVIRONMENT == "production":
        response.headers.setdefault("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
    return response


@app.exception_handler(Exception)
async def unhandled_error(request: Request, exc: Exception):
    # Log the details server-side; never return stack traces to clients.
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Something went wrong on our side. Please try again."},
    )


API_PREFIX = "/api/v1"
app.include_router(health_router, prefix=API_PREFIX)
for module in (auth, users, workflows, executions, hooks, dashboard, integrations, catalog, notifications, push):
    app.include_router(module.router, prefix=API_PREFIX)


@app.get("/", include_in_schema=False)
def root():
    return {
        "application": "GhostWork",
        "message": "Welcome to the GhostWork API.",
        "docs": "/docs",
    }
