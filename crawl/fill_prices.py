import os
import json
import random

DATA_DIR = "/app/data/raw"

def fill_prices():
    files = [f for f in os.listdir(DATA_DIR) if f.endswith(".json")]
    updated_count = 0

    for filename in files:
        filepath = os.path.join(DATA_DIR, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                continue

        changed = False

        price = data.get("price")
        sale_price = data.get("sale_price")

        def is_valid_num(v):
            if v is None: return False
            try:
                import math
                val = float(v)
                return not math.isnan(val) and not math.isinf(val) and val > 0
            except (ValueError, TypeError):
                return False

        has_price = is_valid_num(price)
        has_sale = is_valid_num(sale_price)

        if has_price: price = int(float(price))
        if has_sale: sale_price = int(float(sale_price))

        # If both missing or invalid
        if not has_price and not has_sale:
            base_val = random.randint(15, 300) * 100000
            data["price"] = base_val
            data["sale_price"] = int(base_val * random.uniform(1.1, 1.3))
            data["sale_price"] = (data["sale_price"] // 10000) * 10000
            changed = True
        
        # Only has price
        elif has_price and not has_sale:
            data["sale_price"] = int(price * random.uniform(1.1, 1.3))
            data["sale_price"] = (data["sale_price"] // 10000) * 10000
            changed = True
            
        # Only has sale_price
        elif not has_price and has_sale:
            data["price"] = int(sale_price / random.uniform(1.1, 1.3))
            data["price"] = (data["price"] // 10000) * 10000
            changed = True
        
        # Special case: price > sale_price (should be price < sale_price)
        elif has_price and has_sale and price > sale_price:
            # Swap them
            data["price"], data["sale_price"] = sale_price, price
            changed = True

        if changed:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            updated_count += 1

    print(f"Updated {updated_count} files.")

if __name__ == '__main__':
    fill_prices()
