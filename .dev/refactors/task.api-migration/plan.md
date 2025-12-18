# Implementation Plan: Congress Session Routes Migration

## Overview
Migrate two core Congress session endpoints from Flask (`congress_api`) to FastAPI (`congress_fastapi`) while maintaining exact API compatibility.

---

## Routes to Implement

### Route 1: `GET /congress`
**Purpose**: List all available congress sessions  
**Priority**: HIGH - Foundation endpoint used for navigation

### Route 2: `GET /congress/{session}`
**Purpose**: Get detailed information about a specific congress session  
**Priority**: HIGH - Core metadata endpoint

---

## Step-by-Step Implementation Plan

### Phase 1: Create Pydantic Models (30 mins)

#### 1.1 Create `CongressMetadata` Model
**File**: `backend/congress_fastapi/models/congress.dev.py` (NEW FILE)

```python
from typing import Annotated
from billparser.db.models import Congress as CongressModel
from congress_fastapi.models.abstract import MappableBase
from pydantic import Field


class CongressMetadata(MappableBase):
    """Metadata about a congressional session"""
    
    congress_id: Annotated[int, CongressModel.congress_id] = Field(
        ..., 
        alias="congress_id",
        description="Unique identifier for the congress"
    )
    session_number: Annotated[int, CongressModel.session_number] = Field(
        ..., 
        alias="session_number",
        description="The congress session number (e.g., 116, 117)"
    )
    start_year: Annotated[int, CongressModel.start_year] = Field(
        ..., 
        alias="start_year",
        description="Year the congress session started"
    )
    end_year: Annotated[int, CongressModel.end_year] = Field(
        ..., 
        alias="end_year",
        description="Year the congress session ended"
    )
```

**Why MappableBase?**
- Automatically maps SQLAlchemy columns to Pydantic fields
- Uses `humps.camelize` for automatic camelCase API responses
- Provides `sqlalchemy_columns()` method for clean query building
- Matches existing FastAPI patterns in the codebase

**Compatibility Check:**
- Flask model fields: `congress_id`, `session_number`, `start_year`, `end_year` ✓
- Same field names and types ✓
- Response will be identical ✓

---

### Phase 2: Create Handler Functions (45 mins)

#### 2.1 Create Handler File
**File**: `backend/congress_fastapi/handlers/congress.dev.py` (NEW FILE)

```python
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from billparser.db.models import Congress
from congress_fastapi.db.postgres import get_session
from congress_fastapi.models.congress import CongressMetadata


async def get_all_congress_sessions() -> List[CongressMetadata]:
    """
    Get a list of all congress sessions from the database.
    
    Returns:
        List[CongressMetadata]: List of all congress session metadata
    """
    async with get_session() as session:
        # Build query using MappableBase.sqlalchemy_columns()
        columns = CongressMetadata.sqlalchemy_columns()
        
        query = select(*columns).select_from(Congress)
        result = await session.execute(query)
        
        # Convert rows to Pydantic models
        sessions = [
            CongressMetadata.from_sqlalchemy(row._asdict()) 
            for row in result.all()
        ]
        
        return sessions


async def get_congress_session_by_number(
    session_number: int
) -> Optional[CongressMetadata]:
    """
    Get metadata for a specific congress session.
    
    Args:
        session_number: The congress session number (e.g., 116, 117)
        
    Returns:
        CongressMetadata if found, None otherwise
    """
    async with get_session() as session:
        columns = CongressMetadata.sqlalchemy_columns()
        
        query = (
            select(*columns)
            .select_from(Congress)
            .where(Congress.session_number == session_number)
        )
        result = await session.execute(query)
        row = result.first()
        
        if row is None:
            return None
            
        return CongressMetadata.from_sqlalchemy(row._asdict())
```

**Key Points:**
- Uses async/await pattern consistent with FastAPI
- Leverages `MappableBase.sqlalchemy_columns()` for clean column selection
- Returns Pydantic models for automatic validation and serialization
- Handles not-found case by returning `None`

---

### Phase 3: Create Route Endpoints (30 mins)

#### 3.1 Create Routes File
**File**: `backend/congress_fastapi/routes/congress.dev.py` (NEW FILE)

```python
from typing import List
from fastapi import APIRouter, HTTPException, status

from congress_fastapi.handlers.congress import (
    get_all_congress_sessions,
    get_congress_session_by_number,
)
from congress_fastapi.models.congress import CongressMetadata
from congress_fastapi.models.errors import Error

router = APIRouter(tags=["Congress"])


@router.get(
    "/congress",
    response_model=List[CongressMetadata],
    summary="List all congress sessions",
    description="Returns a list of all available congress sessions",
    responses={
        status.HTTP_200_OK: {
            "model": List[CongressMetadata],
            "description": "List of congress sessions",
        },
    },
)
async def list_congress_sessions() -> List[CongressMetadata]:
    """
    Get a list of all congress sessions.
    
    Returns metadata for every congress session in the database,
    including session number, start year, and end year.
    """
    sessions = await get_all_congress_sessions()
    return sessions


@router.get(
    "/congress/{session}",
    response_model=CongressMetadata,
    summary="Get specific congress session",
    description="Get detailed information about a specific congress session",
    responses={
        status.HTTP_200_OK: {
            "model": CongressMetadata,
            "description": "Congress session metadata",
        },
        status.HTTP_404_NOT_FOUND: {
            "model": Error,
            "description": "Congress session not found",
        },
    },
)
async def get_congress_session(session: int) -> CongressMetadata:
    """
    Get information about a specific congress session.
    
    Args:
        session: The congress session number (e.g., 116, 117)
        
    Returns:
        CongressMetadata for the requested session
        
    Raises:
        HTTPException: 404 if session not found
    """
    session_data = await get_congress_session_by_number(session)
    
    if session_data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Congress session {session} not found",
        )
    
    return session_data
```

