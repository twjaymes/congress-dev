from typing import List, Optional
from sqlalchemy import select

from billparser.db.models import Congress
from congress_fastapi.db.postgres import get_database
from congress_fastapi.models.congress import CongressMetadata


async def get_all_congress_sessions() -> List[CongressMetadata]:
    """
    Get a list of all congress sessions from the database.
    
    Returns:
        List[CongressMetadata]: List of all congress session metadata
    """
    database = await get_database()
    
    # Build query using MappableBase.sqlalchemy_columns()
    columns = CongressMetadata.sqlalchemy_columns()
    
    query = select(*columns).select_from(Congress)
    results = await database.fetch_all(query)
    
    # Convert rows to Pydantic models
    sessions = [
        CongressMetadata.from_sqlalchemy(dict(row)) 
        for row in results
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
    database = await get_database()
    columns = CongressMetadata.sqlalchemy_columns()
    
    query = (
        select(*columns)
        .select_from(Congress)
        .where(Congress.session_number == session_number)
    )
    result = await database.fetch_one(query)
    
    if result is None:
        return None
        
    return CongressMetadata.from_sqlalchemy(dict(result))
