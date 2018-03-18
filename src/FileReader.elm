module FileReader exposing (File, dropZone, fileInput, filesInput)

{-| This module exposes attributes that you can use to read
files into Elm.

@docs File
@docs fileInput, filesInput, dropZone

-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Time exposing (Time)


{-| A selected file that has been read into the application.
The file contents are in the form of a data URL as specified by RFC 2397.

`lastModified` is of type `Maybe Time` because not all browsers and situations
will give you a last modified field.

-}
type alias File =
    { lastModified : Maybe Time
    , name : String
    , size : Int
    , mimeType : String
    , dataURL : String
    }


fileDecoder : Json.Decode.Decoder File
fileDecoder =
    Json.Decode.map5 File
        (Json.Decode.maybe (Json.Decode.field "lastModified" Json.Decode.float))
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "size" Json.Decode.int)
        (Json.Decode.field "mimeType" Json.Decode.string)
        (Json.Decode.field "dataURL" Json.Decode.string)


{-| Add these attributes to an input node to get the contents of the selected file.

    type Msg
        = FileSelected File

    view =
        Html.input (fileInput FileSelected) []

-}
fileInput :
    (File -> msg)
    -> List (Html.Attribute msg)
fileInput fileMsg =
    [ Html.Attributes.type_ "file"
    , Html.Attributes.attribute "onchange" onChangeHandler
    , Html.Events.on "files"
        (Json.Decode.map fileMsg
            (Json.Decode.field "detail"
                (Json.Decode.index 0 fileDecoder)
            )
        )
    ]


{-| Add these attributes to an input node to get the contents of the selected files.

    type Msg
        = FilesSelected (List File)

    view =
        Html.input (filesInput FilesSelected) []

-}
filesInput :
    (List File -> msg)
    -> List (Html.Attribute msg)
filesInput filesMsg =
    [ Html.Attributes.type_ "file"
    , Html.Attributes.multiple True
    , Html.Attributes.attribute "onchange" onChangeHandler
    , Html.Events.on "files"
        (Json.Decode.map filesMsg
            (Json.Decode.field "detail"
                (Json.Decode.list fileDecoder)
            )
        )
    ]


{-| Add these attributes to any node to create a "drop zone" for files
and get the contents of the dropped files. The `enterMsg` and `leaveMsg`
messages could be used to visually indicate the drop zone.

You will either get a `leaveMsg` or a `filesMsg`, so make sure the `filesMsg`
also clears any visual indication started by the `enterMsg`.

    type Msg
        = EnterDropZone
        | LeaveDropZone
        | FilesDropped (List File)

    view =
        Html.div
            (dropZone
                { enterMsg = EnterDropZone
                , leaveMsg = LeaveDropZone
                , filesMsg = FilesDropped
                }
            )
            [ Html.text "Drop files here" ]

-}
dropZone :
    { enterMsg : msg
    , leaveMsg : msg
    , filesMsg : List File -> msg
    }
    -> List (Html.Attribute msg)
dropZone { enterMsg, leaveMsg, filesMsg } =
    [ Html.Events.onWithOptions "dragenter"
        { preventDefault = True, stopPropagation = True }
        (Json.Decode.succeed enterMsg)
    , Html.Events.onWithOptions "dragleave"
        { preventDefault = True, stopPropagation = True }
        (Json.Decode.succeed leaveMsg)
    , Html.Attributes.attribute "ondragover" "event.preventDefault(); event.stopPropagation();"
    , Html.Attributes.attribute "ondrop" onDropHandler
    , Html.Events.on "files"
        (Json.Decode.map filesMsg
            (Json.Decode.field "detail"
                (Json.Decode.list fileDecoder)
            )
        )
    ]


onDropHandler : String
onDropHandler =
    """
    event.preventDefault();
    event.stopPropagation();
    var files = event.dataTransfer.files;
    """ ++ handleFiles


onChangeHandler : String
onChangeHandler =
    """
    event.preventDefault();
    event.stopPropagation();
    var files = event.target.files;
    """ ++ handleFiles


handleFiles : String
handleFiles =
    """
    var fileObjects = []
    var index = 0;
    var reader = new FileReader();
    reader.onload = function() {
        var result =
            { lastModified: files[index].lastModified
            , name: files[index].name
            , size: files[index].size
            , mimeType: files[index].type
            , dataURL: reader.result
            };
        fileObjects.push(result);
        index++;
        readOne();
    }
    function readOne() {
        var file = files[index]
        if (file) {
            reader.readAsDataURL(file);
        } else {
            if (fileObjects.length > 0) {
                var fileEvent;
                try {
                  filesEvent = new CustomEvent("files", { detail: fileObjects });
                } catch(e) {
                  filesEvent = document.createEvent("CustomEvent");
                  filesEvent.initCustomEvent("files", false, false, fileObjects);
                }
                event.target.dispatchEvent(filesEvent);
                console.log(filesEvent);
            }
        }
      }
    readOne();
"""
