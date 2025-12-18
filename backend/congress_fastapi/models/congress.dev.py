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
