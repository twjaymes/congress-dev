from typing import List
from fastapi import APIRouter, HTTPException, status

from congress_fastapi.handlers.congress_dev import (
    get_all_congress_sessions,
    get_congress_session_by_number,
)
from congress_fastapi.models.congress_dev import CongressMetadata
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
