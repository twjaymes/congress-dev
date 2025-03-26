# BillParser.Bioguide

**generator.py:**

- Downloads a ZIP file from the Bioguide Congress website containing legislator data in JSON format.
- Iterates through the JSON files and builds a JSON schema using genson.SchemaBuilder.
- Saves the generated schema to schema.json.
- Uses datamodel-codegen to generate a Python data model (bioguide.py) from the schema.

**manager.py:**

- Manages the import of legislator data into a database.
- Downloads and extracts biographical data from BioguideProfiles.zip.
- Parses JSON data into BioGuideMember objects.
- Reads metadata from local JSON files (legislators-current.json, legislators-historical.json) to map bioguide IDs to LIS (Legislative Information System) IDs.
- Reads legislators-social.json to collect social media handles.
- Processes data to extract key information (party affiliation, state, job, congress ID, and images).
- Saves the cleaned and structured data into a database using SQLAlchemy (Session).

**types.py:** This file defines Pydantic models for handling structured data related to U.S. Congress members. It includes classes representing personal details, relationships, job positions, congressional affiliations, party and caucus memberships, records, images, and name history. The main model, BioGuideMember, aggregates these details, allowing for structured validation and serialization of congressional biographical data.