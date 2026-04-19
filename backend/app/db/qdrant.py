from qdrant_client import QdrantClient
from app.core.config import settings

# Initialize Qdrant Cloud Client
qdrant_client = QdrantClient(
    url=settings.QDRANT_CLUSTER_ENDPOINT, 
    api_key=settings.QDRANT_API_KEY,
)

# Optional: Add a function to check connection or list collections
def check_qdrant_connection():
    try:
        collections = qdrant_client.get_collections()
        print(f"Successfully connected to Qdrant Cloud! Collections: {collections}")
        return True
    except Exception as e:
        print(f"Failed to connect to Qdrant Cloud: {e}")
        return False
