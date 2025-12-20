# Search Bar Implementation - Tasks

## Updates

✅ **Database Setup Complete** - Migration created in [a1b2c3d4e5f6_add_legislator_fts.py](backend/alembic/versions/a1b2c3d4e5f6_add_legislator_fts.py)
✅ **Backend Implementation Complete** - Search endpoint added to [routes/members.py](backend/congress_fastapi/routes/members.py)
✅ **Model Updated** - Added search_vector column to [Legislator model](backend/billparser/db/models.py)

## Database Setup

**Note**: Using existing `legislator` table. Will add FTS columns and triggers to it.

- [x] Add `search_vector` column (TSVECTOR) to existing `legislator` table

```sql
ALTER TABLE legislator ADD COLUMN search_vector TSVECTOR;
```

- [x] Create `legislator_tsvector_update()` trigger function to auto-update search_vector

```sql
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
```

- [x] Create trigger `legislator_search_vector_trigger` to call update function on INSERT/UPDATE

```sql
CREATE TRIGGER legislator_search_vector_trigger
BEFORE INSERT OR UPDATE ON legislator
FOR EACH ROW EXECUTE FUNCTION legislator_tsvector_update();
```

- [x] Create GIN index `legislator_search_idx` on search_vector column

```sql
CREATE INDEX legislator_search_idx
ON legislator USING GIN (search_vector);
```

## Backend Implementation

- [x] Implement POST `/members/search` endpoint in FastAPI
- [x] Add SQL query with `plainto_tsquery` and `ts_rank` for ranked results
- [x] Add pagination (LIMIT 20) to search results
- [x] Return member info with ranking in search response

## Frontend Implementation

- [ ] Create search component for members route
- [ ] Add API call to POST `/api/search` with query parameter
- [ ] Display search results with ranking

## Future Enhancements (Optional)

- [ ] Add metadata filters (e.g., `metadata->>'type' = 'pdf'`)
- [ ] Implement phrase search with `to_tsquery`
- [ ] Add match highlighting with `ts_headline`
- [ ] Consider hybrid approach (FTS + vector similarity) if needed
