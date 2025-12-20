# Setup

## Data Sources

### Bills
Currently reads from local files (download commented out):
- `BULK_BIOGUIDE_URL`: https://bioguide.congress.gov/bioguide/data/BioguideProfiles.zip
- `SENATE_LIST_URL`: https://www.senate.gov/legislative/LIS_MEMBER/cvc_member_data.xml

Fallback to unitedstates/congress-legislators repo:
- Current legislators: https://theunitedstates.io/congress-legislators/legislators-current.json
- Historical legislators: https://theunitedstates.io/congress-legislators/legislators-historical.json

### Bioguide
Uses Congress.gov API:
```
https://api.congress.gov/v3/bill/{congress}/{bill_type}/{bill_number}/cosponsors
```
**Requires**: `CONGRESS_API_KEY` environment variable

### Sponsors
Uses Congress.gov API:
```
https://api.congress.gov/v3/bill/{congress}/{bill_type}/{bill_number}/actions
```
**Requires**: `CONGRESS_API_KEY` environment variable

### Actions
Downloads US Code release points:
```
https://uscode.house.gov/download/releasepoints/us/pl/{congress}/{session}/xml_uslm@{bill_num}.zip
```
Example: https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip

### Releases
Scrapes available release points from:
```
https://uscode.house.gov/download/releasepoints/us/pl/{congress}/{session}/
```

### Statuses
No external data source - processes existing bill data from database.
Uses local bill XML files already downloaded by bills importer.

### Votes
Uses Congress.gov API:
```
https://api.congress.gov/v3/bill/{congress}/{bill_type}/{bill_number}
```
Extracts vote information from bill data.

**Requires**: `CONGRESS_API_KEY` environment variable

### Prompts
No external data source - processes existing bill data.
Reads from local bill XML files.

### Cleanup
No external data source - database maintenance.
Post-processing and data cleanup.

### Committee
Uses Congress.gov API:
```
https://api.congress.gov/v3/committee/{chamber}
```
**Requires**: `CONGRESS_API_KEY` environment variable

## Additional Resources

- Legislators (current): https://raw.githubusercontent.com/unitedstates/congress-legislators/main/legislators-current.json
- Legislators (historical): https://raw.githubusercontent.com/unitedstates/congress-legislators/refs/heads/main/legislators-historical.yaml
- Legislators (social media): https://raw.githubusercontent.com/unitedstates/congress-legislators/refs/heads/main/legislators-social-media.yaml

## Database Connection

```
postgresql://bills:bills@localhost:5401/uscode
```