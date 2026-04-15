from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException
from jose import jwt, JWTError
from typing import Dict, Any

from app.models.user import User, UserRole
from app.schemas.auth import UserCreate, UserLogin, UpdateProfile, ChangePassword
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token
from app.core.config import settings

class AuthService:
    
    @staticmethod
    async def register(db: AsyncSession, user_in: UserCreate) -> Dict[str, Any]:
        # Kiểm tra conflict email hoặc phone
        result = await db.execute(select(User).where(User.email == user_in.email))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email already registered")
        
        if user_in.phone:
            result = await db.execute(select(User).where(User.phone == user_in.phone))
            if result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Phone already registered")
        
        # Mapping enum role
        role_enum = UserRole.buyer
        if user_in.role == "seller": role_enum = UserRole.seller
        elif user_in.role == "admin": role_enum = UserRole.admin

        new_user = User(
            email=user_in.email,
            phone=user_in.phone,
            full_name=user_in.full_name,
            hashed_password=get_password_hash(user_in.password),
            role=role_enum
        )
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)

        return {
            "access_token": create_access_token(new_user.id),
            "refresh_token": create_refresh_token(new_user.id),
            "user": new_user
        }

    @staticmethod
    async def login(db: AsyncSession, login_in: UserLogin) -> Dict[str, Any]:
        result = await db.execute(select(User).where(User.email == login_in.email))
        user = result.scalar_one_or_none()
        
        if not user or not verify_password(login_in.password, user.hashed_password):
            raise HTTPException(status_code=401, detail="Incorrect email or password")
            
        if not user.is_active:
            raise HTTPException(status_code=401, detail="User is currently inactive")
        
        return {
            "access_token": create_access_token(user.id),
            "refresh_token": create_refresh_token(user.id),
            "user": user
        }

    @staticmethod
    async def refresh(db: AsyncSession, refresh_token: str) -> str:
        try:
            payload = jwt.decode(refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            user_id: str = payload.get("sub")
            is_refresh = payload.get("refresh")
            if user_id is None or not is_refresh:
                raise HTTPException(status_code=401, detail="Invalid refresh token format")
        except JWTError:
            raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
        
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
            
        return create_access_token(user.id)

    @staticmethod
    async def update_profile(db: AsyncSession, current_user: User, data: UpdateProfile) -> User:
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(current_user, field, value)
        await db.commit()
        await db.refresh(current_user)
        return current_user

    @staticmethod
    async def change_password(db: AsyncSession, current_user: User, pass_data: ChangePassword):
        if not verify_password(pass_data.old_password, current_user.hashed_password):
            raise HTTPException(status_code=400, detail="Incorrect old password")
        
        current_user.hashed_password = get_password_hash(pass_data.new_password)
        await db.commit()
        return True
