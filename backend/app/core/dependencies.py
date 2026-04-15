from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.db.session import get_db
from app.models.user import User

# Mặc định OpenAPI sẽ biết URL lấy JWT via Swagger UI
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/swagger-login")

# In-Memory token blacklist. Chứa tất cả token được gọi qua /logout
BLACKLISTED_TOKENS = set()

async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # 1. Kiểm tra Token Blacklist
    if token in BLACKLISTED_TOKENS:
        raise HTTPException(status_code=401, detail="Token has been revoked/logged out")

    try:
        # 2. Decode Token
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
            
        # Không cho phép dùng refresh_token thay thế access_token
        if payload.get("refresh"):
             raise HTTPException(status_code=401, detail="Please use access token, not refresh token")
    except JWTError:
        raise credentials_exception

    # 3. Request Database check quyền
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None:
        raise credentials_exception
        
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
        
    return user
