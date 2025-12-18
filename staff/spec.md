# New Feature Specifications

## Feature: Congressional Staff lists

### Overview

The current /member route features two components: biography and sponsored legislation. I'd like to add new api routes for congressional staff. GPO publishes a Congressional Directory (https://catalog.gpo.gov/F/QLVB5462M5NQ4UAKQPY9X8PCR3NMF429HD5F8AFPC38UKBVMF2-57936?func=full-set-set&set_number=001108&set_entry=000001&format=999). GovInfo API routes don't work:

```bash
curl "https://api.govinfo.gov/packages/CDIR-2024-04-25/granules?offset=0&pageSize=500&api_key=ciWCkI5vMcyyNumUhv2YYPdhjrg7RzKQ5VK1NHc3"
```

New feature would use billparser to transform data into models that conform to api models; congress_fastapi/models/members.py. New 'office' model? Add foreign key to members model?

The new container would be featured below the Sponosred Legislation container on the member page. 