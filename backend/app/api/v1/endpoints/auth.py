from fastapi import APIRouter, Depends, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.schemas.auth import (
    UserCreate, UserLogin, StandardResponse, TokenResponse, 
    RefreshTokenReq, UserResponse, UpdateProfile, ChangePassword
)
from app.services.auth_service import AuthService
from app.core.dependencies import get_current_user, BLACKLISTED_TOKENS, oauth2_scheme
from app.models.user import User

from app.core.rate_limit import limiter

router = APIRouter()

def format_res(message: str, data: any = None) -> StandardResponse:
    return StandardResponse(success=True, message=message, data=data)

@router.post("/register", response_model=StandardResponse)
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await AuthService.register(db, user_in)
    
    token_response = TokenResponse(
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        user=UserResponse.model_validate(result["user"])
    )
    return format_res("User registered successfully", token_response)

# --- RIÊNG CHO SWAGGER UI AUTHORIZE ---
@router.post("/swagger-login", include_in_schema=False)
async def swagger_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    # Dùng AuthService login như bình thường
    result = await AuthService.login(db, UserLogin(email=form_data.username, password=form_data.password))
    
    # Swagger Authorize BẮT BUỘC trả về flat object có access_token và token_type
    return {
        "access_token": result["access_token"],
        "token_type": "bearer"
    }

@router.post("/login", response_model=StandardResponse)
@limiter.limit("5/minute")
async def login(request: Request, login_in: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await AuthService.login(db, login_in)
    
    token_response = TokenResponse(
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        user=UserResponse.model_validate(result["user"])
    )
    return format_res("Login successful", token_response)

@router.post("/refresh", response_model=StandardResponse)
async def refresh_token(token_in: RefreshTokenReq, db: AsyncSession = Depends(get_db)):
    # Đổi access token mới
    new_access_token = await AuthService.refresh(db, token_in.refresh_token)
    return format_res("Token refreshed successfully", {"access_token": new_access_token})

@router.post("/logout", response_model=StandardResponse)
async def logout(current_user: User = Depends(get_current_user), token: str = Depends(oauth2_scheme)):
    # Đưa String token cũ vừa gọi request vào thùng rác in-memory
    BLACKLISTED_TOKENS.add(token)
    return format_res("Logged out successfully. Token is now revoked.")

@router.get("/me", response_model=StandardResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    user_data = UserResponse.model_validate(current_user)
    return format_res("User info retrieved successfully", user_data)

@router.put("/me", response_model=StandardResponse)
async def update_me(
    update_data: UpdateProfile, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    updated_user = await AuthService.update_profile(db, current_user, update_data)
    user_data = UserResponse.model_validate(updated_user)
    return format_res("Profile updated successfully", user_data)

@router.post("/change-password", response_model=StandardResponse)
async def change_password(
    pass_data: ChangePassword,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    await AuthService.change_password(db, current_user, pass_data)
    return format_res("Password changed successfully")
