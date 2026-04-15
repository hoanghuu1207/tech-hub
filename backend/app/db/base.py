from sqlalchemy.orm import declarative_base

# Lớp Base mà toàn bộ các SQLAlchemy Models của ứng dụng sẽ kế thừa (User, Product, Order...)
Base = declarative_base()
