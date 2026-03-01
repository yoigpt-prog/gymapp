import re

with open('lib/pages/custom_plan_quiz.dart', 'r') as f:
    content = f.read()

# 1. Update the progress bar calculation
content = re.sub(
    r'double progress = \(questionNumber / \d+\).clamp\(0\.0, 1\.0\);',
    r'double progress = (questionNumber / 26).clamp(0.0, 1.0);',
    content
)
content = re.sub(
    r"'Question \$questionNumber of \d+',",
    r"'Question $questionNumber of 26',",
    content
)

# 2. Update the switch cases
# Old mapping:
# case 0: Welcome
# case 1: Name (REMOVE)
# case 2: Gender -> new case 1
# case 3: Age -> new case 2 ...
# case 20: Diet -> new case 19
# case 21: Exclude Foods (REMOVE)
# case 22: Allergies -> new case 20 ...
# case 27: Work Type -> new case 25
# case 28: Avoid Movements (REMOVE)
# case 29: Water Intake -> new case 26
# case 30: Summary -> new case 27
# case 31: Progress -> new case 28
# case 32: Upgrade -> new case 29

switch_start = content.find("switch (currentScreen) {")
switch_end = content.find("}", switch_start)
switch_block = content[switch_start:switch_end]

mapping = {
    0: 0,
    2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9, 11: 10,
    12: 11, 13: 12, 14: 13, 15: 14, 16: 15, 17: 16, 18: 17, 19: 18, 20: 19,
    22: 20, 23: 21, 24: 22, 25: 23, 26: 24, 27: 25,
    29: 26, 30: 27, 31: 28, 32: 29
}

new_switch_lines = ["switch (currentScreen) {"]
new_switch_lines.append("      case 0: return _buildWelcomeScreen();")
for old, new_idx in mapping.items():
    if old == 0: continue
    # extract the return XYZ statement
    # e.g. case 2: return _buildGenderScreen(isDarkMode);
    match = re.search(f'case {old}:\s+(return.*?);', switch_block)
    if match:
        new_switch_lines.append(f"      case {new_idx}: {match.group(1)};")
new_switch_lines.append("      default: return _buildWelcomeScreen();")
new_switch_block = "\n".join(new_switch_lines)

content = content[:switch_start] + new_switch_block + content[switch_end:]

# 3. Update the startPlanGeneration target
content = re.sub(
    r'nextScreen\(31\); // Progress Screen',
    r'nextScreen(28); // Progress Screen',
    content
)
content = re.sub(
    r'nextScreen\(32\); // Upgrade Screen',
    r'nextScreen(29); // Upgrade Screen',
    content
)

# 4. Remove the methods
def remove_method(method_name):
    global content
    idx = content.find(f"Widget {method_name}(")
    if idx != -1:
        end_idx = content.find("  Widget _build", idx + 10)
        if end_idx != -1:
            content = content[:idx] + content[end_idx:]

remove_method("_buildNameScreen")
remove_method("_buildExcludeFoodsScreen")
remove_method("_buildAvoidMovementsScreen")

# 5. Update questionNumber and nextScreen in the remaining widgets
for old, new_idx in mapping.items():
    if old == 0: continue
    # old corresponds to the OLD questionNumber
    # we need to find questionNumber: {old}, and replace with questionNumber: {new_idx},
    # BUT wait, the regex should target exactly that.
    content = re.sub(f'questionNumber: {old},', f'questionNumber: {new_idx},', content)
    
    # And replace the onContinue/nextScreen calls
    # For a given screen 'old', its "nextScreen" used to be old+1 (or some logic)
    # The simplest is: the old nextScreen for old=2 was 3. So if we see nextScreen(3), it should be nextScreen(mapping[3])
    # However, some might be hardcoded, some might be `questionNumber + 1`.
    
# Let's manually replace all hardcoded nextScreen(X) calls.
for old, new_idx in mapping.items():
    content = re.sub(f'nextScreen\({old}\)', f'nextScreen({new_idx})', content)

with open('lib/pages/custom_plan_quiz.dart', 'w') as f:
    f.write(content)
print("Done.")
