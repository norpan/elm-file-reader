module FileReader exposing (DataFormat(..), Error, File, dropZone, fileInput, filesInput)

{-| This module exposes attributes that you can use to read
files into Elm.

@docs File, DataFormat, Error
@docs fileInput, filesInput, dropZone

-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Time exposing (Time)


{-| The result of a file reading operation
-}
type alias File =
    { lastModified : Time
    , name : String
    , size : Int
    , mimeType : String
    , dataFormat : DataFormat
    , data : Result Error String
    }


{-| The format you want your data in.
`DataURL` - a data URL as specified by RFC 2397.
`Base64` - Base64 encoded as specified by RFC 4648
`Text encoding` - Text, encoded using the specified encoding (See <https://www.w3.org/TR/encoding/#concept-encoding-get>)
-}
type DataFormat
    = DataURL
    | Base64
    | Text String


{-| An error returned from file reading. This corresponds to a
`DomException` (name and message) or a `FileError` (code)
gotten when trying to read the file.
-}
type alias Error =
    { code : Int, name : String, message : String }


fileDecoder : Json.Decode.Decoder File
fileDecoder =
    Json.Decode.map6 File
        (Json.Decode.field "lastModified" Json.Decode.float)
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "size" Json.Decode.int)
        (Json.Decode.field "mimeType" Json.Decode.string)
        dataFormatDecoder
        (Json.Decode.oneOf
            [ Json.Decode.map Ok (Json.Decode.field "data" Json.Decode.string)
            , Json.Decode.map Err errorDecoder
            ]
        )


errorDecoder : Json.Decode.Decoder Error
errorDecoder =
    Json.Decode.map3 Error
        (Json.Decode.field "errorCode" Json.Decode.int |> default 0)
        (Json.Decode.field "errorName" Json.Decode.string |> default "")
        (Json.Decode.field "errorMessage" Json.Decode.string |> default "")


default : a -> Json.Decode.Decoder a -> Json.Decode.Decoder a
default a decoder =
    Json.Decode.oneOf [ decoder, Json.Decode.succeed a ]


dataFormatDecoder : Json.Decode.Decoder DataFormat
dataFormatDecoder =
    Json.Decode.field "dataFormat" Json.Decode.string
        |> Json.Decode.andThen
            (\dataFormat ->
                case dataFormat of
                    "DataURL" ->
                        Json.Decode.succeed DataURL

                    "Base64" ->
                        Json.Decode.succeed Base64

                    "Text" ->
                        Json.Decode.map Text (Json.Decode.field "encoding" Json.Decode.string)

                    _ ->
                        Json.Decode.fail ("Unknown data format: " ++ dataFormat)
            )


{-| Add these attributes to an input node to get the contents of the selected file.

    type Msg
        = FileSelected File

    view =
        Html.input (fileInput DataURL FileSelected) []

-}
fileInput :
    DataFormat
    -> (File -> msg)
    -> List (Html.Attribute msg)
fileInput dataFormat fileMsg =
    [ Html.Attributes.type_ "file"
    , Html.Attributes.attribute "onchange" onChangeHandler
    , Html.Events.on "files"
        (Json.Decode.map fileMsg
            (Json.Decode.field "detail"
                (Json.Decode.index 0 fileDecoder)
            )
        )
    ]
        ++ dataFormatAttributes dataFormat


{-| Add these attributes to an input node to get the contents of the selected files.

    type Msg
        = FilesSelected (List File)

    view =
        Html.input (filesInput DataURL FilesSelected) []

-}
filesInput :
    DataFormat
    -> (List File -> msg)
    -> List (Html.Attribute msg)
filesInput dataFormat filesMsg =
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
        ++ dataFormatAttributes dataFormat


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
                { dataFormat = Base64
                , enterMsg = EnterDropZone
                , leaveMsg = LeaveDropZone
                , filesMsg = FilesDropped
                }
            )
            [ Html.text "Drop files here" ]

-}
dropZone :
    { dataFormat : DataFormat
    , enterMsg : msg
    , leaveMsg : msg
    , filesMsg : List File -> msg
    }
    -> List (Html.Attribute msg)
dropZone { dataFormat, enterMsg, leaveMsg, filesMsg } =
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
        ++ dataFormatAttributes dataFormat


dataFormatAttributes : DataFormat -> List (Html.Attribute msg)
dataFormatAttributes dataFormat =
    case dataFormat of
        DataURL ->
            [ Html.Attributes.attribute "data-format" "DataURL" ]

        Base64 ->
            [ Html.Attributes.attribute "data-format" "Base64" ]

        Text encoding ->
            [ Html.Attributes.attribute "data-format" "Text"
            , Html.Attributes.attribute "data-encoding" encoding
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
    var fileObjects = [];
    var index = 0;
    var reader = new FileReader();
    var dataFormat = event.target.dataset.format;
    var encoding = event.target.dataset.encoding;
    reader.onload = function() {
        var data;
        switch(dataFormat) {
            case 'DataURL':
            case 'Text':
                data = reader.result;
                break;
            case 'Base64':
                data = reader.result.split(',')[1];
                break;
        }
        var lastModified = files[index].lastModified;
        if (!lastModified) {
          lastModified = files[index].lastModifiedDate.getTime();
        }
        var result =
            { lastModified: lastModified
            , name: files[index].name
            , size: files[index].size
            , mimeType: files[index].type
            , dataFormat: dataFormat
            , encoding: encoding
            , data: data
            };
        fileObjects.push(result);
        index++;
        readOne();
    }
    reader.onerror = function () {
        var lastModified = files[index].lastModified;
        if (!lastModified) {
          lastModified = files[index].lastModifiedDate.getTime();
        }
        var result =
            { lastModified: lastModified
            , name: files[index].name
            , size: files[index].size
            , mimeType: files[index].type
            , dataFormat: dataFormat
            , encoding: encoding
            , errorCode: reader.error.code
            , errorName: reader.error.name
            , errorMessage: reader.error.message
            };
        fileObjects.push(result);
        index++;
        readOne();
    }
    function readOne() {
        var file = files[index];
        if (file) {
            switch(dataFormat) {
                case 'DataURL':
                case 'Base64':
                    reader.readAsDataURL(file);
                    break;
                case 'Text':
                    reader.readAsText(file, encoding);
                    break;
            }
        } else {
            if (fileObjects.length > 0) {
                var filesEvent;
                try {
                  filesEvent = new CustomEvent("files", { detail: fileObjects });
                } catch(e) {
                  filesEvent = document.createEvent("CustomEvent");
                  filesEvent.initCustomEvent("files", false, false, fileObjects);
                }
                event.target.dispatchEvent(filesEvent);
            }
        }
      }
    readOne();
"""
