***TEAM MEMBERS***

**CHANGE ABSOLUTELY NOTHING IN THE .gitignore FILE**

BEFORE YOU DO ANYTHING USING THIS REPO!!!!
YOU MUST DO THIS:
1. Go to Command Prompt (search "cmd" in the windows explorer)
2. Type or copy exactly this: git clone https://github.com/ethanledbetter1625-glitch/cpe304finalproj
3. Open Quartus
4. Open project
5. Open the .qpf file in the directory

^You only need to do this once.^

To make and save changes:
1. Use Quartus to make changes.
2. Save your progress (CTRL+S).
3. Close Quartus.
4. Open Command Prompt (same as before).
5. Type: cd filepathtoproject (ends in FinalProject)
6. Type: git status
7. Type: git add .
8. Type: git commit -m "Short description of changes."
9. Type: git push origin main

To get the most updated version of what is on GitHub:
1. cd into the directory
2. Type: git pull origin main

Quartus will automatically detect that the VHDL files changed on your hard drive and will ask if you want to reload them.

It is important that we do not overlap changes. If you are working as a pair (or more), it will be best to work off of one computer. 

If you want to see a visual representation of the branches, run "gitk --all" in cmd prompt while in the file directory.
