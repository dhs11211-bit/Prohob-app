import sys

with open('../clean_diff_2218.patch', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'The following is an <EPHEMERAL_MESSAGE>' in line:
        break
    # Check if the file has double newlines
    if line.endswith('\n\n'):
        new_lines.append(line[:-1])
    else:
        new_lines.append(line)

with open('../fixed_diff_2218.patch', 'w', encoding='utf-8', newline='\n') as f:
    for line in new_lines:
        if line == '\n':
            continue # Try removing empty lines that might be double newlines? No, diffs need SOME empty lines if they are context lines.
        # Actually let's just strip \r then do replace \n\n with \n
        pass

# A better way is to read all text, replace \n\n with \n, and split.
with open('../clean_diff_2218.patch', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('The following is an <EPHEMERAL_MESSAGE>')
if idx != -1:
    text = text[:idx]

text = text.replace('\n\n', '\n')
text = text.replace('\n\n', '\n') # do it twice just in case

with open('../fixed_diff_2218.patch', 'w', encoding='utf-8', newline='\n') as f:
    f.write(text)

print("Fixed diff!")
