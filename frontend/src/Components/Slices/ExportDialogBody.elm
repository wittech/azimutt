module Components.Slices.ExportDialogBody exposing (DocState, ExportInput, Model, Msg(..), SharedDocState, doc, docInit, init, update, view)

import Components.Atoms.Button as Button
import Components.Atoms.Icon as Icon exposing (Icon(..))
import Components.Molecules.Radio as Radio
import Components.Slices.PlanDialog as PlanDialog
import Conf exposing (constants)
import DataSources.JsonMiner.JsonAdapter as JsonAdapter
import DataSources.SqlMiner.MysqlGenerator as MysqlGenerator
import DataSources.SqlMiner.PostgreSqlGenerator as PostgreSqlGenerator
import Dict
import ElmBook
import ElmBook.Actions exposing (logAction)
import ElmBook.Chapter as Chapter exposing (Chapter)
import Html exposing (Html, code, div, h3, p, pre, text)
import Html.Attributes exposing (class, id)
import Html.Events exposing (onClick)
import Libs.Dict as Dict
import Libs.Html exposing (extLink)
import Libs.Html.Attributes exposing (css)
import Libs.Maybe as Maybe
import Libs.Models.FileName exposing (FileName)
import Libs.Models.HtmlId exposing (HtmlId)
import Libs.Remote as Remote exposing (Remote(..))
import Libs.Tailwind as Tw exposing (sm)
import Libs.Task as T
import Models.Dialect as Dialect exposing (Dialect)
import Models.Feature as Feature
import Models.Organization as Organization
import Models.Project as Project exposing (Project)
import Models.Project.Check as Check
import Models.Project.Column as Column exposing (docColumn)
import Models.Project.Layout as Layout
import Models.Project.LayoutName exposing (LayoutName)
import Models.Project.PrimaryKey as PrimaryKey
import Models.Project.ProjectName exposing (ProjectName)
import Models.Project.Relation as Relation
import Models.Project.Schema as Schema exposing (Schema)
import Models.Project.Source as Source
import Models.Project.Table as Table exposing (docTable)
import Models.Project.Unique as Unique
import Models.ProjectRef as ProjectRef exposing (ProjectRef)
import PagesComponents.Organization_.Project_.Models.Erd as Erd exposing (Erd)
import PagesComponents.Organization_.Project_.Models.ErdLayout exposing (ErdLayout)
import PagesComponents.Organization_.Project_.Models.ErdTableLayout exposing (ErdTableLayout)
import PagesComponents.Organization_.Project_.Updates.Extra as Extra exposing (Extra)
import Ports
import Services.Lenses exposing (mapProject, setChecks, setCurrentLayout, setLayouts, setOrganization, setPrimaryKey, setUniques)
import Track


type alias Model =
    { id : HtmlId
    , project : ProjectName
    , layout : LayoutName
    , input : Maybe ExportInput
    , format : Maybe Dialect
    , output : Remote String String
    }


type Msg
    = SetInput ExportInput
    | SetFormat Dialect
    | GetOutput ExportInput Dialect
    | GotOutput Dialect String


type ExportInput
    = Project
    | AllTables
    | CurrentLayout


init : HtmlId -> ProjectName -> LayoutName -> Model
init id project layout =
    { id = id, project = project, layout = layout, input = Nothing, format = Nothing, output = Pending }


update : (Msg -> msg) -> ProjectRef -> Erd -> Msg -> Model -> ( Model, Extra msg )
update wrap projectRef erd msg model =
    case msg of
        SetInput source ->
            { model | input = Just source } |> shouldGetOutput wrap

        SetFormat format ->
            { model | format = Just format } |> shouldGetOutput wrap

        GetOutput source format ->
            ( { model | output = Fetching }, getOutput wrap projectRef erd source format )

        GotOutput format content ->
            if model.format == Just format || model.input == Just Project then
                ( { model | output = Fetched content }, Extra.none )

            else
                ( model, Extra.none )


