import pytest
import uuid
from httpx import AsyncClient

# Kích hoạt chế độ test asyncio
pytestmark = pytest.mark.asyncio

async def test_register_user_success(async_client: AsyncClient):
    unique_email = f"test_{uuid.uuid4()}@example.com"
    response = await async_client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email,
            "password": "Password123!",
            "full_name": "Test User",
            "phone": "0123456789",
            "role": "buyer"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["message"] == "User registered successfully"
    assert "access_token" in data["data"]
    assert data["data"]["user"]["email"] == unique_email


async def test_register_user_duplicate_email(async_client: AsyncClient):
    # Tạo user đầu tiên
    unique_email = f"dup_{uuid.uuid4()}@example.com"
    user_data = {
        "email": unique_email,
        "password": "Password123!",
        "full_name": "Test User Duplicate",
        "role": "buyer"
    }
    res1 = await async_client.post("/api/v1/auth/register", json=user_data)
    assert res1.status_code == 200

    # Cố tình đăng ký lại với cùng email
    res2 = await async_client.post("/api/v1/auth/register", json=user_data)
    
    assert res2.status_code == 400
    data = res2.json()
    assert data["success"] is False
    assert data["error"] == "Email already registered"


async def test_login_success(async_client: AsyncClient):
    unique_email = f"login_{uuid.uuid4()}@example.com"
    password = "StrongPassword123"
    
    # 1. Register first
    await async_client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email,
            "password": password,
            "full_name": "Login Test User",
            "role": "buyer"
        }
    )

    # 2. Login through JSON body
    login_response = await async_client.post(
        "/api/v1/auth/login",
        json={
            "email": unique_email,
            "password": password
        }
    )
    assert login_response.status_code == 200
    data = login_response.json()
    assert data["success"] is True
    assert "access_token" in data["data"]


async def test_login_incorrect_password(async_client: AsyncClient):
    unique_email = f"fail_{uuid.uuid4()}@example.com"
    
    # 1. Register first
    await async_client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email,
            "password": "CorrectPassword123",
            "full_name": "Wrong Login Test",
        }
    )

    # 2. Login with wrong password
    login_response = await async_client.post(
        "/api/v1/auth/login",
        json={
            "email": unique_email,
            "password": "WrongPassword123"
        }
    )
    assert login_response.status_code == 401
    assert login_response.json()["success"] is False


async def test_get_current_user_me(async_client: AsyncClient):
    unique_email = f"me_{uuid.uuid4()}@example.com"
    
    # 1. Register and get token
    register_res = await async_client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email,
            "password": "MePassword123",
            "full_name": "Me User",
        }
    )
    access_token = register_res.json()["data"]["access_token"]
    
    # 2. Call /me endpoint with Bearer token
    me_res = await async_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["success"] is True
    assert me_data["data"]["email"] == unique_email
    assert me_data["data"]["full_name"] == "Me User"


async def test_swagger_login_form(async_client: AsyncClient):
    unique_email = f"swagger_{uuid.uuid4()}@example.com"
    password = "SwaggerPassword123"
    
    await async_client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email,
            "password": password,
            "full_name": "Swagger User",
        }
    )
    
    # Login via form data (application/x-www-form-urlencoded)
    res = await async_client.post(
        "/api/v1/auth/swagger-login",
        data={"username": unique_email, "password": password}
    )
    
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
