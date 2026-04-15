from pydantic import BaseModel, Field
from typing import Optional, Any
from uuid import UUID

# DTO: Standard Response
class StandardResponse(BaseModel):
    success: bool = True
    message: str
    data: Optional[Any] = None
    error: Optional[str] = None

# DTO: Đăng ký
class UserCreate(BaseModel):
    # Regex cơ bản thay EmailStr để tránh lỗi thiếu lib email-validator ở vài môi trường strict
    email: str = Field(..., pattern=r"^\S+@\S+\.\S+$")
    password: str = Field(..., min_length=8, max_length=72)
    full_name: str
    phone: Optional[str] = None
    role: str = "buyer"

# DTO: Đăng nhập
class UserLogin(BaseModel):
    email: str
    password: str = Field(..., max_length=72)

# DTO: Phục vụ trả thông tin cơ bản cho user
class UserResponse(BaseModel):
    id: UUID
    email: str
    full_name: str
    phone: Optional[str]
    role: str
    is_active: bool
    is_verified: bool
    avatar_url: Optional[str]

    class Config:
        from_attributes = True

# DTO: Auth Output (Token)
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse

# DTO: Khác
class RefreshTokenReq(BaseModel):
    refresh_token: str

class UpdateProfile(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None

class ChangePassword(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8, max_length=72)
