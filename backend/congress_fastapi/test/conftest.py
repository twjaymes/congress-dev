import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from congress_fastapi.app import app


@pytest_asyncio.fixture
async def client():
    """Create an async test client for the FastAPI app"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
