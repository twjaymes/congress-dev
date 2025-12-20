"""merge heads

Revision ID: 8c6bb47f15c0
Revises: 581b84b38238, a1b2c3d4e5f6
Create Date: 2025-12-19 14:44:32.103036

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8c6bb47f15c0'
down_revision: Union[str, None] = ('581b84b38238', 'a1b2c3d4e5f6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