shouldGetOutput : (Msg -> msg) -> Model -> ( Model, Extra msg )
shouldGetOutput wrap model =
    if model.output /= Fetching then
        ( { model | output = Pending }
        , if model.input == Just Project then
            GetOutput Project Dialect.JSON |> wrap |> Extra.msg

          else
            Maybe.map2 GetOutput model.input model.format |> Maybe.map wrap |> Extra.msgM
        )

    else
        ( model, Extra.none )


getOutput : (Msg -> msg) -> ProjectRef -> Erd -> ExportInput -> Dialect -> Extra msg
getOutput wrap projectRef erd input format =
    case input of
        Project ->
            if not (Organization.canExportProject projectRef) then
                Extra.cmdL [ GotOutput format "plan_limit" |> wrap |> T.send, Track.planLimit Feature.projectExport (Just erd) ]

            else
                erd |> Erd.unpack |> Project.downloadContent |> (GotOutput format >> wrap >> Extra.msg)

        AllTables ->
            if format /= Dialect.AML && format /= Dialect.JSON && not (Organization.canExportSchema projectRef) then
                Extra.cmdL [ GotOutput format "plan_limit" |> wrap |> T.send, Track.planLimit Feature.schemaExport (Just erd) ]

            else if format == Dialect.AML || format == Dialect.JSON then
                -- generate from JS, not Elm
                erd |> Erd.toSchema |> (JsonAdapter.unpackSchema >> Ports.getCode format >> Extra.cmd)

            else
                erd |> Erd.toSchema |> generateTables format |> (GotOutput format >> wrap >> Extra.msg)

        CurrentLayout ->
            if format /= Dialect.AML && format /= Dialect.JSON && not (Organization.canExportSchema projectRef) then
                Extra.cmdL [ GotOutput format "plan_limit" |> wrap |> T.send, Track.planLimit Feature.schemaExport (Just erd) ]

            else if format == Dialect.AML || format == Dialect.JSON then
                -- generate from JS, not Elm
                (erd |> Erd.toSchema)
                    |> Schema.filter (erd.layouts |> Dict.get erd.currentLayout |> Maybe.mapOrElse (.tables >> List.map .id) [])
                    |> (JsonAdapter.unpackSchema >> Ports.getCode format >> Extra.cmd)

            else
                (erd |> Erd.toSchema)
                    |> Schema.filter (erd.layouts |> Dict.get erd.currentLayout |> Maybe.mapOrElse (.tables >> List.map .id) [])
                    |> generateTables format
                    |> (GotOutput format >> wrap >> Extra.msg)


generateTables : Dialect -> Schema -> String
generateTables format schema =
    case format of
        Dialect.AML ->
            -- see frontend/ts-src/index.ts:448 (getCode)
            "Can't generate AML from Elm"

        Dialect.PostgreSQL ->
            PostgreSqlGenerator.generate schema

        Dialect.MySQL ->
            MysqlGenerator.generate schema

        Dialect.JSON ->
            -- see frontend/ts-src/index.ts:448 (getCode)
            "Can't generate JSON from Elm"


