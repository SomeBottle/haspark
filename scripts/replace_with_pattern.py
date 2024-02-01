# 利用正则表达式辅助替换配置文件中的内容
# 用系统自带的sed做这种事还是太鸡肋了
import re
import sys


def replace_between_patterns(pattern_start, pattern_end, replacement, input_file):
    """
    Replace content between specified patterns in the input file.

    Args:
        pattern_start (str): The starting pattern to search for.
        pattern_end (str): The ending pattern to search for.
        replacement (str): The content to replace the found pattern with.
        input_file (str): The file to read and write the replaced content to.

    Returns:
        None
    """
    with open(input_file, 'r+',encoding='utf-8') as file:
        content = file.read()
        pattern = re.compile(f'{re.escape(pattern_start)}.*?{re.escape(pattern_end)}', re.DOTALL)
        replaced_content = pattern.sub(replacement, content)
        file.seek(0)
        file.write(replaced_content)
        

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python replace_with_pattern.py <pattern_start> <pattern_end> <replacement> <input_file>")
        sys.exit(1)
    pattern_start = sys.argv[1]
    pattern_end = sys.argv[2]
    replacement = sys.argv[3]
    input_file = sys.argv[4]
    print(f"Replacing between {pattern_start} and {pattern_end} with {replacement} in {input_file}")
    replace_between_patterns(pattern_start, pattern_end, replacement, input_file)
