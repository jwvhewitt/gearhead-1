#! /usr/bin/env python
# -*- coding: latin-1 -*-

import os
import re

EXTENSIONS = [".txt", ".pp", ".pas"]

def make_replacement(old, new):
  regex = re.compile(r"\b%s\b" % re.escape(old))
  for dir_path, _, filenames in os.walk("."):
    for filename in filenames:
      if os.path.splitext(filename)[1].lower() not in EXTENSIONS:
        continue
      full_path = os.path.join(dir_path, filename)
      full_path = os.path.normpath(full_path)
      text = open(full_path).read()
      new_text, replace_no = regex.subn(new, text)
      if replace_no:
        print "%dx %r => %r in %s." % (replace_no, old, new, full_path)
        open(full_path, "w").write(new_text)
      if old in new_text:
        print "Warning: %r occurs in %s within another word." % (old, full_path)

if __name__ == "__main__":
  import sys
  if len(sys.argv) != 3:
    print """Usage: replace.py <old_word> <new_word>

Recursively walk through all files and directories in the current directory,
replacing <old_word> by <new_word>. The appropriate replacements are made when
<old_word> occurs in capitalized and upper-case form, i.e. "replace.py
medicene medicine" also replaces "Medicene" by "Medicine" and "MEDICENE" by
"MEDICINE".

Only whole words are replaced, i.e. "replace.py foo bar" does not replace
"fool" by "barl", since this would often have unintended consequences.
However, if <old_word> is found as part of another word in some file, a
warning message is emitted so that the user can check the file and make a
manual replacement if appropriate."""
    raise SystemExit(2)

  old, new = sys.argv[1:3]
  make_replacement(old, new)
  make_replacement(old.capitalize(), new.capitalize())
  make_replacement(old.upper(), new.upper())
