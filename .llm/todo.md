# Flask to FastAPI Migration TODO

## Project Overview
Migrate from Flask-based `congress_api` to FastAPI-based `congress_fastapi`. Goal is to maintain input/output compatibility to avoid frontend changes while leveraging Pydantic/SQLAlchemy models for cleaner, more maintainable code.

## Migration Strategy
- Use MappableBase models with `sqlalchemy_columns()` for cleaner field mapping
- Maintain exact same endpoints and response structures
- Leverage FastAPI's automatic validation and documentation

---

## Routes Migration Status

### ✅ Already Migrated to FastAPI

#### Legislation Routes (NEW)
- [x] `GET /legislation/{legislation_id}/actions` - Get actions for legislation
- [x] `GET /legislation/{legislation_id}/{version_str}` - Get legislation by ID and version
- [x] `GET /legislation/{legislation_id}/latest/text` - Get latest legislation text (MCP)
- [x] `GET /legislation/search` - Search legislation (MCP)
- [x] `GET /legislation/search-tags` - Get available search tags

#### Legislation Version Routes (NEW)
- [x] `GET /legislation_version/{legislation_version_id}/tags` - Get tags for version
- [x] `GET /legislation_version/{legislation_version_id}/summaries` - Get summaries
- [x] `GET /legislation_version/{legislation_version_id}/actions` - Get actions by version
- [x] `GET /legislation_version/{legislation_version_id}/text` - Get text content
- [x] `GET /legislation_version/{legislation_version_id}/summary` - Get version metadata
- [x] `POST /legislation_version/{legislation_version_id}/llm` - LLM chat interface
- [x] `GET /legislation_version/{legislation_version_id}/diff` - Get diff metadata

#### US Code Routes (NEW)
- [x] `POST /uscode/search` - Search US Code (MCP)
- [x] `GET /uscode/{title}/{section}` - Get US Code section (MCP)

#### Members Routes (NEW - Not in Flask)
- [x] `GET /members` - Search members with filters
- [x] `GET /member/{bioguide_id}` - Get member info
- [x] `GET /member/{bioguide_id}/sponsorships` - Get member sponsorships

#### Committees Routes (NEW - Not in Flask)
- [x] `GET /committees` - Search committees
- [x] `GET /committee/{committee_id}` - Get committee info
- [x] `GET /congress/{congress_id}/committees` - Get committees by congress
- [x] `GET /committee/{committee_id}/subcommittees` - Get subcommittees

#### Stats Routes (NEW - Not in Flask)
- [x] `GET /stats/legislation_calendar` - Calendar visualization data
- [x] `GET /stats/legislation_funnel` - Funnel visualization data

#### User Routes (NEW - Not in Flask)
- [x] `GET /user` - Get current user
- [x] `POST /user/login` - User login
- [x] `GET /user/logout` - User logout
- [x] `GET /user/stats` - User statistics
- [x] `GET /user/legislation` - User tracked legislation
- [x] `GET /user/legislation/feed` - User legislation feed
- [x] `GET /user/legislation/update` - Legislation updates
- [x] `GET /user/legislator` - User tracked legislators
- [x] `GET /user/legislator/feed` - User legislator feed
- [x] `GET /user/legislator/update` - Legislator updates
- [x] `GET /user/usc_tracking/folders` - USC tracking folders
- [x] `GET /user/usc_tracking/folder/{folder_id}` - USC tracking folder details

---

### 🟡 In Progress

####  Congress Session Routes
- [ ] `GET /congress` - List all congress sessions
  - **Flask**: `get_sessions_summary()` in `legislation_controller.py`
  - **Response Model**: `CongressSessionList` (List of `SessionMetadata`)
  - **Priority**: HIGH - Core endpoint

- [ ] `GET /congress/{session}` - Get specific session info
  - **Flask**: `get_session_summary(session)` in `legislation_controller.py`
  - **Response Model**: `SessionMetadata`
  - **Priority**: HIGH - Core endpoint

### 🔴 Need to Migrate from Flask to FastAPI

#### Chamber Routes
- [ ] `GET /congress/{session}/{chamber}` - Get chamber summary
  - **Flask**: `get_chamber_summary(session, chamber)` in `legislation_controller.py`
  - **Response Model**: `ChamberMetadata`
  - **Priority**: HIGH - Core endpoint

- [ ] `GET /congress/{session}/{chamber}-bills` - List bills for chamber
  - **Flask**: `get_chamber_bills(session, chamber, page, page_size)` in `legislation_controller.py`
  - **Response Model**: `ChamberBillList`
  - **Query Params**: `page` (default: 1), `page_size` (default: 25, max: 25)
  - **Priority**: HIGH - Core list endpoint

#### Bill Routes
- [ ] `GET /congress/{session}/{chamber}-bill/{bill}` - Get bill summary
  - **Flask**: `get_bill_summary(session, chamber, bill)` in `legislation_controller.py`
  - **Response Model**: `BillMetadata`
  - **Priority**: HIGH - Core endpoint
  - **Note**: May overlap with new `/legislation/{legislation_id}/{version_str}` endpoint

#### Bill Version Routes
- [ ] `GET /congress/{session}/{chamber}-bill/{bill}/{version}/summary` - Get bill version summary
  - **Flask**: `get_bill_version_summary(session, chamber, bill, version)` in `legislation_controller.py`
  - **Response Model**: `BillVersionMetadata`
  - **Priority**: HIGH - Core endpoint
  - **Note**: Check overlap with `/legislation_version/{legislation_version_id}/summary`