view : (Msg -> msg) -> (Cmd msg -> msg) -> msg -> HtmlId -> ProjectRef -> Model -> Html msg
view wrap send onClose titleId project model =
    let
        inputId : HtmlId
        inputId =
            model.id ++ "-radio"
    in
    div [ class "w-5xl" ]
        [ div [ css [ "px-6 pt-6", sm [ "flex items-start" ] ] ]
            [ div [ css [ "mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-primary-100", sm [ "mx-0 h-10 w-10" ] ] ]
                [ Icon.outline Icon.Logout "text-primary-600"
                ]
            , div [ css [ "mt-3 text-center", sm [ "mt-0 ml-4 text-left" ] ] ]
                [ h3 [ id titleId, class "text-lg leading-6 font-medium text-gray-900" ]
                    [ text "Export your diagram" ]
                , div [ class "mt-2" ]
                    [ Radio.smallCards (.value >> SetInput >> wrap)
                        { name = inputId ++ "-source"
                        , label = "Export"
                        , legend = "Choose what to export"
                        , options = [ ( Project, "Full project" ), ( AllTables, "All tables" ), ( CurrentLayout, "Current layout" ) ] |> List.map (\( v, t ) -> { value = v, text = t, disabled = False })
                        , value = model.input
                        , link = Nothing
                        }
                    ]
                , model.input
                    |> Maybe.filter (\i -> i /= Project)
                    |> Maybe.map
                        (\_ ->
                            div [ class "mt-2" ]
                                [ Radio.smallCards (.value >> SetFormat >> wrap)
                                    { name = inputId ++ "-output"
                                    , label = "Output format"
                                    , legend = "Choose an output format"
                                    , options = Dialect.export |> List.map (\d -> { value = d, text = Dialect.toString d, disabled = False })
                                    , value = model.format
                                    , link = Nothing
                                    }
                                ]
                        )
                    |> Maybe.withDefault (div [] [])
                , if model.output == Pending then
                    div [] []

                  else
                    model.output
                        |> Remote.fold
                            (\_ -> viewCode "Choose what you want to export and the format...")
                            (\_ -> viewCode "fetching...")
                            (\e -> viewCode ("Error: " ++ e))
                            (\content ->
                                if content == "plan_limit" then
                                    if model.input == Just Project then
                                        div [ class "mt-3" ] [ PlanDialog.projectExportWarning project ]

                                    else
                                        div [ class "mt-3" ] [ PlanDialog.schemaExportWarning project ]

                                else if model.format == Just Dialect.PostgreSQL then
                                    div [] [ viewCode content, viewSuggestPR "https://github.com/azimuttapp/azimutt/blob/main/frontend/src/DataSources/SqlMiner/PostgreSqlGenerator.elm#L26" ]

                                else if model.format == Just Dialect.MySQL then
                                    div [] [ viewCode content, viewSuggestPR "https://github.com/azimuttapp/azimutt/blob/main/frontend/src/DataSources/SqlMiner/MysqlGenerator.elm#L26" ]

                                else
                                    viewCode content
                            )
                ]
            ]
        , div [ class "px-6 py-3 mt-6 flex items-center flex-row-reverse bg-gray-50 rounded-b-lg" ]
            ((Maybe.map3
                (\input format content ->
                    [ Button.primary3 Tw.primary
                        [ onClick (content ++ "\n" |> Ports.downloadFile (buildFilename input format model.project model.layout) |> send), css [ "w-full text-base", sm [ "ml-3 w-auto text-sm" ] ] ]
                        [ Icon.solid Icon.Download "mr-1", text "Download file" ]
                    , Button.primary3 Tw.primary
                        [ onClick (content ++ "\n" |> Ports.copyToClipboard |> send), css [ "w-full text-base", sm [ "ml-3 w-auto text-sm" ] ] ]
                        [ Icon.solid Icon.Duplicate "mr-1", text "Copy to clipboard" ]
                    ]
                )
                model.input
                model.format
                (model.output |> Remote.toMaybe |> Maybe.filter (\content -> content /= "plan_limit"))
                |> Maybe.withDefault []
             )
                ++ [ Button.white3 Tw.gray [ onClick onClose, css [ "mt-3 w-full text-base", sm [ "mt-0 w-auto text-sm" ] ] ] [ text "Close" ] ]
            )
        ]


viewCode : String -> Html msg
viewCode codeStr =
    pre [ class "mt-2 px-4 py-2 bg-gray-900 text-white text-sm font-mono rounded-md overflow-auto max-h-128 w-4xl" ]
        [ code [] [ text codeStr ] ]


viewSuggestPR : String -> Html msg
viewSuggestPR generatorUrl =
    p [ class "mt-2 text-sm text-gray-500" ]
        [ text "Do you see possible improvements? Please "
        , extLink constants.azimuttBugReport [ class "link" ] [ text "open an issue" ]
        , text " or even "
        , extLink generatorUrl [ class "link" ] [ text "send a PR" ]
        , text ". ❤️"
        ]


