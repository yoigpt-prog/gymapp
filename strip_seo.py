import os
import re

files_to_process = [
    'lib/pages/calculators/body_fat_calculator_page.dart',
    'lib/pages/calculators/calorie_calculator_page.dart',
    'lib/pages/calculators/macro_calculator_page.dart',
    'lib/pages/calculators/one_rm_calculator_page.dart',
    'lib/pages/home_page.dart',
    'lib/pages/download_page.dart'
]

def process_file(filepath):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
        
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    
    # Remove import
    content = re.sub(r"import 'package:seo/seo\.dart';\n", '', content)

    # We can handle Seo.head( ... child: X ) -> X.
    # The regex looks for `return Seo.head(\n      tags: const [\n        MetaTag( ... ),\n      ],\n      child: LegalPageLayout(`
    # or similar
    content = re.sub(r"return Seo\.head\([\s\S]*?child:\s*(LegalPageLayout\()", r"return \1", content)
    content = re.sub(r"return Seo\.head\([\s\S]*?child:\s*(Scaffold\()", r"return \1", content)
    content = re.sub(r"return Seo\.head\([\s\S]*?child:\s*(MainScaffold\()", r"return \1", content)
    
    # In download_page.dart, the last parenthesis of Seo.head needs removing
    # Actually, we can just replace the end of the build method.
    # It's better to just write a simple bracket matcher if we really need to strip the last parenthesis, but:
    # return Seo.head( ... child: XXX( ... ) ); -> return XXX( ... );
    # This means the last `);` at the end of the Widget build method is actually `),` or `);`.
    # Let's just find `Seo.text(...)` and remove it entirely.
    
    # Remove all Seo.text
    # We can match `Seo.text(` and balance brackets.
    def remove_seo_text(text):
        while 'Seo.text(' in text:
            start_idx = text.find('Seo.text(')
            # Find the end of the Seo.text block
            open_brackets = 0
            end_idx = start_idx
            for i in range(start_idx, len(text)):
                if text[i] == '(':
                    open_brackets += 1
                elif text[i] == ')':
                    open_brackets -= 1
                    if open_brackets == 0:
                        end_idx = i + 1
                        break
            # Now we have the block. Wait, there is a `,` after it sometimes.
            if end_idx < len(text) and text[end_idx] == ',':
                end_idx += 1
            # Remove from start_idx to end_idx
            # But wait! The `child: Text(...)` inside Seo.text MUST NOT BE REMOVED! 
            # Oh wait, the user said "undo last changes, Do NOT change any frontend UI".
            # The Seo.text was purely ADDED at the very bottom of the page, so it CAN be removed entirely!
            # Wait, in home_page.dart, I might have wrapped existing Text widgets with Seo.text!
            text = text[:start_idx] + text[end_idx:]
        return text

    # Wait, in home_page.dart, I might have wrapped existing things. Let's check!
    # I better just look at the diff.
    pass

