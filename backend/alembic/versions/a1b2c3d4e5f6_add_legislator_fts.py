"""add legislator full-text search

Revision ID: a1b2c3d4e5f6
Revises: 45716515aad4
Create Date: 2025-12-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "45716515aad4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add search_vector column to legislator table
    op.add_column(
        "legislator",
        sa.Column("search_vector", postgresql.TSVECTOR, nullable=True),
    )

    # Create trigger function to auto-update search_vector
    op.execute(
        """
        CREATE FUNCTION legislator_tsvector_update() RETURNS trigger AS $$
        BEGIN
          NEW.search_vector :=
              setweight(to_tsvector('english', coalesce(NEW.first_name || ' ' || NEW.last_name, '')), 'A')
           || setweight(to_tsvector('english', coalesce(NEW.state, '')), 'B')
           || setweight(to_tsvector('english', coalesce(NEW.party, '')), 'B')
           || setweight(to_tsvector('english', coalesce(NEW.profile, '')), 'C');
          RETURN NEW;
        END
        $$ LANGUAGE plpgsql;
        """
    )

    # Create trigger to call update function on INSERT/UPDATE
    op.execute(
        """
        CREATE TRIGGER legislator_search_vector_trigger
        BEFORE INSERT OR UPDATE ON legislator
        FOR EACH ROW EXECUTE FUNCTION legislator_tsvector_update();
        """
    )

    # Create GIN index on search_vector column
    op.create_index(
        "legislator_search_idx",
        "legislator",
        ["search_vector"],
        unique=False,
        postgresql_using="gin",
    )

    # Populate search_vector for existing rows
    op.execute(
        """
        UPDATE legislator SET search_vector = 
            setweight(to_tsvector('english', coalesce(first_name || ' ' || last_name, '')), 'A')
         || setweight(to_tsvector('english', coalesce(state, '')), 'B')
         || setweight(to_tsvector('english', coalesce(party, '')), 'B')
         || setweight(to_tsvector('english', coalesce(profile, '')), 'C');
        """
    )


def downgrade() -> None:
    # Drop index
    op.drop_index("legislator_search_idx", table_name="legislator")

    # Drop trigger
    op.execute("DROP TRIGGER IF EXISTS legislator_search_vector_trigger ON legislator;")

    # Drop trigger function
    op.execute("DROP FUNCTION IF EXISTS legislator_tsvector_update();")

    # Drop column
    op.drop_column("legislator", "search_vector")
