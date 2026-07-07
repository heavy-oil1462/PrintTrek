#!/usr/bin/env python3
import math
import os
import re
import glob

# Only these files contain real structural tube geometry. The other .scad
# files are component mockups (battery box, niches, plates) whose cubes
# would otherwise be misread as steel tubes.
STRUCTURAL_FILES = {'frame.scad', 'cabin.scad'}

def calculate_tubes(cad_dir):
    scad_files = [f for f in glob.glob(os.path.join(cad_dir, '*.scad'))
                  if os.path.basename(f) in STRUCTURAL_FILES]
    
    tubes = {} # (dimension_x, dimension_y): [lengths...]

    for filepath in scad_files:
        with open(filepath, 'r') as f:
            content = f.read()

        # Remove multi-line comments
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        # Remove single-line comments
        content = re.sub(r'//.*', '', content)

        # 1. Extract variables
        vars_dict = {}
        var_matches = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*([^;]+);', content)
        for var, expr in var_matches:
            vars_dict[var] = expr.strip()
            
        def eval_expr(expr, variables):
            # Iteratively replace variables
            for _ in range(5):
                for v_name, v_val in variables.items():
                    # Replace variable names, but not inside other words.
                    # Parenthesize the substituted expression so operator
                    # precedence survives (e.g. a*a where a = "b + c").
                    expr = re.sub(r'\b' + v_name + r'\b', '(' + str(v_val) + ')', expr)
            try:
                # Evaluate simple math expressions (sqrt needed for the
                # drawbar arm length in frame.scad)
                allowed_names = {"__builtins__": None}
                return float(eval(expr, allowed_names, {"sqrt": math.sqrt}))
            except Exception:
                return None

        # Resolve variables to numbers
        resolved_vars = {}
        for k, v in vars_dict.items():
            val = eval_expr(v, vars_dict)
            if val is not None:
                resolved_vars[k] = val

        # 2. Extract cube calls
        cube_matches = re.findall(r'cube\s*\(\s*\[([^\]]+)\]', content)
        for match in cube_matches:
            parts = match.split(',')
            if len(parts) != 3:
                continue
            
            dims = []
            valid = True
            for part in parts:
                val = eval_expr(part, resolved_vars)
                if val is None:
                    valid = False
                    break
                dims.append(float(val))
            
            if not valid:
                continue
                
            # Sort dimensions to easily find the cross section and length
            # The two smaller dimensions are the cross section (a x b)
            # The largest dimension is the length (c)
            dims.sort()
            a, b, c = dims
            
            # We assume it's a square tube if a == b, and it's not a plate (e.g. thickness >= 15)
            # and the cross section is realistic for a tube (<= 150)
            if a >= 15 and b >= 15 and a <= 150 and b <= 150 and c >= max(a, b):
                if a == b:
                    key = f"{int(a)}x{int(b)}"
                else:
                    key = f"{int(a)}x{int(b)} (Rectangular)"
                
                if key not in tubes:
                    tubes[key] = []
                tubes[key].append(c)

    print("=========================================")
    print(" Square Tube Requirements Calculation")
    print("=========================================\n")
    
    if not tubes:
        print("No tubes found.")
        return

    for key, lengths in tubes.items():
        print(f"Profile: {key} mm")
        print("-" * 30)
        
        # Count occurrences of each length
        length_counts = {}
        for length in lengths:
            l_int = int(length)
            length_counts[l_int] = length_counts.get(l_int, 0) + 1
            
        total_length = 0
        for length, count in sorted(length_counts.items(), reverse=True):
            print(f"  {count} pcs x {length} mm")
            total_length += length * count
            
        print(f"  ---\n  Total length: {total_length} mm ({total_length/1000.0:.2f} m)\n")

if __name__ == '__main__':
    cad_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'cad'))
    calculate_tubes(cad_path)
