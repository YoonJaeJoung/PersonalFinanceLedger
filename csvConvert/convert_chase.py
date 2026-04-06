import csv
import glob
import os
import re
from datetime import datetime

# Configuration
RAW_DIR = os.path.join(os.path.dirname(__file__), 'raw')
CONVERTED_DIR = os.path.join(os.path.dirname(__file__), 'converted')
CATEGORIES_FILE = os.path.join(os.path.dirname(__file__), 'categories.csv')

# Ensure converted directory exists
os.makedirs(CONVERTED_DIR, exist_ok=True)

def load_categories():
    """Load valid categories from the file."""
    categories = set()
    try:
        with open(CATEGORIES_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row['Name']:
                    categories.add(row['Name'])
    except Exception as e:
        print(f"Warning: Could not load categories.csv: {e}")
    return categories

VALID_CATEGORIES = load_categories()

def parse_date(date_str):
    """Parse date from MM/DD/YYYY to YYYY-MM-DD."""
    try:
        dt = datetime.strptime(date_str, '%m/%d/%Y')
        return dt.strftime('%Y-%m-%d')
    except ValueError:
        return date_str

def parse_zelle_date(date_str):
    """Parse Zelle date from D-Mon-YY to YYYY-MM-DD."""
    # Example: 11-Feb-26
    try:
        dt = datetime.strptime(date_str, '%d-%b-%y')
        return dt.strftime('%Y-%m-%d')
    except ValueError:
        return None

def normalize_text(text):
    """Normalize text for matching (strip spaces, lowercase)."""
    if not text:
        return ""
    return " ".join(text.split()).lower()

def load_zelle_data():
    """Load Zelle transactions into a lookup dictionary."""
    zelle_files = glob.glob(os.path.join(RAW_DIR, 'zelle_*.csv'))
    zelle_lookup = [] # List of dicts: {'date': 'YYYY-MM-DD', 'amount': float, 'recipient': str, 'memo': str}

    for zf in zelle_files:
        try:
            with open(zf, 'r', encoding='utf-8-sig') as f:
                lines = f.readlines()
                
            i = 0
            while i < len(lines):
                row1_text = lines[i].strip()
                # Skip empty lines
                if not row1_text or row1_text.startswith(',,,'):
                    i += 1
                    continue
                
                # Parse Row 1
                # Format: Date, , Recipient, , , Amount, 
                parts = list(csv.reader([row1_text]))[0]
                if len(parts) < 7:
                    i += 1
                    continue
                
                date_str = parts[0] # 11-Feb-26
                recipient = parts[2] # JUNYOUNG
                amount_str = parts[5] # $12.68
                
                parsed_date = parse_zelle_date(date_str)
                if not parsed_date:
                    i += 1
                    continue
                
                try:
                    amount = float(amount_str.replace('$', '').replace(',', '').strip())
                except ValueError:
                    amount = 0.0

                # Parse Row 2 for Memo
                memo = ""
                if i + 1 < len(lines):
                    row2_text = lines[i+1].strip()
                    parts2 = list(csv.reader([row2_text]))[0]
                    # Memo is in 3rd column (index 2)
                    if len(parts2) > 2:
                        memo = parts2[2].replace('"', '').strip()
                
                zelle_lookup.append({
                    'date': parsed_date,
                    'amount': amount,
                    'recipient': normalize_text(recipient),
                    'memo': memo
                })
                
                # Advance (usually 2 data lines + blank lines)
                # Simply advance 1, next loop will find next valid start or skip empty
                i += 1 
        except Exception as e:
            print(f"Error reading Zelle file {zf}: {e}")

    return zelle_lookup

def find_zelle_match(date_iso, chase_desc, amount, zelle_data, date_buffer_days=4):
    """Find matching Zelle transaction with a date buffer."""
    # Chase description: "Zelle payment to JUNYOUNG 28034732775"
    
    match = re.search(r"Zelle payment (?:to|from)\s+(.+?)(?:\s+(?:JPM)?\d+)?$", chase_desc, re.IGNORECASE)
    recipient_hint = ""
    if match:
        recipient_hint = normalize_text(match.group(1))
    
    abs_amount = abs(amount)
    
    try:
        current_date_obj = datetime.strptime(date_iso, '%Y-%m-%d')
    except ValueError:
        return None

    candidates = []
    for z in zelle_data:
        # Check Amount
        if abs(z['amount'] - abs_amount) > 0.01:
            continue
            
        # Check Date within buffer
        try:
            z_date_obj = datetime.strptime(z['date'], '%Y-%m-%d')
            delta = (current_date_obj - z_date_obj).days
            # Chase date (current_date_obj) is usually same or later than Zelle date (z_date_obj)
            # Allow Zelle date to be up to `date_buffer_days` before Chase date
            # Also allow it to be slightly after? Unlikely, but let's allow -1 to buffer.
            if -1 <= delta <= date_buffer_days:
                candidates.append(z)
        except ValueError:
            continue
            
    if not candidates:
        return None
        
    # If multiple, try to filter by recipient
    if len(candidates) > 1 and recipient_hint:
        best_match = None
        for cand in candidates:
            if cand['recipient'] in recipient_hint or recipient_hint in cand['recipient']:
                best_match = cand
                break
        if best_match:
            return best_match
            
    # Default to first match if amount matches and date is close
    return candidates[0]

def get_category(description, amount):
    """Determine category based on rules."""
    # Rules order:
    # 1. Transportation (handled by caller for MTA special case? No, "category should be Transportation")
    # 2. Restaurant Week (Amount < -70)
    # 3. Medical (CVS)
    # 4. Food (water, chipotle, TST, CPI, SQ)
    # 5. Groceries (Amazon, Target, tjoes)
    # 6. Gift (Amount > 0)
    # 7. Etc (Default)

    desc_lower = description.lower()
    
    # Rule 2: Restaurant Week
    if amount < -70:
        return "Restaurant Week"
        
    # Rule 3: Medical
    if 'cvs' in desc_lower:
        return "Medical"
        
    # Rule 4: Food
    food_keywords = ['water', 'chipotle', 'tst', 'cpi', 'sq']
    for kw in food_keywords:
        if kw in desc_lower:
            return "Food"
            
    # Rule 5: Groceries
    groceries_keywords = ['amazon', 'target', 'tjoes']
    for kw in groceries_keywords:
        if kw in desc_lower:
            return "Groceries"
            
    # Rule 6: Gift
    if amount > 0:
        return "Gift"
        
    # Rule 7: Etc
    return "Etc"

def process_chase_file(filepath, zelle_data):
    filename = os.path.basename(filepath)
    # Output filename: "before _" 
    # e.g., chase_0211.csv -> chase.csv
    if '_' in filename:
        out_name = filename.split('_')[0] + '.csv'
    else:
        out_name = filename
    
    out_path = os.path.join(CONVERTED_DIR, out_name)
    
    print(f"Processing {filename} -> {out_name}")
    
    with open(filepath, 'r', encoding='utf-8') as f_in, \
         open(out_path, 'w', encoding='utf-8', newline='') as f_out:
        
        reader = csv.reader(f_in)
        writer = csv.writer(f_out)
        
        # Write Header
        # "Strictly that follow: Date, Description, Category, Amount"
        writer.writerow(['Date', 'Description', 'Category', 'Amount'])
        
        # Skip original header
        try:
            header = next(reader)
        except StopIteration:
            return

        # Chase Header: Details,Posting Date,Description,Amount,Type,Balance,Check or Slip #
        # Index: 0=Details, 1=Posting Date, 2=Description, 3=Amount
        
        for row in reader:
            if len(row) < 4:
                continue
                
            raw_date = row[1]
            raw_desc = row[2]
            raw_amount_str = row[3]
            
            try:
                amount = float(raw_amount_str)
            except ValueError:
                amount = 0.0
                
            # Date Logic
            # Check for date in description suffix: "MM/DD"
            # Regex: \s\d{2}/\d{2}$
            date_override_match = re.search(r'\s(\d{2}/\d{2})$', raw_desc)
            if date_override_match:
                # Use the year from the posting date
                # Posting Date format: MM/DD/YYYY
                try:
                    posting_year = datetime.strptime(raw_date, '%m/%d/%Y').year
                    mm_dd = date_override_match.group(1)
                    final_date = f"{posting_year}-{mm_dd.replace('/', '-')}"
                except:
                    # Fallback
                    final_date = parse_date(raw_date)
            else:
                final_date = parse_date(raw_date)

            # Description Logic
            final_desc = raw_desc.strip()
            final_cat = "Etc" # Default
            
            is_mta = False
            
            # Rule 2: MTA
            if final_desc.startswith("MTA*NYCT PAYGO NEW YORK NY"):
                final_desc = "Subway"
                final_cat = "Transportation"
                is_mta = True
                
            # Rule 3: Zelle
            # "if the transaction descriptioin starts with "Zelle payemnet" (sic)"
            # Note: Chase often uses "Zelle payment to..." or "Zelle payment from..."
            if final_desc.lower().startswith("zelle payment"):
                match = find_zelle_match(final_date, final_desc, amount, zelle_data)
                
                # Extract original recipient for the formatted string
                # Helper to extract cleaner recipient name from Chase desc
                recip_match = re.search(r"Zelle payment (?:to|from)\s+(.+?)(?:\s+(?:JPM)?\d+)?$", raw_desc, re.IGNORECASE)
                raw_recipient = recip_match.group(1).strip() if recip_match else "Unknown"
                
                if match and match['memo']:
                    # Format: "Desc (Zelle to Recipient)"
                    # "Zelle payment to..." -> Is it always "to"? 
                    # If amount is positive, it might be "from". 
                    # User request: "Donut (Zelle to John)"
                    # If positive, maybe "Donut (Zelle from John)"? User didn't specify "from".
                    # But Zelle lookup has recipient.
                    
                    direction = "to" if amount < 0 else "from"
                    final_desc = f"{match['memo']} (Zelle {direction} {raw_recipient})"
                else:
                    # If no match found or no memo, keep as is? Or format partially?
                    # Keep as is for now if no memo found in Zelle file
                    pass
            
            # Category Logic
            if is_mta:
                pass # Already set to Transportation
            else:
                final_cat = get_category(final_desc, amount)
            
            # Validate Category
            if final_cat not in VALID_CATEGORIES:
                # Fallback to Etc if invalid (though our get_category returns valid ones mostly)
                # But 'Medical' is in list? Yes.
                # 'Restaurant Week' is in list? Yes.
                pass

            # Write Row
            writer.writerow([final_date, final_desc, final_cat, amount])

if __name__ == "__main__":
    zelle_data = load_zelle_data()
    chase_files = glob.glob(os.path.join(RAW_DIR, 'chase_*.CSV')) # Case insensitive? Glob is case sensitive usually on *nix, but on Mac can be loose.
    # Pattern matching for case mapping
    if not chase_files:
         chase_files = glob.glob(os.path.join(RAW_DIR, 'chase_*.csv'))
         
    for cf in chase_files:
        process_chase_file(cf, zelle_data)
