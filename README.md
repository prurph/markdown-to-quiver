## A humble Ruby script to convert markdown files to [Quiver](http://happenapps.com/#quiver) notes.

### Setup
1. Get `quiver_import.rb`
2. All `.md` files in a directory will be packaged in one Quiver notebook
  - Relative paths to images will be respected.
  - Code blocks may have no language, or [one of these abbreviations](https://github.com/HappenApps/Quiver/wiki/Syntax-Highlighting-Supported-Languages). Other languages won't break the import but Quiver won't understand and the note will look truncated/broken until you manually give each of these blocks a valid language.
3. Run like this: `ruby quiver_import.rb <directory to export> <path-to-new-notebook>.qvnotebook <'Notebook Name'>`
4. From within Quiver, select `File > Import Notebook` and select your .qvnotebook directory

### Tags and Titles
The script will attempt to parse the title and tags from the first and second lines
of the file, respectively.

It expects something like this on the first two lines:

```md
# An h1 for the title!
[bracketed, tags, comma | pipe | or whitespace separated]
```

If either parse succeeds, the first two lines of the note are omitted from the body of the final quiver note.

There is definitely room for this to be more sophisticated.

### Questions/Problems?
[Reach out!](https://github.com/prurph/markdown-to-quiver/issues)
