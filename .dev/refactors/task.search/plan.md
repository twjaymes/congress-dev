# Search Bar for Members Route

Postgres FTS is a strong foundation and scales well.

## Minimal mental model

document text
   ↓
to_tsvector()
   ↓
GIN index
   ↓
tsquery(search terms)
   ↓
ranked results

⸻

## 1️⃣ Table design (single file → many docs)

For members search, use data from...

```sql
CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  title TEXT,
  body TEXT,
  metadata JSONB,
  search_vector TSVECTOR
);
```

### Auto-update the search vector

```sql
CREATE FUNCTION documents_tsvector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.body, '')), 'B');
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_tsvector_trigger
BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION documents_tsvector_update();
```

---

## 2️⃣ Index it (critical)

```sql
CREATE INDEX documents_search_idx
ON documents
USING GIN (search_vector);
```

---

## 3️⃣ Query it (core search)

### Simple search

```sql
SELECT id, title
FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'cloud costs');
```

### Ranked search

```sql
SELECT
  id,
  title,
  ts_rank(search_vector, plainto_tsquery('english', 'cloud costs')) AS rank
FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'cloud costs')
ORDER BY rank DESC;
```

---

## 4️⃣ Python backend (FastAPI example)

```python
@app.post("/search")
def search(q: str):
    sql = """
    SELECT id, title
    FROM documents
    WHERE search_vector @@ plainto_tsquery('english', %s)
    ORDER BY ts_rank(search_vector, plainto_tsquery('english', %s)) DESC
    LIMIT 20;
    """
    return db.fetch_all(sql, (q, q))
```

---

## 5️⃣ Frontend (Node / Next.js)

```javascript
await fetch("/api/search", {
  method: "POST",
  body: JSON.stringify({ q: query }),
})
```

---

## 6️⃣ Extendability checklist (future you will thank you)

- [x] Add metadata filters:

```sql
AND metadata->>'type' = 'pdf'
```

- [x] Phrase search:

```sql
to_tsquery('english', 'cloud & cost')
```

- [x] Highlight matches:

```sql
ts_headline('english', body, query)
```

- [x] Hybrid later:
  - Keep this FTS
  - Add vector similarity
  - Blend ranks

---

## When to stop using pure FTS

Move beyond Postgres-only when:

- Documents > ~5–10M
- Need semantic meaning
- Cross-language similarity

Until then: Postgres FTS is fast, cheap, and debuggable.

---

## Next

- FTS for code files
- Incremental indexing from filesystem
- Hybrid FTS + embeddings
- Ranking tuning (A/B weights, decay, freshness)
