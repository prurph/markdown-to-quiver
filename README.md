## A humble Ruby script to convert markdown files to [Quiver](http://happenapps.com/#quiver) notes.

### Setup:
1. Get `quiver_import.rb`
2. All `.md` files in a directory will be packaged in one Quiver notebook
  - Relative paths to images will be respected.
  - Code blocks may have no language, or [one of these abbreviations](https://github.com/HappenApps/Quiver/wiki/Syntax-Highlighting-Supported-Languages). Other languages won't break the import but Quiver won't understand and the note will look truncated/broken until you manually give each of these blocks a valid language.
3. Run like this: `ruby quiver_import.rb <directory to export> <path-to-new-notebook>.qvnotebook <'Notebook Name'>`
4. From within Quiver, select `File > Import Notebook` and select your .qvnotebook directory

### Questions/Problems?
[Reach out!](https://github.com/prurph/markdown-to-quiver/issues)
