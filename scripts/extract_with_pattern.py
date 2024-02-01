# 利用正则表达式辅助提取配置文件中的内容
import re
import sys

def extract_with_pattern(pattern_start, pattern_end, input_file):
    """
    Extracts content between the given start and end patterns from the input file.

    Args:
        pattern_start (str): The start pattern to search for.
        pattern_end (str): The end pattern to search for.
        input_file (str): The path to the input file.

    Returns:
        None
    """
    with open(input_file, 'r',encoding='utf-8') as file:
        content = file.read()
        pattern = re.compile(f'{re.escape(pattern_start)}(.*?){re.escape(pattern_end)}', re.DOTALL)
        match = pattern.search(content)
        if match:
            extracted_content = match.group(1)
            print(extracted_content)
        else:
            sys.exit(1)
    
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python extract_with_pattern.py <pattern_start> <pattern_end> <input_file>")
        sys.exit(1)
    pattern_start = sys.argv[1]
    pattern_end = sys.argv[2]
    input_file = sys.argv[3]
    extract_with_pattern(pattern_start, pattern_end,input_file)
