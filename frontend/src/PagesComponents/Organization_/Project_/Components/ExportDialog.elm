module PagesComponents.Organization_.Project_.Components.ExportDialog exposing (Model, Msg(..), init, update, view)

import Components.Molecules.Modal as Modal
import Components.Slices.ExportDialogBody as ExportDialogBody
import Html exposing (Html)
import Libs.Models.HtmlId exposing (HtmlId)
import Libs.Task as T
import Models.Project.LayoutName exposing (LayoutName)
import Models.Project.ProjectName exposing (ProjectName)
import Models.ProjectRef exposing (ProjectRef)
import PagesComponents.Organization_.Project_.Models.Erd exposing (Erd)
import PagesComponents.Organization_.Project_.Updates.Extra as Extra exposing (Extra)
import Services.Lenses exposing (mapBodyT, mapMT)


dialogId : HtmlId
dialogId =
    "export-dialog"


type alias Model =
    { id : HtmlId, body : ExportDialogBody.Model }


type Msg
    = Open
    | Close
    | BodyMsg ExportDialogBody.Msg


init : ProjectName -> LayoutName -> Model
init project layout =
    { id = dialogId, body = ExportDialogBody.init dialogId project layout }


update : (Msg -> msg) -> (HtmlId -> msg) -> ProjectRef -> Erd -> Msg -> Maybe Model -> ( Maybe Model, Extra msg )
update wrap modalOpen projectRef erd msg model =
    case msg of
        Open ->
            ( Just (init erd.project.name erd.currentLayout), modalOpen dialogId |> T.sendAfter 1 |> Extra.cmd )

        Close ->
            ( Nothing, Extra.none )

        BodyMsg message ->
            model |> mapMT (mapBodyT (ExportDialogBody.update (BodyMsg >> wrap) projectRef erd message)) |> Extra.defaultT


view : (Msg -> msg) -> (Cmd msg -> msg) -> (msg -> msg) -> Bool -> ProjectRef -> Model -> Html msg
view wrap send modalClose opened project model =
    let
        titleId : HtmlId
        titleId =
            model.id ++ "-title"
    in
    Modal.modal
        { id = model.id
        , titleId = titleId
        , isOpen = opened
        , onBackgroundClick = Close |> wrap |> modalClose
        }
        [ ExportDialogBody.view (BodyMsg >> wrap) send (Close |> wrap |> modalClose) titleId project model.body
        ]
