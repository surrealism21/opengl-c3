# Opengl C3 bindings generator

Updated by surrealism21 for the newest versions of c3. Note that the examples have *not* been updated and I do not plan to update them...

### Building

Git clone the repository and run `git submodule init && git submodule update` to get OpenGL submodules 

Make sure [dart](https://dart.dev/) is installed 

Install dart packages `dart pub get`

Build C3 binding `dart run main.dart`



### Using 

Download `opengl.c3l` file and then copy it to your C3 project dependencies folder.

C3 project.json example

```
"dependency-search-paths": [ "lib" ],
"dependencies": [ "opengl" ],

"linked-libraries": ["GL"],
"linker-search-paths": ["lib"],
```
