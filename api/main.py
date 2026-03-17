import uvicorn

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware
from fastapi.openapi.utils import get_openapi
from routers.default import router as default_router
from routers.stripe import router as stripe_router
from routers.dome import router as dome_router
from routers.inventory import router as inventory_router
from routers.user import router as user_router
from routers.plants import router as plants_router
from routers.scrapbook import router as scrapbook_router
from routers.chat import router as chat_router
from routers.feedback import router as feedback_router
from routers.qr_admin import router as qr_admin_router
from routers.tasks import router as tasks_router
from routers.announcements import router as announcements_router

from settings import config

app = FastAPI(
    title="domes",
    description="API for domes",
    version="1.0.0",
    docs_url=None if config.environment.name == "production" else "/docs",
    redoc_url=None if config.environment.name == "production" else "/redoc",
    swagger_ui_init_oauth={
        "usePkceWithAuthorizationCodeGrant": True,
        "clientId": config.auth0.client_id,
        "scopes": ["openid", "profile", "email"],
        "appName": "domes",
        "additionalQueryStringParams": {
            "audience": config.auth0.audience,
        },
    },
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*", # Not best practice
    ],
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Accept", "Authorization", "X-Requested-With"],
    allow_credentials=True,
    expose_headers=["*"],
    max_age=3600,
)

app.add_middleware(SessionMiddleware, secret_key=config.auth0.secret_id)

app.include_router(default_router, prefix="/api/v1", tags=["default"])
app.include_router(stripe_router, prefix="/api/v1", tags=["stripe"])
app.include_router(dome_router, prefix="/api/v1", tags=["dome"])
app.include_router(inventory_router, prefix="/api/v1", tags=["inventory"])
app.include_router(user_router, prefix="/api/v1", tags=["user"])
app.include_router(plants_router, prefix="/api/v1", tags=["plants"])
app.include_router(scrapbook_router, prefix="/api/v1", tags=["scrapbook"])
app.include_router(chat_router, prefix="/api/v1", tags=["chat"])
app.include_router(feedback_router, prefix="/api/v1", tags=["feedback"])
app.include_router(qr_admin_router, prefix="/api/v1", tags=["qr-admin"])
app.include_router(tasks_router, prefix="/api/v1", tags=["tasks"])
app.include_router(announcements_router, prefix="/api/v1", tags=["announcements"])

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy"}


# Supabase connection check endpoint
@app.get("/health/supabase")
async def supabase_health_check():
    from dependencies import get_supabase_databridge
    try:
        databridge = get_supabase_databridge()
        is_connected = await databridge.check_connection()
        version = await databridge.get_database_version()
        return {
            "status": "connected" if is_connected else "disconnected",
            "database_version": version,
            "database_url": config.supabase.url,
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "database_url": config.supabase.url,
        }


# Custom OpenAPI schema with security definitions
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )

    # Add Auth0 security scheme
    openapi_schema["components"] = openapi_schema.get("components", {})
    openapi_schema["components"]["securitySchemes"] = {
        "Auth0": {
            "type": "oauth2",
            "flows": {
                "authorizationCode": {
                    "authorizationUrl": f"https://{config.auth0.domain}/authorize",
                    "tokenUrl": f"https://{config.auth0.domain}/oauth/token",
                    "refreshUrl": f"https://{config.auth0.domain}/oauth/token",
                    "scopes": {
                        "openid": "OpenID Connect",
                        "profile": "User profile",
                        "email": "User email",
                    },
                }
            },
        }
    }

    # Apply security to all protected endpoints
    openapi_schema["security"] = [{"Auth0": ["openid", "profile", "email"]}]

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8443,
        reload=True,
        log_level="info",
    )
