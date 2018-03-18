# Elm file reader

This package is a simple way to use the FileReader api from Elm.
It provides attributes that help handle the different events and read files
and send them as messages to Elm.

To make a file input and get a message in Elm, this is all you have to do:

```Elm
import FileReader

type Msg =
    FileSelected FileReader.File

Html.input (FileReader.fileInput FileSelected) []
```

## Example
Look in the examples folder. Live version at https://norpan.github.io/elm-file-reader-example.html
