import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_congress_sessions(client: AsyncClient):
    """Test GET /congress returns list of sessions"""
    response = await client.get("/congress")
    
    assert response.status_code == 200
    data = response.json()
    
    # Should return a list
    assert isinstance(data, list)
    
    # Each item should have required fields
    if len(data) > 0:
        session = data[0]
        assert "congressId" in session or "congress_id" in session
        assert "sessionNumber" in session or "session_number" in session
        assert "startYear" in session or "start_year" in session
        assert "endYear" in session or "end_year" in session


@pytest.mark.asyncio
async def test_get_congress_session_exists(client: AsyncClient):
    """Test GET /congress/{session} with valid session"""
    # First get a valid session number
    list_response = await client.get("/congress")
    sessions = list_response.json()
    
    if len(sessions) == 0:
        pytest.skip("No congress sessions in database")
    
    session_number = sessions[0].get("sessionNumber") or sessions[0].get("session_number")
    
    # Get specific session
    response = await client.get(f"/congress/{session_number}")
    
    assert response.status_code == 200
    data = response.json()
    
    assert data.get("sessionNumber") or data.get("session_number") == session_number


@pytest.mark.asyncio
async def test_get_congress_session_not_found(client: AsyncClient):
    """Test GET /congress/{session} with invalid session"""
    response = await client.get("/congress/99999")
    
    assert response.status_code == 404
    data = response.json()
    assert "detail" in data
