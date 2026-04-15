docker exec techshop_backend alembic revision --autogenerate -m "tên_thay_doi"
docker exec techshop_backend alembic upgrade head
