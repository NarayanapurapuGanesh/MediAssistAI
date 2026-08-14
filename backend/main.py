from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware

from api.api import api_router
from core.config import settings
from db.base import Base
from db.session import engine
import models  # noqa: F401 — ensures all models are imported for table creation

# Create all tables (safe: does NOT drop existing tables/data)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME, openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
def root():
    return {"message": "Welcome to MediAssist AI Backend API"}
