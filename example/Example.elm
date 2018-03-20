module Example exposing (..)

import FileReader
import Html exposing (Html)
import Html.Attributes
import MimeType


type alias Model =
    { singleFile : Maybe FileReader.File
    , multipleFiles : List FileReader.File
    , inDropZone : Bool
    , droppedFiles : List FileReader.File
    }


type Msg
    = SingleFile FileReader.File
    | MultipleFiles (List FileReader.File)
    | DropZoneEntered
    | DropZoneLeaved
    | FilesDropped (List FileReader.File)


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , init = init
        }


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.h2 [] [ Html.text "File reader using DataURL" ]
        , Html.input (FileReader.fileInput FileReader.DataURL SingleFile) []
        , case model.singleFile of
            Just file ->
                viewFile file

            Nothing ->
                Html.text ""
        , Html.hr [] []
        , Html.h2 [] [ Html.text "Files reader using Base64" ]
        , Html.input (FileReader.filesInput FileReader.Base64 MultipleFiles) []
        , if List.length model.multipleFiles > 0 then
            Html.div [] (List.map viewFile model.multipleFiles)
          else
            Html.text ""
        , Html.hr [] []
        , Html.h2 [] [ Html.text "Drop zone using Text latin1" ]
        , Html.div
            ([ Html.Attributes.style
                ([ ( "border", "1px solid" ) ]
                    ++ (if model.inDropZone then
                            [ ( "background", "lightblue" ) ]
                        else
                            []
                       )
                )
             ]
                ++ FileReader.dropZone
                    { dataFormat = FileReader.Text "latin1"
                    , enterMsg = DropZoneEntered
                    , leaveMsg = DropZoneLeaved
                    , filesMsg = FilesDropped
                    }
            )
            [ Html.text "Drop files here" ]
        , if List.length model.droppedFiles > 0 then
            Html.div [] (List.map viewFile model.droppedFiles)
          else
            Html.text ""
        ]


viewFile : FileReader.File -> Html Msg
viewFile file =
    Html.div []
        [ Html.dl []
            [ Html.dt [] [ Html.text "File name" ]
            , Html.dd [] [ Html.text file.name ]
            , Html.dt [] [ Html.text "File size" ]
            , Html.dd [] [ Html.text (toString file.size) ]
            , Html.dt [] [ Html.text "Last modified" ]
            , Html.dd [] [ Html.text (toString file.lastModified) ]
            , Html.dt [] [ Html.text "Mime type" ]
            , Html.dd [] [ Html.text file.mimeType ]
            , Html.dt [] [ Html.text "Data format" ]
            , Html.dd [] [ Html.text (toString file.dataFormat) ]
            , Html.dt [] [ Html.text "Data" ]
            , Html.dd []
                (case file.data of
                    Ok data ->
                        case ( file.dataFormat, MimeType.parseMimeType file.mimeType ) of
                            ( FileReader.DataURL, Just (MimeType.Image _) ) ->
                                [ Html.img [ Html.Attributes.src data ] [] ]

                            _ ->
                                [ Html.text data ]

                    Err error ->
                        [ Html.text ("Error: " ++ toString error.code ++ " " ++ error.name ++ " " ++ error.message) ]
                )
            ]
        ]


init : ( Model, Cmd Msg )
init =
    ( { singleFile = Nothing
      , multipleFiles = []
      , inDropZone = False
      , droppedFiles = []
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( case msg of
        SingleFile file ->
            { model | singleFile = Just file }

        MultipleFiles files ->
            { model | multipleFiles = files }

        DropZoneEntered ->
            { model | inDropZone = True }

        DropZoneLeaved ->
            { model | inDropZone = False }

        FilesDropped files ->
            { model | inDropZone = False, droppedFiles = files }
    , Cmd.none
    )
