from fastapi import APIRouter

router = APIRouter(prefix="/default", tags=["default"])

@router.get("/")
async def get_default():
    return {"message": "Hello, World!"}