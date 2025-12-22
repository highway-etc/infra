import os
import pathlib

try:
    import pandas as pd
except ImportError:
    pd = None

def convert_to_utf8(file_path):
    """Ensure existing CSV files are UTF-8 encoded."""
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
        
        # Try to decode as UTF-8 first (safest)
        try:
            content.decode('utf-8')
            print(f"Skipping {file_path}: Already valid UTF-8")
            return
        except UnicodeDecodeError:
            pass

        # If not UTF-8, try GB18030 (common in Chinese Excel exports)
        try:
            text = content.decode('gb18030')
            # Write back as UTF-8
            with open(file_path, 'w', encoding='utf-8', newline='') as f:
                f.write(text)
            print(f"Converted {file_path} from GB18030 to UTF-8")
        except UnicodeDecodeError:
            print(f"Failed to decode {file_path} with GB18030")
            
    except Exception as e:
        print(f"Error converting {file_path}: {e}")

def convert_xlsx_to_csv(xlsx_path):
    """Convert XLSX to CSV with UTF-8 encoding."""
    if pd is None:
        print(f"pandas not installed, skip converting {xlsx_path.name}; install pandas to enable XLSX conversion")
        return
    try:
        csv_path = xlsx_path.with_suffix('.csv')
        if csv_path.exists():
            print(f"Skipping {xlsx_path.name}: {csv_path.name} already exists")
            return
        
        print(f"Converting {xlsx_path.name}...")
        df = pd.read_excel(xlsx_path, engine='openpyxl')
        df.to_csv(csv_path, index=False, encoding='utf-8')
        print(f"Successfully converted {xlsx_path.name} to {csv_path.name}")
    except Exception as e:
        print(f"Error converting {xlsx_path.name}: {e}")

def main():
    # Use absolute path or relative to script location
    script_dir = pathlib.Path(__file__).parent
    data_dir = script_dir.parent / "flink" / "data" / "test_data"
    
    if not data_dir.exists():
        # Fallback to the hardcoded path if relative fails
        data_dir = pathlib.Path("d:/Projects/highway-etc/infra/flink/data/test_data")

    print(f"Scanning directory: {data_dir.absolute()}")

    xlsx_files = list(data_dir.glob("*.xlsx"))
    print(f"Found {len(xlsx_files)} XLSX files")

    # 1. Convert XLSX to CSV
    for xlsx_path in xlsx_files:
        convert_xlsx_to_csv(xlsx_path)

    csv_files = list(data_dir.glob("*.csv"))
    print(f"Found {len(csv_files)} CSV files")

    # 2. Ensure all CSVs are UTF-8
    for csv_path in csv_files:
        convert_to_utf8(csv_path)

if __name__ == "__main__":
    main()
