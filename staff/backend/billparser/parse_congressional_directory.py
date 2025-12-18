#!/usr/bin/env python3
"""
Parser for Congressional Directory text files.
Extracts member information and staff listings, converts to parquet format.
"""

import re
import pandas as pd
from pathlib import Path
from typing import List, Dict, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CongressionalDirectoryParser:
    """Parse Congressional Directory text files and extract staff information."""
    
    def __init__(self, filepath: str):
        self.filepath = Path(filepath)
        self.text = self._read_file()
        
    def _read_file(self) -> str:
        """Read the text file."""
        with open(self.filepath, 'r', encoding='utf-8') as f:
            return f.read()
    
    def _extract_member_sections(self) -> List[str]:
        """Split the document into individual member sections."""
        # Look for sections that start with member names (typically after district headers)
        # Members typically have their name in all caps followed by party and location
        sections = []
        
        # Split by district markers (e.g., "FIRST DISTRICT", "SECOND DISTRICT")
        # or by the pattern of member names
        lines = self.text.split('\n')
        current_section = []
        in_member_section = False
        
        for i, line in enumerate(lines):
            # Check if we're starting a new member section
            # Members are identified by: NAME, Party, of Location, State
            if re.match(r'^[A-Z][A-Z\s\.\'-]+,\s+(Republican|Democrat)', line.strip()):
                if current_section:
                    sections.append('\n'.join(current_section))
                current_section = [line]
                in_member_section = True
            elif in_member_section:
                # Continue collecting lines until we hit another member or major section
                if line.strip().startswith('***') or \
                   (i + 1 < len(lines) and 
                    re.match(r'^[A-Z][A-Z\s\.\'-]+,\s+(Republican|Democrat)', lines[i+1].strip())):
                    sections.append('\n'.join(current_section))
                    current_section = []
                    in_member_section = False
                else:
                    current_section.append(line)
        
        # Add the last section
        if current_section:
            sections.append('\n'.join(current_section))
            
        return sections
    
    def _parse_member_name(self, text: str) -> Optional[Dict]:
        """Extract member name, party, and basic info from section header."""
        # Pattern: NAME, Party, of City, State; born in...
        match = re.search(
            r'^([A-Z][A-Z\s\.\'-]+),\s+(Republican|Democrat|Independent),\s+of\s+([^,]+),\s+([A-Z]{2})',
            text, 
            re.MULTILINE
        )
        
        if match:
            return {
                'name': match.group(1).strip(),
                'party': match.group(2).strip(),
                'city': match.group(3).strip(),
                'state': match.group(4).strip()
            }
        return None
    
    def _parse_district(self, text: str) -> Optional[str]:
        """Extract district information."""
        # Look for district number
        match = re.search(r'(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH|TENTH|'
                         r'ELEVENTH|TWELFTH|THIRTEENTH|FOURTEENTH|FIFTEENTH|SIXTEENTH|'
                         r'SEVENTEENTH|EIGHTEENTH|NINETEENTH|TWENTIETH|AT-LARGE)\s+DISTRICT', 
                         text)
        if match:
            return match.group(1).title()
        return None
    
    def _parse_office_address(self, text: str) -> Optional[str]:
        """Extract Washington DC office address."""
        match = re.search(
            r'(\d+\s+(?:Cannon|Longworth|Rayburn|Russell|Dirksen|Hart)\s+(?:House|Senate)\s+Office Building)',
            text,
            re.IGNORECASE
        )
        if match:
            return match.group(1)
        return None
    
    def _parse_staff(self, text: str) -> List[Dict]:
        """Extract staff members and their positions."""
        staff_list = []
        
        # Pattern for staff entries:
        # Position.—Name.
        # or Position.—Name [ACTING].
        # or Multiple names: Position: Name1, Name2.
        
        lines = text.split('\n')
        for line in lines:
            # Single staff member pattern
            match = re.search(r'^([^.—]+)[.—]+([^.\n]+)\.?\s*(?:\[.*?\])?\s*$', line.strip())
            if match:
                position = match.group(1).strip()
                name = match.group(2).strip()
                
                # Skip lines that don't look like staff positions
                if any(keyword in position.lower() for keyword in [
                    'chief of staff', 'director', 'assistant', 'scheduler',
                    'counsel', 'advisor', 'coordinator', 'manager', 'secretary',
                    'representative', 'aide', 'correspondent'
                ]):
                    # Remove [ACTING] or similar annotations
                    name = re.sub(r'\s*\[.*?\]\s*', '', name).strip()
                    
                    # Check if multiple names are listed (Name1, Name2 pattern)
                    if ': ' in name:
                        # Handle "Position: Name1, Name2" format
                        names = name.split(': ')[-1]
                        for n in names.split(','):
                            n = n.strip()
                            if n and not n.startswith('('):
                                staff_list.append({
                                    'position': position,
                                    'name': n
                                })
                    else:
                        staff_list.append({
                            'position': position,
                            'name': name
                        })
        
        return staff_list
    
    def parse(self) -> pd.DataFrame:
        """Parse the entire document and return a DataFrame."""
        logger.info(f"Parsing {self.filepath}")
        
        sections = self._extract_member_sections()
        logger.info(f"Found {len(sections)} potential member sections")
        
        all_staff = []
        
        for section in sections:
            member_info = self._parse_member_name(section)
            
            if not member_info:
                continue
            
            district = self._parse_district(section)
            office = self._parse_office_address(section)
            staff_list = self._parse_staff(section)
            
            logger.info(f"Processing {member_info['name']} - found {len(staff_list)} staff members")
            
            for staff in staff_list:
                all_staff.append({
                    'member_name': member_info['name'],
                    'member_party': member_info['party'],
                    'member_city': member_info['city'],
                    'member_state': member_info['state'],
                    'district': district,
                    'office_address': office,
                    'staff_position': staff['position'],
                    'staff_name': staff['name']
                })
        
        df = pd.DataFrame(all_staff)
        logger.info(f"Created DataFrame with {len(df)} staff records")
        
        return df
    
    def save_to_parquet(self, output_path: str):
        """Parse and save to parquet format."""
        df = self.parse()
        
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_parquet(output_path, index=False, engine='pyarrow')
        logger.info(f"Saved to {output_path}")
        
        return df


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Parse Congressional Directory text file and convert to parquet'
    )
    parser.add_argument(
        'input_file',
        help='Path to the Congressional Directory text file'
    )
    parser.add_argument(
        '-o', '--output',
        default=None,
        help='Output parquet file path (default: same name as input with .parquet extension)'
    )
    
    args = parser.parse_args()
    
    # Set default output path if not provided
    if args.output is None:
        input_path = Path(args.input_file)
        args.output = input_path.parent / f"{input_path.stem}.parquet"
    
    # Parse and save
    parser = CongressionalDirectoryParser(args.input_file)
    df = parser.save_to_parquet(args.output)
    
    # Print summary
    print(f"\nParsing complete!")
    print(f"Total staff records: {len(df)}")
    print(f"Unique members: {df['member_name'].nunique()}")
    print(f"Output saved to: {args.output}")
    print(f"\nSample records:")
    print(df.head(10).to_string(index=False))


if __name__ == '__main__':
    main()
