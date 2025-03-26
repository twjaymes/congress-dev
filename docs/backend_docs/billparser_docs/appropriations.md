# BillParser.Appropriations

Processes legislative text to extract and store appropriation details using an LLM and a database.

Key Components:

Dependencies:

- Uses json, litellm, and SQLAlchemy ORM (Session, LegislationContent, Appropriation).
- Imports calculate_appropriation from billparser.appropriations.

LLM-Based Parsing (llm_parse):

- Queries the database for legislation content that contains $ (indicating appropriations).
- Uses an LLM (ollama/dolphin-mixtral:8x7b) to extract appropriation details from each clause.
- Converts extracted monetary values to integers.
- Recursively processes sub-appropriations and stores them in the database.

Rule-Based Parsing (parse_bill_for_appropriations):

- Searches legislative text for appropriations using keywords like "appropriated" and $.
- Uses calculate_appropriation() (rule-based function) to extract appropriations.
- Stores extracted appropriations in the database.

Purpose:

- Automates appropriation extraction from legislative text using a mix of LLMs and rule-based methods.
- Stores structured appropriation data in a database for further analysis.