**Route Design Decisions:**
- Uses `response_model` for automatic serialization and OpenAPI docs
- Includes comprehensive docstrings for auto-generated API documentation
- Proper HTTP status codes (200, 404)
- Error handling matches Flask behavior
- Path parameter validation is automatic via FastAPI

---

### Phase 4: Register Routes (10 mins)

#### 4.1 Update FastAPI App
**File**: `backend/congress_fastapi/app.py`

Add route registration:

```python
# Add import at top
from congress_fastapi.routes.congress import router as congress_router

# Add router registration (check existing pattern in file)
app.include_router(congress_router)
```

**Location**: Find where other routers are registered and add this one in the same pattern.

---

### Phase 5: Testing & Validation (45 mins)

#### 5.1 Unit Tests
**File**: `backend/congress_fastapi/test/test_congress.dev.py` (NEW FILE)

```python
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
```

#### 5.2 Compatibility Testing

**Manual Test Checklist:**
- [ ] Compare Flask response to FastAPI response for `/congress`
- [ ] Compare Flask response to FastAPI response for `/congress/{session}`
- [ ] Verify field names match (camelCase vs snake_case)
- [ ] Verify data types match
- [ ] Test error cases (invalid session number)
- [ ] Check response times (should be similar or better)

**Testing Commands:**
```bash
# Start Flask API (if still running)
# Test: curl http://localhost:9090/congress
# Save output: curl http://localhost:9090/congress > flask_congress_list.json

# Start FastAPI
# Test: curl http://localhost:9091/congress
# Save output: curl http://localhost:9091/congress > fastapi_congress_list.json

# Compare outputs
diff flask_congress_list.json fastapi_congress_list.json
```

#### 5.3 Performance Testing

Optional but recommended:
- [ ] Load test with `ab` or `wrk`
- [ ] Compare response times under load
- [ ] Check database query patterns (should use same queries)

---

### Phase 6: Documentation (15 mins)

#### 6.1 Update API Documentation
- FastAPI auto-generates OpenAPI docs at `/docs`
- Verify documentation looks correct
- Check request/response examples

#### 6.2 Update README
**File**: `backend/README.md`

Add note about migrated endpoints:
```markdown
## Migrated Endpoints

The following endpoints have been migrated from Flask to FastAPI:

- `GET /congress` - List all congress sessions
- `GET /congress/{session}` - Get specific session info

These endpoints are now available in both APIs during the transition period.
```

---

## Migration Checklist

### Pre-Implementation
- [ ] Review existing FastAPI patterns in codebase
- [ ] Check database connection setup in FastAPI
- [ ] Verify test infrastructure is set up

### Implementation
- [ ] Create `CongressMetadata` Pydantic model
- [ ] Create handler functions with async/await
- [ ] Create route endpoints with proper error handling
- [ ] Register routes in FastAPI app
- [ ] Write unit tests
- [ ] Run tests and fix any issues

### Validation
- [ ] Test both endpoints manually
- [ ] Compare responses with Flask version
- [ ] Verify error handling works correctly
- [ ] Check OpenAPI documentation
- [ ] Test with frontend (if available)

### Deployment
- [ ] Update environment configuration if needed
- [ ] Deploy to staging environment
- [ ] Run integration tests
- [ ] Monitor for errors
- [ ] Update production when ready

---

## Files to Create/Modify

### New Files
1. `backend/congress_fastapi/models/congress.dev.py` - Pydantic models
2. `backend/congress_fastapi/handlers/congress.dev.py` - Business logic
3. `backend/congress_fastapi/routes/congress.dev.py` - API endpoints
4. `backend/congress_fastapi/test/test_congress.dev.py` - Tests

### Modified Files
1. `backend/congress_fastapi/app.py` - Register new router
2. `backend/README.md` - Update documentation

---

## Success Criteria

✅ Both endpoints return identical data to Flask versions  
✅ All tests pass  
✅ No breaking changes for frontend  
✅ OpenAPI documentation is accurate  
✅ Error handling matches Flask behavior  
✅ Response times are equal or better  

---

## Estimated Time

- **Phase 1 (Models)**: 30 minutes
- **Phase 2 (Handlers)**: 45 minutes  
- **Phase 3 (Routes)**: 30 minutes
- **Phase 4 (Registration)**: 10 minutes
- **Phase 5 (Testing)**: 45 minutes
- **Phase 6 (Documentation)**: 15 minutes

**Total**: ~3 hours for complete implementation and testing

---

## Rollback Plan

If issues arise:
1. Routes are not registered by default - just don't register them
2. Keep Flask versions running as fallback
3. Can disable FastAPI routes via feature flag if needed
4. No database changes required, so rollback is safe

---

## Next Steps After Completion

Once these two routes are successfully migrated:
1. Migrate chamber routes (`/congress/{session}/{chamber}`)
2. Migrate bill routes (`/congress/{session}/{chamber}-bill/{bill}`)
3. Gradually migrate remaining Flask routes
4. Add deprecation warnings to Flask routes
5. Eventually remove Flask API entirely
