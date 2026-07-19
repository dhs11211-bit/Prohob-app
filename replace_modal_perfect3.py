import sys

target = 'D:/Projects/David/Devoted/prohob-app/lib/custom_code/widgets/admin_customers_view.dart'
modal = 'D:/Projects/David/Devoted/worker_modal_fixed3.dart'

with open(target, 'r', encoding='utf-8') as f:
    text = f.read()

with open(modal, 'r', encoding='utf-8') as f:
    modal_text = f.read()

modal_text = modal_text.strip() + "\n\n"

t_start_idx = text.find('  void _showCreateJobModal() {')
t_end_idx = text.find('  @override\n  Widget build(BuildContext context) {')

if t_start_idx != -1 and t_end_idx != -1:
    new_text = text[:t_start_idx] + modal_text + text[t_end_idx:]
    with open(target, 'w', encoding='utf-8') as f:
        f.write(new_text)
    print("Perfect replacement done!")
else:
    print("Could not find start or end index!")