buildFilename : ExportInput -> Dialect -> ProjectName -> LayoutName -> FileName
buildFilename input format project layout =
    let
        ( suffix, ext ) =
            ( case input of
                Project ->
                    ".azimutt"

                AllTables ->
                    ""

                CurrentLayout ->
                    "-" ++ layout
            , case format of
                Dialect.AML ->
                    ".md"

                Dialect.PostgreSQL ->
                    ".sql"

                Dialect.MySQL ->
                    ".sql"

                Dialect.JSON ->
                    ".json"
            )
    in
    project ++ suffix ++ ext



-- DOCUMENTATION


type alias SharedDocState x =
    { x | exportDialogDocState : DocState }


type alias DocState =
    { free : Model }


docInit : DocState
docInit =
    { free = { id = "free-modal-id", project = "Doc project", layout = "initial layout", input = Nothing, format = Nothing, output = Pending }
    }


updateDocState : ProjectRef -> (DocState -> Model) -> (Model -> DocState -> DocState) -> Msg -> ElmBook.Msg (SharedDocState x)
updateDocState project get set msg =
    ElmBook.Actions.updateStateWithCmd
        (\s ->
            s.exportDialogDocState
                |> get
                |> update (updateDocState project get set) ProjectRef.zero (sampleErd |> mapProject (setOrganization project.organization)) msg
                |> Tuple.mapBoth (\r -> { s | exportDialogDocState = s.exportDialogDocState |> set r }) .cmd
        )


updateDocFreeState : Msg -> ElmBook.Msg (SharedDocState x)
updateDocFreeState msg =
    updateDocState samplePlanFree .free (\m s -> { s | free = m }) msg


sampleOnClose : ElmBook.Msg state
sampleOnClose =
    ElmBook.Actions.logAction "onClose"


sampleTitleId : String
sampleTitleId =
    "modal-id-title"


sampleErd : Erd
sampleErd =
    Project.doc "Project name"
        (Source.doc "test"
            [ Table.doc ( "", "users" ) [ "id" ] [ ( "id", "uuid" ), ( "name", "varchar" ), ( "age", "int" ), ( "created_at", "datetime" ) ]
                |> setChecks [ Check.doc [ "age" ] (Just "age > 0") "users_age_chk" ]
            , { docTable
                | id = ( "", "organizations" )
                , name = "organizations"
                , columns =
                    Dict.fromListBy .name
                        [ Column.doc 1 "id" "uuid"
                        , { docColumn | index = 2, name = "slug", kind = "varchar", nullable = True }
                        , Column.doc 3 "name" "varchar"
                        , Column.doc 4 "created_at" "datetime"
                        ]
              }
                |> setPrimaryKey (PrimaryKey.doc [ "id" ])
                |> setUniques [ Unique.doc [ "slug" ] "organizations_slug_uniq" ]
            , Table.doc ( "", "organization_members" ) [ "organization_id", "user_id" ] [ ( "organization_id", "uuid" ), ( "user_id", "uuid" ) ]
            ]
            [ Relation.doc "organization_members.organization_id" "organizations.id"
            , Relation.doc "organization_members.user_id" "users.id"
            ]
        )
        |> setLayouts (Dict.fromList [ ( "init layout", Layout.doc [ ( "users", [ "id", "name" ] ) ] ) ])
        |> Erd.create
        |> setCurrentLayout "init layout"


samplePlanFree : ProjectRef
samplePlanFree =
    ProjectRef.zero


component : String -> (DocState -> Html msg) -> ( String, SharedDocState x -> Html msg )
component name render =
    ( name, \{ exportDialogDocState } -> render exportDialogDocState )


doc : Chapter (SharedDocState x)
doc =
    Chapter.chapter "ExportDialogBody"
        |> Chapter.renderStatefulComponentList
            [ component "exportDialog" (\model -> view updateDocFreeState (\_ -> logAction "Download file") sampleOnClose sampleTitleId samplePlanFree model.free)
            ]
