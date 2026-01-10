A tauri app for creating notes and assignments from a typst project. It is (very) opinionated to my own personal use.

# Using it

I am assuming basic knowledge of [typst](https://typst.app/).
- Copy the contents of the `typst` folder somewhere. The `note_template.typ` file can be renamed.
- Customize the content of `env.typ` to your liking. Some basic data like `course-name` and `instructor-name` could be set here. You can add/remove environments, and change the style.
- Run the `Note Creator`
- Locate the `note_template.typ`
- Give the app the location of `Assignments` and `Daynotes` folders
- ...
- Profit?

## Building it

For a Windows executable, check the Releases. For linux, clone the repo, set up rust, and build using `npm run tauri build` (if you are using linux, I am assuming you know your stuff). If you are using mac, good luck!