- [ ] `GET /congress/{session}/{chamber}-bill/{bill}/{version}/text` - Get bill version text
  - **Flask**: `get_bill_version_text(session, chamber, bill, version, include_parsed)` in `legislation_controller.py`
  - **Response Model**: `BillTextResponse`
  - **Query Params**: `include_parsed` (default: false)
  - **Priority**: HIGH - Core text retrieval
  - **Note**: Check overlap with `/legislation_version/{legislation_version_id}/text`

#### Bill Diff Routes
- [ ] `GET /congress/{session}/{chamber}-bill/{bill}/{version}/diffs/{short_title}/{section_number}` - Get diffs by section
  - **Flask**: `get_bill_version_diffs(session, chamber, bill, version, short_title, section_number)` in `legislation_controller.py`
  - **Response Model**: `BillContentDiffList`
  - **Priority**: MEDIUM - Specialized diff view

- [ ] `GET /congress/{session}/{chamber}-bill/{bill}/{base_version}/amendments/{new_version}` - Get amendments (DEPRECATED)
  - **Flask**: `get_bill_version_amdts(session, chamber, bill, base_version, new_version)` in `legislation_controller.py`
  - **Response Model**: Generic object
  - **Priority**: LOW - Already deprecated in Flask

#### Search Routes
- [ ] `GET /congress/search` - Search bills
  - **Flask**: `get_congress_search(congress, chamber, versions, text, sort, page, page_size)` in `legislation_controller.py`
  - **Response Model**: `BillSearchList`
  - **Query Params**: `congress`, `chamber`, `versions`, `text`, `sort`, `page` (default: 1), `pageSize` (default: 25, max: 25)
  - **Priority**: HIGH - Core search
  - **Note**: FastAPI has `/legislation/search` - may need to support both or redirect

#### US Code Release Routes
- [ ] `GET /usc/releases` - Get available USC releases
  - **Flask**: `get_usc_releases()` in `uscode_controller.py`
  - **Response Model**: `ReleasePointList`
  - **Priority**: MEDIUM

- [ ] `GET /usc/{release_vers}/titles` - Get titles for release
  - **Flask**: `get_usc_release_titles(release_vers)` in `uscode_controller.py`
  - **Response Model**: `USCTitleList`
  - **Priority**: MEDIUM

#### US Code Section Routes
- [ ] `GET /usc/{release_vers}/{short_title}/sections` - Get sections for title
  - **Flask**: `get_usc_release_sections(release_vers, short_title)` in `uscode_controller.py`
  - **Response Model**: `USCSectionList`
  - **Priority**: MEDIUM

- [ ] `GET /usc/{release_vers}/{short_title}/{section_number}/text` - Get section text
  - **Flask**: `get_usc_release_text(release_vers, short_title, section_number)` in `uscode_controller.py`
  - **Response Model**: `USCSectionContentList`
  - **Priority**: MEDIUM
  - **Note**: FastAPI has `/uscode/{title}/{section}` - different structure

#### US Code Hierarchy Routes
- [ ] `GET /usc/{release_vers}/{short_title}/levels` - Get base levels
  - **Flask**: `get_usc_levels_base(release_vers, short_title)` in `uscode_controller.py`
  - **Response Model**: `USCSectionList`
  - **Priority**: LOW - Hierarchical navigation

- [ ] `GET /usc/{release_vers}/{short_title}/levels/{usc_section_id}` - Get child levels
  - **Flask**: `get_usc_levels(release_vers, short_title, usc_section_id)` in `uscode_controller.py`
  - **Response Model**: `USCSectionList`
  - **Priority**: LOW - Hierarchical navigation

- [ ] `GET /usc/{release_vers}/{short_title}/lineage/{usc_section_number}` - Get section lineage
  - **Flask**: `get_usc_section_lineage(release_vers, short_title, usc_section_number)` in `uscode_controller.py`
  - **Response Model**: `USCSectionList`
  - **Priority**: LOW - Breadcrumb/navigation

---

## Implementation Notes

### Route Mapping Strategy
1. **Direct Migration**: Routes that map 1:1 should maintain exact path structure
2. **Path Parameter Changes**: Some routes use different parameter structures (e.g., session/chamber/bill vs legislation_id)
3. **Dual Support**: Consider supporting both old and new routes during transition
4. **Deprecation**: Mark old routes as deprecated once new versions stabilize

### Model Migration Pattern
```python
# Example from LegislationContent
class LegislationContent(MappableBase):
    legislation_content_id: int
    parent_id: Optional[int]
    # ... other fields
    
    @classmethod
    def sqlalchemy_columns(cls):
        return [
            # Maps snake_case DB columns to camelCase API fields
        ]
```

### Priority Definitions
- **HIGH**: Core functionality used by frontend, needed for basic operations
- **MEDIUM**: Important features but with workarounds available
- **LOW**: Nice-to-have, specialized use cases, or deprecated features

---

## Testing Checklist
- [ ] Compare Flask vs FastAPI response structures for compatibility
- [ ] Test all query parameters work correctly
- [ ] Verify error handling matches Flask behavior
- [ ] Check pagination works identically
- [ ] Validate enum values (chamber, versions, etc.)
- [ ] Test with frontend to ensure no breaking changes

---

## Next Steps
1. Start with HIGH priority Congress/Chamber routes (foundational)
2. Migrate Bill routes (core functionality)
3. Migrate US Code routes (specialized but important)
4. Add deprecation warnings to Flask routes
5. Update frontend to use new endpoints gradually
6. Remove Flask routes once migration complete
